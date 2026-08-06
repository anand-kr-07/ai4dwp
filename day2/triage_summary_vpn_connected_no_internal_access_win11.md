# Triage Summary - T-1008

## Summary (one line)
After Windows 11 upgrade, VPN shows connected but internal resources are unreachable, suggesting route, DNS, adapter, or policy application issue post-upgrade (to-verify).

## Impact (who/how many/business urgency)
- Who: Reported remote user/device using VPN.
- How many: One reported user/device so far (to-verify).
- Business urgency: High (to-verify) if user cannot reach core internal apps/services.

## Known facts
- Ticket ID: T-1008.
- Symptom: VPN connects.
- Symptom: No internal resources reachable.
- Change context: Problem started after Windows 11 upgrade.

## Missing information to gather
- Whether internet access works while VPN is connected.
- Whether internal access fails by hostname only, by IP only, or both.
- VPN client version and profile used; whether reinstall/repair was attempted.
- Whether other upgraded users with same VPN profile are affected.
- Whether local firewall/security client changes were made post-upgrade (to-verify).
- Whether problem occurs on all networks or only specific network locations.
- Exact internal resources tested and failure behavior (timeout, name resolution, auth prompt) (to-verify).

## Likely catagory
Network and Remote Access - VPN post-Windows 11 upgrade connectivity/routing issue (to-verify).

## First diagnostic step
On the affected device while VPN is connected, validate assigned VPN adapter details plus route and DNS resolution behavior for one known internal target to determine whether failure is name resolution, routing path, or upstream access policy (to-verify).
