# DWP Event Log Archive and Cleanup Script

This folder includes a safe Windows PowerShell 5.1 script to archive old Windows event logs and clean old archive data using a rollback-friendly workflow.

## File

- `event_log_archive_cleanup_safe.ps1`

## What the script does

- Exports events older than a configurable age from selected logs (`Application`, `System`, `Security` by default).
- Uses idempotent archive behavior:
  - If today's archive file already exists for a log, that log is skipped.
- Cleans up old archive files older than the same age threshold.
- In cleanup mode, uses soft-delete by moving files to quarantine so rollback is possible.
- Supports dry-run mode that reports record counts it would clean without changing anything.
- Logs every action to a timestamped log file in `DAY3\logs`.
- Prints a summary at the end.

## Safety model

- The script does not hard-delete archive files during cleanup.
- Cleanup moves files to `DAY3\eventlog_quarantine` and writes a rollback manifest.
- `-Rollback` restores files from quarantine back to original archive paths.

## Parameters

- `-OlderThanDays <int>`
  - Age threshold in days for archive filtering and cleanup selection.
  - Default: `3`.

- `-DryRun`
  - Simulates archive and cleanup actions.
  - Prints how many records would be cleaned (`Records to delete`).
  - Makes no filesystem changes.

- `-Rollback`
  - Restores quarantined archive files from a previous cleanup run.

- `-RollbackManifestPath <string>`
  - Optional explicit path to a manifest JSON from a prior cleanup run.
  - If omitted with `-Rollback`, latest manifest is selected automatically.

- `-LogNames <string[]>`
  - Logs to archive.
  - Default: `Application`, `System`, `Security`.

- `-ArchiveRoot <string>`
  - Optional archive storage root.
  - Default: `DAY3\eventlog_archives`.

- `-QuarantineRoot <string>`
  - Optional quarantine storage root.
  - Default: `DAY3\eventlog_quarantine`.

- `-LogRoot <string>`
  - Optional operation log output folder.
  - Default: `DAY3\logs`.

## Usage examples

### 1) Dry run (default threshold: 3 days)

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\DAY3\event_log_archive_cleanup_safe.ps1 -DryRun
```

### 2) Dry run with a 7-day threshold

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\DAY3\event_log_archive_cleanup_safe.ps1 -DryRun -OlderThanDays 7
```

### 3) Run archive and cleanup

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\DAY3\event_log_archive_cleanup_safe.ps1 -OlderThanDays 3
```

### 4) Use custom log list

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\DAY3\event_log_archive_cleanup_safe.ps1 -LogNames Application,System,"Microsoft-Windows-WindowsUpdateClient/Operational" -OlderThanDays 5
```

### 5) Rollback latest cleanup run

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\DAY3\event_log_archive_cleanup_safe.ps1 -Rollback
```

### 6) Rollback with a specific manifest file

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\DAY3\event_log_archive_cleanup_safe.ps1 -Rollback -RollbackManifestPath ".\DAY3\eventlog_quarantine\manifests\cleanup_manifest_20260805_120000_ab12cd34.json"
```

## Operational notes

- Always run `-DryRun` first in production.
- Keep quarantine data until validation is complete.
- Logs and manifest files provide a full audit trail for each run.
