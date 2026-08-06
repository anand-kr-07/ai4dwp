# Triage Summary - T-1004

## Summary (one line)
Company app installation fails from Company Portal with error 0x87D1041C, indicating likely deployment requirement, assignment, detection, or app content issue (to-verify).

## Impact (who/how many/business urgency)
- Who: Reported user/device attempting app install.
- How many: One reported user/device (to-verify).
- Business urgency: Medium-High (to-verify) if app is required for role-critical tasks.

## Known facts
- Ticket ID: T-1004.
- Channel: Company Portal.
- Symptom: Company app fails to install.
- Reported code: 0x87D1041C.

## Missing information to gather
- Exact app name/version and whether it is required or available deployment.
- Whether failure occurs on multiple devices or only this device.
- Device compliance/enrollment state at time of install attempt.
- Available disk space and pending reboot state on device.
- Whether app dependencies/prerequisites are present (to-verify).
- Install attempt timestamp for backend log correlation.
- Whether same user can install other Company Portal apps.

## Likely catagory
Endpoint Management - Intune/Company Portal app deployment failure (to-verify).

## First diagnostic step
Check Intune app deployment status for this device and user at the reported timestamp, focusing on assignment, requirement rule evaluation, and detection result to identify the first failing stage in the install workflow (to-verify).
