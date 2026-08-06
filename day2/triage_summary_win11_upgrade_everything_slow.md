# Triage Summary - T-1006

## Summary (one line)
User reports system-wide slowness two days after Windows 11 upgrade, likely related to post-upgrade background processing, driver compatibility, or resource contention (to-verify).

## Impact (who/how many/business urgency)
- Who: Single reported user/device.
- How many: One reported case so far (to-verify).
- Business urgency: Medium (to-verify), potentially High if role-critical tasks are blocked.

## Known facts
- Ticket ID: T-1006.
- Symptom statement: "Everything is slow."
- Change context: User upgraded to Windows 11 two days ago.

## Missing information to gather
- Whether slowness is constant or tied to specific apps/actions.
- Current CPU, memory, and disk utilization pattern during slowdown.
- Device free disk percentage and storage type.
- Whether updates, indexing, antivirus scans, or sync are still running post-upgrade.
- Whether startup apps changed after upgrade.
- Whether issue persists after clean reboot.
- Whether other recently upgraded users show similar behavior (to-verify).

## Likely catagory
Endpoint Performance - Post-Windows 11 upgrade degradation (to-verify).

## First diagnostic step
Open Task Manager and monitor CPU, memory, and disk for several minutes during active slowness to identify the dominant bottleneck process before applying remediation; this avoids blind changes and narrows root cause quickly.
