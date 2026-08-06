# DWP Day-Run Auditor (PowerShell 5.1)

## File

- dwp_day_run_auditor.ps1

## What this script does

This script is a combined toolkit for DWP endpoint engineers:

1. Startup Program Auditor
- Lists startup entries from registry Run keys and Startup folders.
- Can disable startup entries by program name using a safe, rollback-capable method.

2. Large File Finder (Read-Only)
- Finds files above a configurable threshold.
- Default threshold is 100 MB.

3. Disk Health Reporter (Read-Only)
- Reports volume and physical disk health status.
- Reports optimization metadata from ScheduledDefrag task only.
- Does not run defrag or optimize operations.

4. Event Log Archive and Cleanup Workflow
- Archives events older than configurable days (default 3).
- Idempotent archive behavior: if today archive file exists, that log is skipped.
- Cleanup stage quarantines old archive files for rollback instead of hard deletion.
- Dry-run prints records that would be deleted.

## Safety features

- Try/catch handling in each operation block.
- Timestamped action log file in DAY3/logs.
- Dry-run mode for safe preview.
- Rollback mode via generated manifest.
- Idempotent behavior for daily event archives.

## Parameters

- DisableStartup
  - Switch.
  - Enables startup disable flow.

- ProgramName <string>
  - Startup program name match input used with DisableStartup.

- LargeFileThresholdMB <int>
  - Large file threshold in MB.
  - Default: 100.

- ScanPaths <string[]>
  - Paths to scan for large files.
  - Default: current user profile.

- LogNames <string[]>
  - Event logs to archive.
  - Default: Application, System, Security.

- OlderThanDays <int>
  - Age threshold for event archive query and cleanup selection.
  - Default: 3.

- DryRun
  - Switch.
  - Simulates change operations and prints Records to delete.

- SkipEventLogMaintenance
  - Switch.
  - Skips event log archive and cleanup sections.

- Rollback
  - Switch.
  - Restores changes from the latest or specified rollback manifest.

- RollbackManifestPath <string>
  - Optional explicit manifest path for rollback.

- ArchiveRoot <string>
  - Optional override for event archive root.

- QuarantineRoot <string>
  - Optional override for event quarantine root.

- LogRoot <string>
  - Optional override for operation log folder.

- StartupQuarantineRoot <string>
  - Optional override for disabled startup file quarantine folder.

## Usage examples

Dry run with defaults:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\DAY3\dwp_day_run_auditor.ps1 -DryRun
```

Disable startup entries by name with dry run:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\DAY3\dwp_day_run_auditor.ps1 -DisableStartup -ProgramName Teams -DryRun
```

Disable startup entries by name (real run):

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\DAY3\dwp_day_run_auditor.ps1 -DisableStartup -ProgramName Teams
```

Large file scan with custom threshold and paths:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\DAY3\dwp_day_run_auditor.ps1 -LargeFileThresholdMB 250 -ScanPaths C:\Users\labuser\Downloads,C:\Temp -SkipEventLogMaintenance
```

Run event log workflow with 7-day threshold:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\DAY3\dwp_day_run_auditor.ps1 -OlderThanDays 7
```

Rollback latest manifest:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\DAY3\dwp_day_run_auditor.ps1 -Rollback
```

Rollback specific manifest:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\DAY3\dwp_day_run_auditor.ps1 -Rollback -RollbackManifestPath .\DAY3\eventlog_quarantine\manifests\day_run_manifest_YYYYMMDD_HHMMSS_xxxxxxxx.json
```

## Output and artifacts

- Runtime logs:
  - DAY3/logs/dwp_day_run_auditor_yyyyMMdd_HHmmss.log
- Event archives:
  - DAY3/eventlog_archives/yyyyMMdd
- Event cleanup quarantine:
  - DAY3/eventlog_quarantine/<runId>
- Startup disable quarantine:
  - DAY3/startup_quarantine/<runId>
- Rollback manifests:
  - DAY3/eventlog_quarantine/manifests/day_run_manifest_<runId>.json

## Operational note

Always run with DryRun first on production endpoints before any real change run.
