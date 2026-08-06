# DWP Temp Cleanup Script

This folder contains a safe Windows PowerShell 5.1 temp cleanup script for endpoint support engineers.

## File

- `temp_cleanup_safe.ps1`

## What the script does

- Scans temp folders (default: user temp and Windows temp).
- Targets only files older than a configurable number of days.
- Supports a dry-run mode that lists files it would remove.
- Skips locked files and logs the skip without stopping the run.
- Uses per-file try/catch error handling.
- Logs all actions to a timestamped log file.
- Prints a summary at the end.
- Supports rollback by restoring files from a manifest.
- Is idempotent:
  - Re-running cleanup does not reprocess already moved files.
  - Re-running rollback safely skips files already restored or missing from staging.

## Parameters

- `-Paths <string[]>`
  - One or more folders to scan.
  - Default: `$env:TEMP` and `$env:WINDIR\Temp`.

- `-OlderThanDays <int>`
  - Minimum file age in days.
  - Default: `0`.

- `-DryRun`
  - Lists files that would be removed.
  - Does not move or delete files.

- `-Rollback`
  - Restores files from a prior run manifest.

- `-ManifestPath <string>`
  - Path to a manifest CSV file created during cleanup.
  - If omitted with `-Rollback`, the script uses the latest manifest found under staging.

- `-LogRoot <string>`
  - Folder for timestamped logs.
  - Default: `DAY3\logs` (relative to script path).

- `-StagingRoot <string>`
  - Folder where files are staged for rollback.
  - Default: `$env:ProgramData\DWPTempCleanup\Staging`.

## Usage examples

### 1) Dry run with default age filter

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\DAY3\temp_cleanup_safe.ps1 -DryRun
```

### 2) Dry run for files older than 7 days

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\DAY3\temp_cleanup_safe.ps1 -DryRun -OlderThanDays 7
```

### 3) Cleanup files older than 14 days in default paths

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\DAY3\temp_cleanup_safe.ps1 -OlderThanDays 14
```

### 4) Cleanup with custom path list

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\DAY3\temp_cleanup_safe.ps1 -Paths "C:\Windows\Temp","C:\Users\Public\Temp" -OlderThanDays 3
```

### 5) Rollback using the latest manifest automatically

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\DAY3\temp_cleanup_safe.ps1 -Rollback
```

### 6) Rollback using a specific manifest

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\DAY3\temp_cleanup_safe.ps1 -Rollback -ManifestPath "C:\ProgramData\DWPTempCleanup\Staging\20260805_120000_ab12cd34\manifest_20260805_120000_ab12cd34.csv"
```

## Operational notes

- Review dry-run output before performing cleanup in production.
- Keep staging content until you are sure rollback is no longer needed.
- The script currently stages files (safe removal) rather than permanently deleting them.
  - If permanent deletion is required, define a retention policy and purge staged files after that retention window.
