<#
.SYNOPSIS
DWP Engineer Day-Run Auditor (PowerShell 5.1).

.DESCRIPTION
Single-script toolkit for endpoint operations with safe defaults:
1) Startup program auditor (list startup items and optionally disable by program name)
2) Large file finder (read-only)
3) Disk health and optimization status reporter (read-only, no defrag execution)
4) Event log archive and cleanup workflow with dry-run, rollback, idempotency, and audit logging

Safety features:
- Dry-run support for change operations
- Rollback manifest and restore flow
- Idempotent archive behavior (skip if today's archive exists)
- Try/catch handling around each operational block
- Timestamped run log
- End-of-run summary
#>

[CmdletBinding()]
param(
    # Section: Startup auditor options.
    [Parameter(Mandatory = $false)]
    [switch]$DisableStartup,

    [Parameter(Mandatory = $false)]
    [string]$ProgramName,

    # Section: Large file finder option.
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 1024000)]
    [int]$LargeFileThresholdMB = 100,

    [Parameter(Mandatory = $false)]
    [string[]]$ScanPaths,

    # Section: Event log maintenance options.
    [Parameter(Mandatory = $false)]
    [string[]]$LogNames = @('Application', 'System', 'Security'),

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 36500)]
    [int]$OlderThanDays = 3,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [switch]$SkipEventLogMaintenance,

    [Parameter(Mandatory = $false)]
    [switch]$Rollback,

    [Parameter(Mandatory = $false)]
    [string]$RollbackManifestPath,

    [Parameter(Mandatory = $false)]
    [string]$ArchiveRoot,

    [Parameter(Mandatory = $false)]
    [string]$QuarantineRoot,

    [Parameter(Mandatory = $false)]
    [string]$LogRoot,

    [Parameter(Mandatory = $false)]
    [string]$StartupQuarantineRoot
)

# Section: Resolve runtime paths and initialize date-based metadata.
$scriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
if ([string]::IsNullOrWhiteSpace($ArchiveRoot)) { $ArchiveRoot = Join-Path $scriptDirectory 'eventlog_archives' }
if ([string]::IsNullOrWhiteSpace($QuarantineRoot)) { $QuarantineRoot = Join-Path $scriptDirectory 'eventlog_quarantine' }
if ([string]::IsNullOrWhiteSpace($LogRoot)) { $LogRoot = Join-Path $scriptDirectory 'logs' }
if ([string]::IsNullOrWhiteSpace($StartupQuarantineRoot)) { $StartupQuarantineRoot = Join-Path $scriptDirectory 'startup_quarantine' }

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$runId = '{0}_{1}' -f $timestamp, ([Guid]::NewGuid().ToString('N').Substring(0, 8))
$archiveDate = Get-Date -Format 'yyyyMMdd'
$cutoffDate = (Get-Date).AddDays(-$OlderThanDays)
$ageInMilliseconds = [Int64][Math]::Round(([TimeSpan]::FromDays($OlderThanDays)).TotalMilliseconds)
$logFilePath = Join-Path $LogRoot ('dwp_day_run_auditor_{0}.log' -f $timestamp)
$manifestDirectory = Join-Path $QuarantineRoot 'manifests'
$quarantineRunDirectory = Join-Path $QuarantineRoot $runId
$startupRunDirectory = Join-Path $StartupQuarantineRoot $runId

# Section: Create required directories safely.
foreach ($requiredPath in @($ArchiveRoot, $QuarantineRoot, $LogRoot, $manifestDirectory, $StartupQuarantineRoot)) {
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

# Section: Centralized logging helper writes to console and file.
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

# Section: Safely resolves a startup command for reporting readability.
function Resolve-StartupPath {
    param(
        [Parameter(Mandatory = $false)]
        [string]$Command
    )

    try {
        if ([string]::IsNullOrWhiteSpace($Command)) {
            return $null
        }

        $trimmed = $Command.Trim()
        if ($trimmed.StartsWith('"')) {
            $endQuote = $trimmed.IndexOf('"', 1)
            if ($endQuote -gt 1) {
                return $trimmed.Substring(1, $endQuote - 1)
            }
        }

        $firstToken = ($trimmed -split '\s+')[0]
        return $firstToken
    }
    catch {
        return $null
    }
}

# Section: Enumerates startup entries from registry and Startup folders.
function Get-StartupPrograms {
    $items = New-Object System.Collections.Generic.List[object]

    $runLocations = @(
        @{ Scope = 'HKLM'; Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' },
        @{ Scope = 'HKCU'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' }
    )

    foreach ($loc in $runLocations) {
        try {
            if (-not (Test-Path -LiteralPath $loc.Path)) {
                continue
            }

            $key = Get-Item -LiteralPath $loc.Path -ErrorAction Stop
            $valueNames = $key.GetValueNames()
            foreach ($name in $valueNames) {
                try {
                    $valueData = $key.GetValue($name)
                    $items.Add([PSCustomObject]@{
                        EntryType     = 'RegistryRun'
                        Scope         = $loc.Scope
                        Name          = $name
                        Command       = [string]$valueData
                        SourcePath    = $loc.Path
                        SourceSubPath = $name
                        StartupPath   = Resolve-StartupPath -Command ([string]$valueData)
                    }) | Out-Null
                }
                catch {
                    Write-Log -Level 'WARN' -Message ('Unable to read value {0} from {1}. Error: {2}' -f $name, $loc.Path, $_.Exception.Message)
                }
            }
        }
        catch {
            Write-Log -Level 'WARN' -Message ('Unable to enumerate registry startup path {0}. Error: {1}' -f $loc.Path, $_.Exception.Message)
        }
    }

    $folderLocations = @(
        @{ Scope = 'CurrentUser'; Path = [Environment]::GetFolderPath('Startup') },
        @{ Scope = 'AllUsers'; Path = [Environment]::GetFolderPath('CommonStartup') }
    )

    foreach ($folder in $folderLocations) {
        try {
            if ([string]::IsNullOrWhiteSpace($folder.Path) -or -not (Test-Path -LiteralPath $folder.Path)) {
                continue
            }

            Get-ChildItem -LiteralPath $folder.Path -File -ErrorAction Stop | ForEach-Object {
                $items.Add([PSCustomObject]@{
                    EntryType     = 'StartupFolder'
                    Scope         = $folder.Scope
                    Name          = $_.BaseName
                    Command       = $_.FullName
                    SourcePath    = $_.FullName
                    SourceSubPath = $null
                    StartupPath   = $_.FullName
                }) | Out-Null
            }
        }
        catch {
            Write-Log -Level 'WARN' -Message ('Unable to enumerate startup folder {0}. Error: {1}' -f $folder.Path, $_.Exception.Message)
        }
    }

    return $items
}

# Section: Collects event count from an EVTX file, returns 0 on failure.
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

# Section: Archives events older than configured age; skips if archive exists today.
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
        LogName       = $LogName
        Destination   = $DestinationPath
        Skipped       = $false
        Success       = $false
        ArchivedCount = 0
        ErrorMessage  = $null
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

# Section: Restores previously moved files and registry entries from a manifest.
function Invoke-Rollback {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ManifestPath
    )

    $summary = [ordered]@{
        ManifestPath         = $ManifestPath
        ManifestEntries      = 0
        RestoredFiles        = 0
        RestoredRegistry     = 0
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
            if ($entry.Action -eq 'MoveFile') {
                $sourcePath = [string]$entry.QuarantinePath
                $destinationPath = [string]$entry.OriginalPath

                if (-not (Test-Path -LiteralPath $sourcePath)) {
                    $summary.MissingQuarantine++
                    Write-Log -Level 'WARN' -Message ('Rollback missing quarantine file: {0}' -f $sourcePath)
                    continue
                }

                if (Test-Path -LiteralPath $destinationPath) {
                    $summary.DestinationExists++
                    Write-Log -Level 'WARN' -Message ('Rollback destination already exists, skipping: {0}' -f $destinationPath)
                    continue
                }

                $destinationFolder = Split-Path -Path $destinationPath -Parent
                if (-not (Test-Path -LiteralPath $destinationFolder)) {
                    New-Item -Path $destinationFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
                }

                Move-Item -LiteralPath $sourcePath -Destination $destinationPath -Force -ErrorAction Stop
                $summary.RestoredFiles++
                Write-Log -Message ('Rollback restored file: {0}' -f $destinationPath)
            }
            elseif ($entry.Action -eq 'RegistryRename') {
                $path = [string]$entry.RegistryPath
                $from = [string]$entry.DisabledValueName
                $to = [string]$entry.OriginalValueName

                $key = Get-Item -LiteralPath $path -ErrorAction Stop
                $existingNames = $key.GetValueNames()

                if (($existingNames -contains $to) -and ($existingNames -contains $from)) {
                    $summary.DestinationExists++
                    Write-Log -Level 'WARN' -Message ('Rollback registry target already exists and disabled value still exists; skipping path {0} value {1}' -f $path, $to)
                    continue
                }

                if (-not ($existingNames -contains $from)) {
                    $summary.MissingQuarantine++
                    Write-Log -Level 'WARN' -Message ('Rollback disabled registry value missing; skipping path {0} value {1}' -f $path, $from)
                    continue
                }

                Rename-ItemProperty -LiteralPath $path -Name $from -NewName $to -ErrorAction Stop
                $summary.RestoredRegistry++
                Write-Log -Message ('Rollback restored registry startup value: {0}\{1}' -f $path, $to)
            }
            else {
                Write-Log -Level 'WARN' -Message ('Unknown manifest action skipped: {0}' -f [string]$entry.Action)
            }
        }
        catch {
            $summary.Failed++
            Write-Log -Level 'ERROR' -Message ('Rollback entry failed. Action={0}. Error={1}' -f [string]$entry.Action, $_.Exception.Message)
        }
    }

    return $summary
}

# Section: Startup log header.
Write-Log -Message ('Script started. DryRun={0}, Rollback={1}, DisableStartup={2}, ProgramName={3}, OlderThanDays={4}, ThresholdMB={5}, SkipEventLogMaintenance={6}' -f $DryRun.IsPresent, $Rollback.IsPresent, $DisableStartup.IsPresent, $ProgramName, $OlderThanDays, $LargeFileThresholdMB, $SkipEventLogMaintenance.IsPresent)
Write-Log -Message ('ArchiveRoot={0}' -f $ArchiveRoot)
Write-Log -Message ('QuarantineRoot={0}' -f $QuarantineRoot)
Write-Log -Message ('StartupQuarantineRoot={0}' -f $StartupQuarantineRoot)
Write-Log -Message ('CutoffDate={0}' -f $cutoffDate)
Write-Log -Message ('LogFile={0}' -f $logFilePath)

# Section: Rollback mode path resolution and execution.
if ($Rollback) {
    try {
        if ([string]::IsNullOrWhiteSpace($RollbackManifestPath)) {
            $latestManifest = Get-ChildItem -LiteralPath $manifestDirectory -Filter 'day_run_manifest_*.json' -File -ErrorAction Stop |
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
    Write-Host ('Restored registry  : {0}' -f $rollbackSummary.RestoredRegistry)
    Write-Host ('Missing quarantine : {0}' -f $rollbackSummary.MissingQuarantine)
    Write-Host ('Destination exists : {0}' -f $rollbackSummary.DestinationExists)
    Write-Host ('Failed             : {0}' -f $rollbackSummary.Failed)
    Write-Host ('Log file           : {0}' -f $logFilePath)

    Write-Log -Message ('Rollback finished. RestoredFiles={0}, RestoredRegistry={1}, MissingQuarantine={2}, DestinationExists={3}, Failed={4}' -f $rollbackSummary.RestoredFiles, $rollbackSummary.RestoredRegistry, $rollbackSummary.MissingQuarantine, $rollbackSummary.DestinationExists, $rollbackSummary.Failed)
    exit 0
}

# Section: Initialize summary and manifest collectors.
$summary = [ordered]@{
    StartupItemsTotal            = 0
    StartupDisableCandidates     = 0
    StartupDisabled              = 0
    StartupDisableFailures       = 0
    LargeFilesFound              = 0
    LargeFileThresholdMB         = $LargeFileThresholdMB
    DiskVolumesReported          = 0
    PhysicalDisksReported        = 0
    EventLogsRequested           = $LogNames.Count
    EventLogsArchived            = 0
    EventLogsSkippedExisting     = 0
    EventLogArchiveFailures      = 0
    EventArchiveCandidateFiles   = 0
    EventArchiveCandidateRecords = 0
    EventArchiveQuarantinedFiles = 0
    EventArchiveQuarantinedRecs  = 0
    EventArchiveCleanupFailures  = 0
    DryRun                       = $DryRun.IsPresent
}

$manifestRows = New-Object System.Collections.Generic.List[object]

# Section: Startup program audit and optional disable operation.
$startupItems = @()
try {
    $startupItems = @(Get-StartupPrograms)
    $summary.StartupItemsTotal = $startupItems.Count
    Write-Log -Message ('Startup audit collected {0} entries.' -f $startupItems.Count)

    Write-Host ''
    Write-Host 'Startup Program Auditor'
    Write-Host '-----------------------'
    if ($startupItems.Count -eq 0) {
        Write-Host 'No startup items found.'
    }
    else {
        $startupItems |
            Select-Object EntryType, Scope, Name, Command |
            Sort-Object Scope, Name |
            Format-Table -Wrap -AutoSize
    }
}
catch {
    Write-Log -Level 'ERROR' -Message ('Startup audit failed. Error: {0}' -f $_.Exception.Message)
}

if ($DisableStartup) {
    if ([string]::IsNullOrWhiteSpace($ProgramName)) {
        Write-Log -Level 'ERROR' -Message 'DisableStartup was specified but ProgramName is empty.'
    }
    else {
        try {
            $matches = @($startupItems | Where-Object { $_.Name -like "*$ProgramName*" })
            $summary.StartupDisableCandidates = $matches.Count

            Write-Log -Message ('Startup disable requested. ProgramName={0}. Matches={1}' -f $ProgramName, $matches.Count)

            if ($DryRun) {
                Write-Log -Message ('DRY-RUN startup disable candidates (records to delete): {0}' -f $matches.Count)
            }
            else {
                if (-not (Test-Path -LiteralPath $startupRunDirectory)) {
                    New-Item -Path $startupRunDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null
                }

                foreach ($entry in $matches) {
                    try {
                        if ($entry.EntryType -eq 'RegistryRun') {
                            $path = [string]$entry.SourcePath
                            $oldName = [string]$entry.Name
                            $newName = ('DISABLED_{0}_{1}' -f $runId, $oldName)

                            $key = Get-Item -LiteralPath $path -ErrorAction Stop
                            $valueNames = $key.GetValueNames()
                            if ($valueNames -contains $newName) {
                                Write-Log -Message ('Registry value already disabled (idempotent skip): {0}\{1}' -f $path, $newName)
                                continue
                            }

                            if (-not ($valueNames -contains $oldName)) {
                                Write-Log -Level 'WARN' -Message ('Registry value no longer exists, skipping: {0}\{1}' -f $path, $oldName)
                                continue
                            }

                            Rename-ItemProperty -LiteralPath $path -Name $oldName -NewName $newName -ErrorAction Stop

                            $manifestRows.Add([PSCustomObject]@{
                                Action            = 'RegistryRename'
                                RegistryPath      = $path
                                OriginalValueName = $oldName
                                DisabledValueName = $newName
                                CreatedAt         = (Get-Date).ToString('o')
                            }) | Out-Null

                            $summary.StartupDisabled++
                            Write-Log -Message ('Disabled registry startup value: {0}\{1}' -f $path, $oldName)
                        }
                        elseif ($entry.EntryType -eq 'StartupFolder') {
                            $sourcePath = [string]$entry.SourcePath
                            if (-not (Test-Path -LiteralPath $sourcePath)) {
                                Write-Log -Level 'WARN' -Message ('Startup file missing, skipping: {0}' -f $sourcePath)
                                continue
                            }

                            $relativeName = Split-Path -Path $sourcePath -Leaf
                            $destinationPath = Join-Path $startupRunDirectory $relativeName

                            if (Test-Path -LiteralPath $destinationPath) {
                                Write-Log -Message ('Startup file already moved this run (idempotent skip): {0}' -f $sourcePath)
                                continue
                            }

                            Move-Item -LiteralPath $sourcePath -Destination $destinationPath -Force -ErrorAction Stop

                            $manifestRows.Add([PSCustomObject]@{
                                Action         = 'MoveFile'
                                OriginalPath   = $sourcePath
                                QuarantinePath = $destinationPath
                                CreatedAt      = (Get-Date).ToString('o')
                            }) | Out-Null

                            $summary.StartupDisabled++
                            Write-Log -Message ('Disabled startup folder item: {0}' -f $sourcePath)
                        }
                    }
                    catch {
                        $summary.StartupDisableFailures++
                        Write-Log -Level 'ERROR' -Message ('Failed to disable startup item {0}. Error: {1}' -f $entry.Name, $_.Exception.Message)
                    }
                }
            }
        }
        catch {
            Write-Log -Level 'ERROR' -Message ('Startup disable operation failed. Error: {0}' -f $_.Exception.Message)
        }
    }
}

# Section: Large file finder (read-only) using threshold input.
try {
    if ($null -eq $ScanPaths -or $ScanPaths.Count -eq 0) {
        $ScanPaths = @([Environment]::GetFolderPath('UserProfile'))
    }

    $bytesThreshold = [Int64]$LargeFileThresholdMB * 1MB
    $largeFiles = New-Object System.Collections.Generic.List[object]

    foreach ($path in $ScanPaths) {
        try {
            if ([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path -LiteralPath $path)) {
                Write-Log -Level 'WARN' -Message ('Scan path not found, skipping: {0}' -f $path)
                continue
            }

            Get-ChildItem -LiteralPath $path -File -Recurse -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.Length -ge $bytesThreshold } |
                ForEach-Object {
                    $largeFiles.Add([PSCustomObject]@{
                        Path         = $_.FullName
                        SizeMB       = [Math]::Round($_.Length / 1MB, 2)
                        LastWriteTime = $_.LastWriteTime
                    }) | Out-Null
                }
        }
        catch {
            Write-Log -Level 'WARN' -Message ('Large file scan failed for path {0}. Error: {1}' -f $path, $_.Exception.Message)
        }
    }

    $summary.LargeFilesFound = $largeFiles.Count

    Write-Host ''
    Write-Host 'Large File Finder (Read-Only)'
    Write-Host '-----------------------------'
    Write-Host ('Threshold MB: {0}' -f $LargeFileThresholdMB)
    Write-Host ('Paths       : {0}' -f ($ScanPaths -join '; '))

    if ($largeFiles.Count -eq 0) {
        Write-Host 'No files found above threshold.'
    }
    else {
        $largeFiles |
            Sort-Object SizeMB -Descending |
            Select-Object -First 100 |
            Format-Table -AutoSize
    }

    Write-Log -Message ('Large file scan complete. ThresholdMB={0}. FilesFound={1}' -f $LargeFileThresholdMB, $largeFiles.Count)
}
catch {
    Write-Log -Level 'ERROR' -Message ('Large file finder section failed. Error: {0}' -f $_.Exception.Message)
}

# Section: Disk health and optimization status reporting (strictly read-only).
try {
    Write-Host ''
    Write-Host 'Disk Health Reporter (Read-Only)'
    Write-Host '-------------------------------'

    $volumeReport = @()
    try {
        $volumeReport = @(Get-Volume -ErrorAction Stop | Select-Object DriveLetter, FileSystemLabel, FileSystem, HealthStatus, SizeRemaining, Size)
        $summary.DiskVolumesReported = $volumeReport.Count
    }
    catch {
        Write-Log -Level 'WARN' -Message ('Unable to collect volume report via Get-Volume. Error: {0}' -f $_.Exception.Message)
    }

    if ($volumeReport.Count -gt 0) {
        $volumeReport |
            Select-Object DriveLetter, FileSystemLabel, FileSystem, HealthStatus,
                @{Name='SizeGB';Expression={ if ($_.Size) { [Math]::Round($_.Size / 1GB, 2) } else { 0 } }},
                @{Name='FreeGB';Expression={ if ($_.SizeRemaining) { [Math]::Round($_.SizeRemaining / 1GB, 2) } else { 0 } }} |
            Format-Table -AutoSize
    }
    else {
        Write-Host 'No volume data available.'
    }

    $physicalDisks = @()
    try {
        $physicalDisks = @(Get-PhysicalDisk -ErrorAction Stop | Select-Object FriendlyName, MediaType, HealthStatus, OperationalStatus, Size)
        $summary.PhysicalDisksReported = $physicalDisks.Count
    }
    catch {
        Write-Log -Level 'WARN' -Message ('Unable to collect physical disk report via Get-PhysicalDisk. Error: {0}' -f $_.Exception.Message)
    }

    if ($physicalDisks.Count -gt 0) {
        $physicalDisks |
            Select-Object FriendlyName, MediaType, HealthStatus, OperationalStatus,
                @{Name='SizeGB';Expression={ if ($_.Size) { [Math]::Round($_.Size / 1GB, 2) } else { 0 } }} |
            Format-Table -AutoSize
    }
    else {
        Write-Host 'No physical disk data available.'
    }

    try {
        $defragTask = Get-ScheduledTask -TaskPath '\Microsoft\Windows\Defrag\' -TaskName 'ScheduledDefrag' -ErrorAction Stop
        $taskInfo = Get-ScheduledTaskInfo -TaskPath '\Microsoft\Windows\Defrag\' -TaskName 'ScheduledDefrag' -ErrorAction Stop

        Write-Host ''
        Write-Host 'Optimization Status (Read-Only Task Metadata)'
        Write-Host ('Task State       : {0}' -f $defragTask.State)
        Write-Host ('Last Run Time    : {0}' -f $taskInfo.LastRunTime)
        Write-Host ('Next Run Time    : {0}' -f $taskInfo.NextRunTime)
        Write-Host ('Last Task Result : {0}' -f $taskInfo.LastTaskResult)

        Write-Log -Message ('Disk optimization metadata collected from ScheduledDefrag task. State={0}, LastResult={1}' -f $defragTask.State, $taskInfo.LastTaskResult)
    }
    catch {
        Write-Log -Level 'WARN' -Message ('Unable to read ScheduledDefrag task metadata. Error: {0}' -f $_.Exception.Message)
    }

    Write-Log -Message 'Disk health report section completed (read-only).' 
}
catch {
    Write-Log -Level 'ERROR' -Message ('Disk health section failed. Error: {0}' -f $_.Exception.Message)
}

# Section: Event log maintenance (archive + quarantine cleanup) with dry-run and idempotency.
if (-not $SkipEventLogMaintenance) {
    try {
        $archiveDayFolder = Join-Path $ArchiveRoot $archiveDate
        if (-not (Test-Path -LiteralPath $archiveDayFolder)) {
            New-Item -Path $archiveDayFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }

        foreach ($logName in $LogNames) {
            $safeLogName = ($logName -replace '[^A-Za-z0-9._-]', '_')
            $archiveFilePath = Join-Path $archiveDayFolder ('{0}_{1}.evtx' -f $safeLogName, $archiveDate)

            try {
                $archiveResult = Export-LogOlderEvents -LogName $logName -DestinationPath $archiveFilePath -OlderThanMs $ageInMilliseconds -IsDryRun:$DryRun

                if (-not $archiveResult.Success) {
                    $summary.EventLogArchiveFailures++
                    continue
                }

                if ($archiveResult.Skipped) {
                    $summary.EventLogsSkippedExisting++
                    continue
                }

                $summary.EventLogsArchived++
            }
            catch {
                $summary.EventLogArchiveFailures++
                Write-Log -Level 'ERROR' -Message ('Unexpected archive loop failure for log {0}. Error: {1}' -f $logName, $_.Exception.Message)
            }
        }

        $archiveFilesForCleanup = @()
        try {
            $archiveFilesForCleanup = @(Get-ChildItem -LiteralPath $ArchiveRoot -Recurse -File -Filter '*.evtx' -ErrorAction Stop |
                Where-Object { $_.LastWriteTime -lt $cutoffDate })
        }
        catch {
            Write-Log -Level 'ERROR' -Message ('Failed to enumerate archive files for cleanup. Error: {0}' -f $_.Exception.Message)
        }

        foreach ($archiveFile in $archiveFilesForCleanup) {
            try {
                $recordCount = Get-EvtxRecordCount -Path $archiveFile.FullName
                $summary.EventArchiveCandidateFiles++
                $summary.EventArchiveCandidateRecords += $recordCount

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

                $manifestRows.Add([PSCustomObject]@{
                    Action         = 'MoveFile'
                    OriginalPath   = $archiveFile.FullName
                    QuarantinePath = $quarantinePath
                    RecordCount    = $recordCount
                    LastWriteTime  = $archiveFile.LastWriteTime.ToString('o')
                    CreatedAt      = (Get-Date).ToString('o')
                }) | Out-Null

                $summary.EventArchiveQuarantinedFiles++
                $summary.EventArchiveQuarantinedRecs += $recordCount
                Write-Log -Message ('Quarantined archive file: {0} -> {1}. RecordCount={2}' -f $archiveFile.FullName, $quarantinePath, $recordCount)
            }
            catch {
                $summary.EventArchiveCleanupFailures++
                Write-Log -Level 'ERROR' -Message ('Failed cleanup for archive file {0}. Error: {1}' -f $archiveFile.FullName, $_.Exception.Message)
            }
        }
    }
    catch {
        Write-Log -Level 'ERROR' -Message ('Event log maintenance section failed. Error: {0}' -f $_.Exception.Message)
    }
}
else {
    Write-Log -Message 'Event log maintenance skipped by flag.'
}

# Section: Persist manifest for rollback if any changes were made.
$manifestPathForRun = Join-Path $manifestDirectory ('day_run_manifest_{0}.json' -f $runId)
if (-not $DryRun -and $manifestRows.Count -gt 0) {
    try {
        $manifestRows | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPathForRun -Encoding UTF8 -ErrorAction Stop
        Write-Log -Message ('Rollback manifest written: {0}' -f $manifestPathForRun)
    }
    catch {
        Write-Log -Level 'ERROR' -Message ('Failed to write rollback manifest. Error: {0}' -f $_.Exception.Message)
    }
}
elseif (-not $DryRun) {
    Write-Log -Message 'No change operations performed; rollback manifest was not created.'
}

# Section: Final summary output for engineer visibility.
Write-Host ''
Write-Host 'Day-Run Auditor Summary'
Write-Host '-----------------------'
Write-Host ('Startup items discovered      : {0}' -f $summary.StartupItemsTotal)
Write-Host ('Startup disable candidates    : {0}' -f $summary.StartupDisableCandidates)
Write-Host ('Startup disabled              : {0}' -f $summary.StartupDisabled)
Write-Host ('Startup disable failures      : {0}' -f $summary.StartupDisableFailures)
Write-Host ('Large files found             : {0}' -f $summary.LargeFilesFound)
Write-Host ('Large file threshold (MB)     : {0}' -f $summary.LargeFileThresholdMB)
Write-Host ('Disk volumes reported         : {0}' -f $summary.DiskVolumesReported)
Write-Host ('Physical disks reported       : {0}' -f $summary.PhysicalDisksReported)
Write-Host ('Event logs requested          : {0}' -f $summary.EventLogsRequested)
Write-Host ('Event logs archived           : {0}' -f $summary.EventLogsArchived)
Write-Host ('Event logs skipped (today)    : {0}' -f $summary.EventLogsSkippedExisting)
Write-Host ('Event archive failures        : {0}' -f $summary.EventLogArchiveFailures)
Write-Host ('Cleanup candidates (files)    : {0}' -f $summary.EventArchiveCandidateFiles)
Write-Host ('Records to delete             : {0}' -f $summary.EventArchiveCandidateRecords)
Write-Host ('Quarantined cleanup files     : {0}' -f $summary.EventArchiveQuarantinedFiles)
Write-Host ('Quarantined cleanup records   : {0}' -f $summary.EventArchiveQuarantinedRecs)
Write-Host ('Cleanup failures              : {0}' -f $summary.EventArchiveCleanupFailures)
Write-Host ('Dry run                       : {0}' -f $summary.DryRun)
Write-Host ('Log file                      : {0}' -f $logFilePath)

if (-not $DryRun -and $manifestRows.Count -gt 0) {
    Write-Host ('Rollback manifest             : {0}' -f $manifestPathForRun)
}

Write-Log -Message ('Script completed. StartupTotal={0}, StartupDisabled={1}, LargeFiles={2}, Volumes={3}, PhysicalDisks={4}, EventArchived={5}, EventSkipped={6}, EventCleanupCandidates={7}, EventCandidateRecords={8}, EventQuarantined={9}, DryRun={10}' -f $summary.StartupItemsTotal, $summary.StartupDisabled, $summary.LargeFilesFound, $summary.DiskVolumesReported, $summary.PhysicalDisksReported, $summary.EventLogsArchived, $summary.EventLogsSkippedExisting, $summary.EventArchiveCandidateFiles, $summary.EventArchiveCandidateRecords, $summary.EventArchiveQuarantinedFiles, $summary.DryRun)
