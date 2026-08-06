<#
.SYNOPSIS
Safely archives and cleans up Windows Event Logs for DWP endpoint support.

.DESCRIPTION
This script exports events older than a configurable age from selected Windows event logs,
then cleans up old archive files using a quarantine model to support rollback.

Safety design:
- Dry-run mode performs no changes and reports how many records would be cleaned up.
- Cleanup moves old archive files to quarantine (soft delete) instead of hard delete.
- Rollback restores quarantined archive files using a manifest from a prior run.
- Idempotent archive behavior skips archive creation when today's archive file already exists.

.NOTES
Designed for Windows PowerShell 5.1.
#>

[CmdletBinding()]
param(
    # Section: Selects which event logs to process for archiving.
    [Parameter(Mandatory = $false)]
    [string[]]$LogNames = @('Application', 'System', 'Security'),

    # Section: Targets only data older than this many days (default: 3).
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 36500)]
    [int]$OlderThanDays = 3,

    # Section: Simulates all actions and prints what would be cleaned up.
    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    # Section: Restores files moved to quarantine by a previous cleanup run.
    [Parameter(Mandatory = $false)]
    [switch]$Rollback,

    # Section: Optional path to a specific rollback manifest JSON file.
    [Parameter(Mandatory = $false)]
    [string]$RollbackManifestPath,

    # Section: Optional override for archive storage root.
    [Parameter(Mandatory = $false)]
    [string]$ArchiveRoot,

    # Section: Optional override for quarantine storage root.
    [Parameter(Mandatory = $false)]
    [string]$QuarantineRoot,

    # Section: Optional override for runtime log output folder.
    [Parameter(Mandatory = $false)]
    [string]$LogRoot
)

# Section: Resolves script-relative defaults after parameter binding (PS 5.1 safe pattern).
$scriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
if ([string]::IsNullOrWhiteSpace($ArchiveRoot)) {
    $ArchiveRoot = Join-Path $scriptDirectory 'eventlog_archives'
}
if ([string]::IsNullOrWhiteSpace($QuarantineRoot)) {
    $QuarantineRoot = Join-Path $scriptDirectory 'eventlog_quarantine'
}
if ([string]::IsNullOrWhiteSpace($LogRoot)) {
    $LogRoot = Join-Path $scriptDirectory 'logs'
}

# Section: Builds shared runtime values used by logging, manifest naming, and summaries.
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$runId = '{0}_{1}' -f $timestamp, ([Guid]::NewGuid().ToString('N').Substring(0, 8))
$archiveDate = Get-Date -Format 'yyyyMMdd'
$cutoffDate = (Get-Date).AddDays(-$OlderThanDays)
$ageInMilliseconds = [Int64][Math]::Round(([TimeSpan]::FromDays($OlderThanDays)).TotalMilliseconds)
$logFilePath = Join-Path $LogRoot ('eventlog_archive_cleanup_{0}.log' -f $timestamp)
$manifestDirectory = Join-Path $QuarantineRoot 'manifests'
$quarantineRunDirectory = Join-Path $QuarantineRoot $runId

# Section: Creates required folders with protection against runtime failures.
foreach ($requiredPath in @($ArchiveRoot, $QuarantineRoot, $LogRoot, $manifestDirectory)) {
    try {
        if (-not (Test-Path -LiteralPath $requiredPath)) {
            New-Item -Path $requiredPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }
    }
    catch {
        Write-Error ('Failed to create or access folder: {0}. Error: {1}' -f $requiredPath, $_.Exception.Message)
        exit 1
    }
}

# Section: Writes timestamped messages to both console and persistent run log.
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    try {
        $line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
        Add-Content -LiteralPath $logFilePath -Value $line -ErrorAction Stop
        Write-Host $line
    }
    catch {
        Write-Host ('[{0}] [ERROR] Failed to write log entry. Original message: {1}. Error: {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message, $_.Exception.Message)
    }
}

# Section: Returns record count for an EVTX file; returns 0 if unreadable.
function Get-EvtxRecordCount {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        if (-not (Test-Path -LiteralPath $Path)) {
            return 0
        }

        return (Get-WinEvent -Path $Path -ErrorAction Stop | Measure-Object).Count
    }
    catch {
        Write-Log -Level 'WARN' -Message ('Unable to count records in archive file: {0}. Error: {1}' -f $Path, $_.Exception.Message)
        return 0
    }
}

# Section: Archives old events from one log name using wevtutil with a timediff query.
function Export-LogOlderEvents {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogName,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,

        [Parameter(Mandatory = $true)]
        [Int64]$OlderThanMs,

        [Parameter(Mandatory = $true)]
        [switch]$IsDryRun
    )

    $result = [ordered]@{
        LogName        = $LogName
        Destination    = $DestinationPath
        Skipped        = $false
        Success        = $false
        ArchivedCount  = 0
        ErrorMessage   = $null
    }

    try {
        if (Test-Path -LiteralPath $DestinationPath) {
            $result.Skipped = $true
            $result.Success = $true
            Write-Log -Message ('Archive already exists for today; skipping for idempotency: {0}' -f $DestinationPath)
            return $result
        }
    }
    catch {
        $result.ErrorMessage = $_.Exception.Message
        Write-Log -Level 'ERROR' -Message ('Failed idempotency check for {0}. Error: {1}' -f $LogName, $_.Exception.Message)
        return $result
    }

    try {
        $query = '*[System[TimeCreated[timediff(@SystemTime) >= {0}]]]' -f $OlderThanMs

        if ($IsDryRun) {
            Write-Log -Message ('DRY-RUN would archive log {0} to {1} using age filter of {2} days.' -f $LogName, $DestinationPath, $OlderThanDays)
            $result.Success = $true
            return $result
        }

        $arguments = @('epl', $LogName, $DestinationPath, ('/q:{0}' -f $query))
        & wevtutil.exe @arguments

        if ($LASTEXITCODE -ne 0) {
            throw ('wevtutil exited with code {0}' -f $LASTEXITCODE)
        }

        if (-not (Test-Path -LiteralPath $DestinationPath)) {
            throw 'Archive export command completed but destination file was not found.'
        }

        $result.ArchivedCount = Get-EvtxRecordCount -Path $DestinationPath
        $result.Success = $true
        Write-Log -Message ('Archived log {0} to {1}. RecordCount={2}' -f $LogName, $DestinationPath, $result.ArchivedCount)
        return $result
    }
    catch {
        $result.ErrorMessage = $_.Exception.Message
        Write-Log -Level 'ERROR' -Message ('Failed to archive log {0}. Error: {1}' -f $LogName, $_.Exception.Message)
        return $result
    }
}

# Section: Restores archived files from quarantine based on a manifest from a prior run.
function Invoke-Rollback {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ManifestPath
    )

    $summary = [ordered]@{
        ManifestPath         = $ManifestPath
        ManifestEntries      = 0
        RestoredFiles        = 0
        MissingQuarantine    = 0
        DestinationExists    = 0
        Failed               = 0
    }

    try {
        if (-not (Test-Path -LiteralPath $ManifestPath)) {
            throw ('Rollback manifest not found: {0}' -f $ManifestPath)
        }
    }
    catch {
        Write-Log -Level 'ERROR' -Message $_.Exception.Message
        return $summary
    }

    try {
        $entries = Get-Content -LiteralPath $ManifestPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop

        if ($null -eq $entries) {
            Write-Log -Level 'WARN' -Message 'Rollback manifest is empty. Nothing to restore.'
            return $summary
        }

        if ($entries -isnot [System.Array]) {
            $entries = @($entries)
        }

        $summary.ManifestEntries = $entries.Count
    }
    catch {
        Write-Log -Level 'ERROR' -Message ('Failed to parse rollback manifest: {0}. Error: {1}' -f $ManifestPath, $_.Exception.Message)
        return $summary
    }

    foreach ($entry in $entries) {
        try {
            $sourcePath = $entry.QuarantinePath
            $destinationPath = $entry.OriginalPath

            if (-not (Test-Path -LiteralPath $sourcePath)) {
                $summary.MissingQuarantine++
                Write-Log -Level 'WARN' -Message ('Quarantine file missing, skipping: {0}' -f $sourcePath)
                continue
            }

            if (Test-Path -LiteralPath $destinationPath) {
                $summary.DestinationExists++
                Write-Log -Level 'WARN' -Message ('Destination already exists, skipping restore: {0}' -f $destinationPath)
                continue
            }

            $destinationFolder = Split-Path -Path $destinationPath -Parent
            if (-not (Test-Path -LiteralPath $destinationFolder)) {
                New-Item -Path $destinationFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
            }

            Move-Item -LiteralPath $sourcePath -Destination $destinationPath -Force -ErrorAction Stop
            $summary.RestoredFiles++
            Write-Log -Message ('Rollback restored: {0}' -f $destinationPath)
        }
        catch {
            $summary.Failed++
            Write-Log -Level 'ERROR' -Message ('Rollback failed for destination {0}. Error: {1}' -f $entry.OriginalPath, $_.Exception.Message)
        }
    }

    return $summary
}

# Section: Logs startup configuration for traceability and audit.
Write-Log -Message ('Script started. DryRun={0}, Rollback={1}, OlderThanDays={2}' -f $DryRun.IsPresent, $Rollback.IsPresent, $OlderThanDays)
Write-Log -Message ('ArchiveRoot={0}' -f $ArchiveRoot)
Write-Log -Message ('QuarantineRoot={0}' -f $QuarantineRoot)
Write-Log -Message ('CutoffDate={0}' -f $cutoffDate)
Write-Log -Message ('LogFile={0}' -f $logFilePath)

# Section: Handles rollback mode and exits after summary output.
if ($Rollback) {
    try {
        if ([string]::IsNullOrWhiteSpace($RollbackManifestPath)) {
            $latestManifest = Get-ChildItem -LiteralPath $manifestDirectory -Filter 'cleanup_manifest_*.json' -File -ErrorAction Stop |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1

            if ($null -eq $latestManifest) {
                throw 'No rollback manifest was provided and none were found in the manifest directory.'
            }

            $RollbackManifestPath = $latestManifest.FullName
            Write-Log -Message ('Using latest rollback manifest: {0}' -f $RollbackManifestPath)
        }
    }
    catch {
        Write-Log -Level 'ERROR' -Message ('Rollback initialization failed. Error: {0}' -f $_.Exception.Message)
        exit 1
    }

    $rollbackSummary = Invoke-Rollback -ManifestPath $RollbackManifestPath

    Write-Host ''
    Write-Host 'Rollback Summary'
    Write-Host '----------------'
    Write-Host ('Manifest path      : {0}' -f $rollbackSummary.ManifestPath)
    Write-Host ('Manifest entries   : {0}' -f $rollbackSummary.ManifestEntries)
    Write-Host ('Restored files     : {0}' -f $rollbackSummary.RestoredFiles)
    Write-Host ('Missing quarantine : {0}' -f $rollbackSummary.MissingQuarantine)
    Write-Host ('Destination exists : {0}' -f $rollbackSummary.DestinationExists)
    Write-Host ('Failed             : {0}' -f $rollbackSummary.Failed)
    Write-Host ('Log file           : {0}' -f $logFilePath)

    Write-Log -Message ('Rollback finished. Restored={0}, MissingQuarantine={1}, DestinationExists={2}, Failed={3}' -f $rollbackSummary.RestoredFiles, $rollbackSummary.MissingQuarantine, $rollbackSummary.DestinationExists, $rollbackSummary.Failed)
    exit 0
}

# Section: Prepares per-day archive folder used by idempotent archive writes.
$archiveDayFolder = Join-Path $ArchiveRoot $archiveDate
try {
    if (-not (Test-Path -LiteralPath $archiveDayFolder)) {
        New-Item -Path $archiveDayFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }
}
catch {
    Write-Log -Level 'ERROR' -Message ('Failed to prepare archive day folder. Error: {0}' -f $_.Exception.Message)
    exit 1
}

# Section: Initializes run summaries for archive and cleanup phases.
$archiveSummary = [ordered]@{
    LogsRequested   = $LogNames.Count
    ArchivedLogs    = 0
    SkippedExisting = 0
    FailedLogs      = 0
    ArchivedRecords = 0
}

$cleanupSummary = [ordered]@{
    CandidateFiles   = 0
    CandidateRecords = 0
    QuarantinedFiles = 0
    QuarantinedRecords = 0
    FailedFiles      = 0
}

$cleanupManifestRows = New-Object System.Collections.Generic.List[object]

# Section: Archives older events for each requested event log with per-log safety handling.
foreach ($logName in $LogNames) {
    $safeLogName = ($logName -replace '[^A-Za-z0-9._-]', '_')
    $archiveFilePath = Join-Path $archiveDayFolder ('{0}_{1}.evtx' -f $safeLogName, $archiveDate)

    try {
        $archiveResult = Export-LogOlderEvents -LogName $logName -DestinationPath $archiveFilePath -OlderThanMs $ageInMilliseconds -IsDryRun:$DryRun

        if (-not $archiveResult.Success) {
            $archiveSummary.FailedLogs++
            continue
        }

        if ($archiveResult.Skipped) {
            $archiveSummary.SkippedExisting++
            continue
        }

        $archiveSummary.ArchivedLogs++
        $archiveSummary.ArchivedRecords += $archiveResult.ArchivedCount
    }
    catch {
        $archiveSummary.FailedLogs++
        Write-Log -Level 'ERROR' -Message ('Unexpected archive loop failure for log {0}. Error: {1}' -f $logName, $_.Exception.Message)
    }
}

# Section: Identifies archive files older than cutoff and computes record deletion counts.
try {
    $archiveFilesForCleanup = Get-ChildItem -LiteralPath $ArchiveRoot -Recurse -File -Filter '*.evtx' -ErrorAction Stop |
        Where-Object { $_.LastWriteTime -lt $cutoffDate }
}
catch {
    Write-Log -Level 'ERROR' -Message ('Failed to enumerate archive files for cleanup. Error: {0}' -f $_.Exception.Message)
    exit 1
}

foreach ($archiveFile in $archiveFilesForCleanup) {
    try {
        $recordCount = Get-EvtxRecordCount -Path $archiveFile.FullName
        $cleanupSummary.CandidateFiles++
        $cleanupSummary.CandidateRecords += $recordCount

        if ($DryRun) {
            Write-Log -Message ('DRY-RUN would clean archive file: {0}. RecordCount={1}' -f $archiveFile.FullName, $recordCount)
            continue
        }

        if (-not (Test-Path -LiteralPath $quarantineRunDirectory)) {
            New-Item -Path $quarantineRunDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }

        $relativePath = $archiveFile.FullName.Substring($ArchiveRoot.Length).TrimStart('\\')
        $quarantinePath = Join-Path $quarantineRunDirectory $relativePath
        $quarantineFolder = Split-Path -Path $quarantinePath -Parent

        if (-not (Test-Path -LiteralPath $quarantineFolder)) {
            New-Item -Path $quarantineFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }

        Move-Item -LiteralPath $archiveFile.FullName -Destination $quarantinePath -Force -ErrorAction Stop

        $cleanupManifestRows.Add([PSCustomObject]@{
            RunId          = $runId
            OriginalPath   = $archiveFile.FullName
            QuarantinePath = $quarantinePath
            RecordCount    = $recordCount
            LastWriteTime  = $archiveFile.LastWriteTime.ToString('o')
            MovedAt        = (Get-Date).ToString('o')
        }) | Out-Null

        $cleanupSummary.QuarantinedFiles++
        $cleanupSummary.QuarantinedRecords += $recordCount
        Write-Log -Message ('Quarantined archive file: {0} -> {1}. RecordCount={2}' -f $archiveFile.FullName, $quarantinePath, $recordCount)
    }
    catch {
        $cleanupSummary.FailedFiles++
        Write-Log -Level 'ERROR' -Message ('Failed cleanup for archive file {0}. Error: {1}' -f $archiveFile.FullName, $_.Exception.Message)
    }
}

# Section: Persists cleanup manifest so rollback can restore files deterministically.
$manifestPathForRun = Join-Path $manifestDirectory ('cleanup_manifest_{0}.json' -f $runId)
if (-not $DryRun -and $cleanupManifestRows.Count -gt 0) {
    try {
        $cleanupManifestRows | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $manifestPathForRun -Encoding UTF8 -ErrorAction Stop
        Write-Log -Message ('Cleanup manifest written: {0}' -f $manifestPathForRun)
    }
    catch {
        Write-Log -Level 'ERROR' -Message ('Failed to write cleanup manifest. Error: {0}' -f $_.Exception.Message)
    }
}
elseif (-not $DryRun) {
    Write-Log -Message 'No archive files were quarantined. No cleanup manifest created.'
}

# Section: Prints end-of-run summary for operational visibility.
Write-Host ''
Write-Host 'Archive and Cleanup Summary'
Write-Host '---------------------------'
Write-Host ('Requested logs       : {0}' -f $archiveSummary.LogsRequested)
Write-Host ('Archived logs        : {0}' -f $archiveSummary.ArchivedLogs)
Write-Host ('Skipped (idempotent) : {0}' -f $archiveSummary.SkippedExisting)
Write-Host ('Archive failures     : {0}' -f $archiveSummary.FailedLogs)
Write-Host ('Archived records     : {0}' -f $archiveSummary.ArchivedRecords)
Write-Host ('')
Write-Host ('Cleanup candidates   : {0} files' -f $cleanupSummary.CandidateFiles)
Write-Host ('Records to delete    : {0}' -f $cleanupSummary.CandidateRecords)
Write-Host ('Quarantined files    : {0}' -f $cleanupSummary.QuarantinedFiles)
Write-Host ('Quarantined records  : {0}' -f $cleanupSummary.QuarantinedRecords)
Write-Host ('Cleanup failures     : {0}' -f $cleanupSummary.FailedFiles)
Write-Host ('Dry run              : {0}' -f $DryRun.IsPresent)
Write-Host ('Log file             : {0}' -f $logFilePath)

if (-not $DryRun -and $cleanupManifestRows.Count -gt 0) {
    Write-Host ('Rollback manifest    : {0}' -f $manifestPathForRun)
}

Write-Log -Message ('Script finished. ArchiveLogs={0}, ArchiveSkipped={1}, ArchiveFailed={2}, CleanupCandidates={3}, CleanupCandidateRecords={4}, QuarantinedFiles={5}, QuarantinedRecords={6}, CleanupFailed={7}, DryRun={8}' -f $archiveSummary.ArchivedLogs, $archiveSummary.SkippedExisting, $archiveSummary.FailedLogs, $cleanupSummary.CandidateFiles, $cleanupSummary.CandidateRecords, $cleanupSummary.QuarantinedFiles, $cleanupSummary.QuarantinedRecords, $cleanupSummary.FailedFiles, $DryRun.IsPresent)
