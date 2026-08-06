<#
.SYNOPSIS
    Read-only endpoint health report for DWP engineers (PowerShell 5.1).

.DESCRIPTION
    Collects and displays the following information about the local machine:
      1) System uptime          - How long the machine has been running since last reboot
      2) Free disk space        - Storage available on each local fixed drive
      3) Pending reboot status  - Whether Windows is waiting for a reboot (registry-based)
      4) Top 5 by memory        - Processes using the most RAM (Working Set)
      5) Top 5 by CPU           - Processes with the highest cumulative processor time
      6) Recent System errors   - Last 5 Error-level events from the Windows System log

    This script is strictly READ-ONLY. It does not modify any registry keys,
    files, services, or system settings of any kind.

.AUTHOR
    DWP Digital Engineering Team

.HOW TO RUN
    1. Open PowerShell. For full process path and event log visibility, run as Administrator:
          Right-click PowerShell -> "Run as Administrator"

    2. Navigate to the folder containing this script:
          cd C:\Path\To\Script

    3. On first run on a new machine, unblock the file if prompted:
          Unblock-File -Path .\endpoint_health_report.ps1

    4. Run the script:
          .\endpoint_health_report.ps1

    5. To save the output to a text file instead of (or as well as) the console:
          .\endpoint_health_report.ps1 | Out-File -FilePath C:\Temp\health_report.txt

.NOTES
    - Requires PowerShell 5.1 (built into Windows 10/11).
    - Some sections may show limited data without Administrator rights (process paths, event logs).
    - Every section is wrapped in try/catch so one failure does not stop the rest of the report.
#>


# ============================================================
# REPORT HEADER
# ============================================================

# Print the report title to the console in cyan so it stands out visually
Write-Host "`n=== Endpoint Health Report ===" -ForegroundColor Cyan

# Print the timestamp at which this report was generated (useful when saving output to a file)
Write-Host "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"


# ============================================================
# SECTION 1: System Uptime
# Purpose: Show when the machine last rebooted and how long it has been running.
# ============================================================
try {
    # Query WMI for operating system details; Win32_OperatingSystem is available on all Windows versions
    $operatingSystemInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop

    # Pull the last boot timestamp out of the WMI result object
    $lastBootTime = $operatingSystemInfo.LastBootUpTime

    # Subtract the boot time from the current time to get a TimeSpan representing uptime
    $systemUptime = (Get-Date) - $lastBootTime

    # Print the section heading in yellow to separate it visually from other sections
    Write-Host "`n[1] System Uptime" -ForegroundColor Yellow

    # Print the full date and time of the last reboot
    Write-Host ("Last Boot Time : {0}" -f $lastBootTime)

    # Print the uptime split into days, hours, and minutes for easy reading
    Write-Host ("Uptime         : {0} days, {1} hours, {2} minutes" -f $systemUptime.Days, $systemUptime.Hours, $systemUptime.Minutes)
}
catch {
    # If the WMI query failed for any reason, show the heading and the specific error message
    Write-Host "`n[1] System Uptime" -ForegroundColor Yellow
    Write-Host "Unable to retrieve uptime data: $($_.Exception.Message)" -ForegroundColor Red
}


# ============================================================
# SECTION 2: Free Disk Space
# Purpose: Show total size, free space, and free percentage for every local fixed drive.
# DriveType=3 means local fixed disk; this excludes USB drives, network shares, and CD drives.
# ============================================================
try {
    # Query WMI for all local fixed disks on this machine
    $localFixedDisks = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction Stop

    # Print the section heading
    Write-Host "`n[2] Free Disk Space" -ForegroundColor Yellow

    # Handle the unlikely case where no fixed disks are found
    if (-not $localFixedDisks) {
        Write-Host "No local fixed disks found."
    }
    else {
        # Build a formatted table by converting raw byte values into more readable units
        $diskSpaceReport = $localFixedDisks | Select-Object DeviceID,
            # Divide bytes by 1GB and round to 2 decimal places to get gigabytes
            @{Name='SizeGB';      Expression={[Math]::Round($_.Size / 1GB, 2)}},
            # Same conversion for free space
            @{Name='FreeGB';      Expression={[Math]::Round($_.FreeSpace / 1GB, 2)}},
            # Calculate free space as a percentage; the size check prevents division-by-zero on empty virtual drives
            @{Name='FreePercent'; Expression={
                if ($_.Size -gt 0) { [Math]::Round(($_.FreeSpace / $_.Size) * 100, 2) }
                else { 0 }
            }}

        # Print the disk report as a table; -AutoSize fits column widths to the content
        $diskSpaceReport | Format-Table -AutoSize
    }
}
catch {
    # If the WMI query failed for any reason, show the heading and the specific error message
    Write-Host "`n[2] Free Disk Space" -ForegroundColor Yellow
    Write-Host "Unable to retrieve disk data: $($_.Exception.Message)" -ForegroundColor Red
}


# ============================================================
# SECTION 3: Pending Reboot Check
# Purpose: Detect whether Windows is waiting for a reboot to finish applying changes.
# Windows signals a pending reboot by writing to specific registry keys or values.
# ============================================================
try {
    # Print the section heading
    Write-Host "`n[3] Pending Reboot Status (Registry)" -ForegroundColor Yellow

    # Define the three standard registry locations that Windows uses to flag a pending reboot.
    # 'KeyExists' means we check if the registry key itself is present.
    # 'ValueExists' means we check if a named value exists inside a key.
    $rebootIndicatorDefinitions = @(
        @{
            # CBS writes this key when a component update is applied and needs a reboot to complete
            Name      = 'Component Based Servicing RebootPending key'
            Path      = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
            Type      = 'KeyExists'
        },
        @{
            # Windows Update writes this key when one or more updates require a reboot to take effect
            Name      = 'Windows Update RebootRequired key'
            Path      = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
            Type      = 'KeyExists'
        },
        @{
            # Session Manager writes this value when files are locked and must be renamed on next reboot
            Name      = 'Session Manager PendingFileRenameOperations value'
            Path      = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
            ValueName = 'PendingFileRenameOperations'
            Type      = 'ValueExists'
        }
    )

    # Loop through each indicator definition and check the registry; collect results into $rebootCheckResults
    $rebootCheckResults = foreach ($rebootIndicator in $rebootIndicatorDefinitions) {

        # Start with the assumption that this indicator is not set
        $isRebootPending = $false

        # For key-based indicators: Test-Path returns true if the registry key exists
        if ($rebootIndicator.Type -eq 'KeyExists') {
            $isRebootPending = Test-Path -Path $rebootIndicator.Path
        }
        # For value-based indicators: try to read the named value; a non-null result means it is present
        elseif ($rebootIndicator.Type -eq 'ValueExists') {
            # SilentlyContinue suppresses the error if the key or value does not exist
            $registryValue = Get-ItemProperty -Path $rebootIndicator.Path -Name $rebootIndicator.ValueName -ErrorAction SilentlyContinue
            $isRebootPending = $null -ne $registryValue
        }

        # Output a result object for this indicator; the foreach loop collects these into $rebootCheckResults
        [PSCustomObject]@{
            Indicator    = $rebootIndicator.Name
            Pending      = $isRebootPending
            RegistryPath = $rebootIndicator.Path
        }
    }

    # Print all three indicator results as a table so they can be reviewed at a glance
    $rebootCheckResults | Format-Table -AutoSize

    # If any single indicator returned true, the machine needs a reboot — highlight this in red
    if ($rebootCheckResults.Pending -contains $true) {
        Write-Host "Overall Pending Reboot: YES" -ForegroundColor Red
    }
    else {
        # All indicators are clear — no reboot is required
        Write-Host "Overall Pending Reboot: NO" -ForegroundColor Green
    }
}
catch {
    # If an unexpected error occurred during the registry checks, show the heading and error message
    Write-Host "`n[3] Pending Reboot Status (Registry)" -ForegroundColor Yellow
    Write-Host "Unable to evaluate reboot indicators: $($_.Exception.Message)" -ForegroundColor Red
}


# ============================================================
# SECTION 4: Top 5 Processes by Memory (Working Set)
# Purpose: Identify which processes are consuming the most physical RAM right now.
# Working Set = the amount of RAM currently allocated to a process by the OS.
# NOTE: Run as Administrator to see executable paths for all processes.
# ============================================================
try {
    # Print the section heading
    Write-Host "`n[4] Top 5 Processes by Memory (Working Set)" -ForegroundColor Yellow

    # Retrieve all running processes, sort by RAM usage highest-first, keep only the top 5
    $topMemoryProcesses = Get-Process -ErrorAction Stop |
        Sort-Object -Property WorkingSet64 -Descending |
        Select-Object -First 5

    # Build and print the output table with memory in MB and executable details
    $topMemoryProcesses |
        Select-Object ProcessName,
            Id,
            # Convert WorkingSet64 (bytes) to megabytes rounded to 2 decimal places
            @{Name='WorkingSetMB';  Expression={[Math]::Round($_.WorkingSet64 / 1MB, 2)}},
            # Split-Path -Leaf extracts just the filename (e.g. chrome.exe) from the full path
            @{Name='ExecutableName'; Expression={
                if ($_.Path) { Split-Path -Path $_.Path -Leaf }
                else { "$($_.ProcessName).exe" }
            }},
            # Show the full disk path to the executable; system processes may not expose this without admin rights
            @{Name='ExecutablePath'; Expression={
                if ($_.Path) { $_.Path }
                else { '[Path unavailable - verify privileges/process access]' }
            }} |
        Format-Table -Wrap -AutoSize
}
catch {
    # If the process query failed for any reason, show the heading and the specific error message
    Write-Host "`n[4] Top 5 Processes by Memory (Working Set)" -ForegroundColor Yellow
    Write-Host "Unable to retrieve process memory data: $($_.Exception.Message)" -ForegroundColor Red
}


# ============================================================
# SECTION 5: Top 5 Processes by CPU
# Purpose: Identify which processes have consumed the most processor time since they started.
# IMPORTANT: The CPU property is CUMULATIVE total seconds used since the process launched,
#            not a current percentage. A long-running idle process may outrank a briefly busy one.
# NOTE: Run as Administrator to see executable paths for all processes.
# ============================================================
try {
    # Print the section heading
    Write-Host "`n[5] Top 5 Processes by CPU" -ForegroundColor Yellow

    # Retrieve all processes, skip any where CPU is null (some kernel processes report nothing),
    # sort by cumulative CPU seconds highest-first, keep only the top 5
    $topCpuProcesses = Get-Process -ErrorAction Stop |
        Where-Object { $null -ne $_.CPU } |
        Sort-Object -Property CPU -Descending |
        Select-Object -First 5

    # Build and print the output table with CPU seconds and executable details
    $topCpuProcesses |
        Select-Object ProcessName,
            Id,
            # Round the cumulative CPU time to 2 decimal places for readability
            @{Name='CPUSeconds';    Expression={[Math]::Round($_.CPU, 2)}},
            # Split-Path -Leaf extracts just the filename (e.g. chrome.exe) from the full path
            @{Name='ExecutableName'; Expression={
                if ($_.Path) { Split-Path -Path $_.Path -Leaf }
                else { "$($_.ProcessName).exe" }
            }},
            # Show the full disk path to the executable; system processes may not expose this without admin rights
            @{Name='ExecutablePath'; Expression={
                if ($_.Path) { $_.Path }
                else { '[Path unavailable - verify privileges/process access]' }
            }} |
        Format-Table -Wrap -AutoSize
}
catch {
    # If the process query failed for any reason, show the heading and the specific error message
    Write-Host "`n[5] Top 5 Processes by CPU" -ForegroundColor Yellow
    Write-Host "Unable to retrieve process CPU data: $($_.Exception.Message)" -ForegroundColor Red
}


# ============================================================
# SECTION 6: Last 5 System Log Errors
# Purpose: Surface the most recent Error-level events from the Windows System event log.
# Level=2 means Error only; this excludes Warnings (3) and Informational events (4).
# NOTE: Reading event logs may require Administrator rights in some environments.
# ============================================================
try {
    # Print the section heading
    Write-Host "`n[6] Last 5 System Log Errors" -ForegroundColor Yellow

    # Query the System event log for up to 5 Error-level entries, most recent first
    $systemLogErrors = Get-WinEvent -FilterHashtable @{LogName='System'; Level=2} -MaxEvents 5 -ErrorAction Stop

    # If the System log has no errors at all, tell the user explicitly
    if (-not $systemLogErrors) {
        Write-Host "No recent System log errors found."
    }
    else {
        # Select the most useful fields and display them in a wrapped table so long messages are not cut off
        $systemLogErrors |
            Select-Object TimeCreated, Id, ProviderName, LevelDisplayName, Message |
            Format-Table -Wrap -AutoSize
    }
}
catch {
    # If the event log query failed (e.g. insufficient permissions), show the heading and error message
    Write-Host "`n[6] Last 5 System Log Errors" -ForegroundColor Yellow
    Write-Host "Unable to retrieve System log errors: $($_.Exception.Message)" -ForegroundColor Red
}


# ============================================================
# END OF REPORT
# ============================================================

# Print the closing footer banner to clearly mark where the report output ends
Write-Host "`n=== End of Report ===" -ForegroundColor Cyan
