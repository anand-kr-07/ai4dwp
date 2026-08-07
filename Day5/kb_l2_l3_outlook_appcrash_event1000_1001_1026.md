Title: L2/L3 KB - Outlook APPCRASH (Event 1000/1001/1026) Diagnostic and Recovery
Version: v 1.0
Date: 07/08/2026
Status : Draft

## Background
Outlook is the primary desktop client for user email, calendar, and meeting workflows. When Outlook crashes repeatedly after launch, the user cannot reliably send/receive email, manage meetings, or search mailbox content. This is a high business-impact endpoint issue even when Microsoft 365 backend services are healthy.

## Symptom
Engineer observes:
1. Outlook closes within minutes of launch, often after startup.
2. Repeated crash entries exist in Windows Application log.
3. Crash signature repeats with same module and fault offset.

User reports:
1. "Outlook opens, then suddenly closes."
2. "It works in short bursts, then crashes again."
3. "Restart did not permanently fix it."

## Root Cause
Specific technical cause:
- Reproducible Outlook access-violation crash path during initialization/runtime, commonly triggered by add-in/profile/cache state reloaded at startup.

Evidence that confirms it:
1. Event ID 1000 appears multiple times with:
- Faulting application name: OUTLOOK.EXE
- Faulting module name: KERNELBASE.dll
- Exception code: 0xc0000005
- Same fault offset across crashes
2. Event ID 1001 shows APPCRASH bucket for the same incident window.
3. Event ID 1026 shows unhandled System.AccessViolationException for OUTLOOK.EXE.
4. First crash occurs shortly after Outlook startup and repeats after relaunch.

## Detection
Target completion time: under 3 minutes.

1. Open the affected user session and launch Event Viewer at Event Viewer > Windows Logs > Application.
Expected result: You are viewing the Application log on the affected endpoint.

2. In Event Viewer > Windows Logs > Application, click Filter Current Log and set Event IDs to 1000,9009.
Expected result: The Application log list shows only Event 1000 and Event 9009.

3. Open the newest Event 1000 in Application log and check these fields in General/Details:
- Event ID: 1000
- Faulting application name: OUTLOOK.EXE
- Faulting module name: igdumd64.dll
Expected result: Event 1000 explicitly contains OUTLOOK.EXE and igdumd64.dll.

4. Open the nearest Event 9009 in Application log (same user session, same incident window) and compare TimeCreated with Event 1000.
Expected result: Event 9009 occurs in the same incident window as Event 1000 (typically within a few minutes).

5. Run this PowerShell command on the affected endpoint to extract Application log evidence quickly:
`Get-WinEvent -FilterHashtable @{LogName='Application'; Id=1000,9009; StartTime=(Get-Date).AddHours(-8)} | Sort-Object TimeCreated -Descending | Select-Object -First 20 TimeCreated, Id, ProviderName, MachineName, Message | Format-List`
Expected result: Output shows Event 1000 and Event 9009 entries, including Message text for fast validation.

6. In the output, confirm at least one Event 1000 message contains both OUTLOOK.EXE and igdumd64.dll.
Expected result: Crash signature match is confirmed on the affected endpoint.

7. Run this PowerShell command on control host POOL-FIN-02 to collect healthy baseline from Application log:
`Get-WinEvent -ComputerName 'POOL-FIN-02' -FilterHashtable @{LogName='Application'; Id=9011; StartTime=(Get-Date).AddHours(-24)} | Sort-Object TimeCreated -Descending | Select-Object -First 10 TimeCreated, Id, ProviderName, MachineName, Message | Format-List`
Expected result: Event 9011 is present on POOL-FIN-02 as the unaffected control baseline.

8. Perform comparison check (affected host vs POOL-FIN-02).
Expected result: Affected host shows Event 1000 + Event 9009 crash pattern with igdumd64.dll, while POOL-FIN-02 shows Event 9011 baseline and no matching crash pattern.

## Resolution

1. Open Azure portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts > FIN01-HOST-01.
Expected result: You are on the affected session host details page.

2. In FIN01-HOST-01, set Allow new sessions to Off and click Save.
Expected result: FIN01-HOST-01 enters drain mode and no new users are placed on this host.

3. Run this Azure CLI command to enforce drain mode quickly:
```bash
az desktopvirtualization session-host update \
	--resource-group <rg-avd-prod> \
	--host-pool-name POOL-FIN-01 \
	--name FIN01-HOST-01 \
	--allow-new-session false
```
Expected result: Command returns allowNewSession as false.

4. Open Azure portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > User sessions.
Expected result: Active user sessions list for POOL-FIN-01 is visible.

5. Send a maintenance message to impacted sessions from the User sessions page.
Expected result: Users receive a warning and save work before session move/logoff.

6. Run this Azure CLI command to list active sessions on FIN01-HOST-01:
```bash
az desktopvirtualization user-session list \
	--resource-group <rg-avd-prod> \
	--host-pool-name POOL-FIN-01 \
	--session-host-name FIN01-HOST-01 \
	--query "[].{session: name, user: userPrincipalName, state: sessionState}" -o table
```
Expected result: You get the exact session IDs and users on the affected host.

7. Log off affected sessions from FIN01-HOST-01 after notice period.
Expected result: Users reconnect to healthy hosts in the pool.

8. Run this Azure CLI command to restart the affected host:
```bash
az vm restart --resource-group <rg-avd-prod> --name FIN01-HOST-01
```
Expected result: VM restart is accepted and host returns to running state.

9. Open Azure portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts > FIN01-HOST-01 > Virtual machine > Settings > Extensions + applications.
Expected result: Host extension/app status is visible and healthy.

10. Open Azure portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts > FIN01-HOST-01 > Virtual machine > Settings > Properties > Image.
Expected result: Current image publisher/offer/sku/version is visible for the affected host.

11. Run this Azure CLI command to capture current image version on FIN01-HOST-01:
```bash
az vm show \
	--resource-group <rg-avd-prod> \
	--name FIN01-HOST-01 \
	--query "storageProfile.imageReference" -o table
```
Expected result: Image details are returned for incident notes and comparison.

12. On FIN01-HOST-01, run Outlook remediation with Run command.
Path: Azure portal > Virtual machines > FIN01-HOST-01 > Operations > Run command > RunPowerShellScript.
Script: close Outlook process; launch Outlook safe mode test; apply add-in/profile/OST remediation from runbook if needed.
Expected result: Outlook on this host no longer reproduces the crash signature.

## Verification

1. Open Azure portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts > FIN01-HOST-01.
Expected result: Host shows Available state and expected health.

2. Open Azure portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts > FIN01-HOST-01 > Virtual machine > Settings > Properties > Image.
Expected result: Image value matches approved baseline for POOL-FIN-01.

3. Open Azure portal > Azure Virtual Desktop > Host pools > POOL-FIN-02 > Session hosts > POOL-FIN-02-CONTROL-01 > Virtual machine > Settings > Properties > Image.
Expected result: Control host image is visible for side-by-side comparison.

4. Compare FIN01-HOST-01 image with POOL-FIN-02-CONTROL-01 image.
Expected result: Either image parity is confirmed or delta is documented as remediation clue.

5. Run this Azure CLI command to verify current host drain setting:
```bash
az desktopvirtualization session-host show \
	--resource-group <rg-avd-prod> \
	--host-pool-name POOL-FIN-01 \
	--name FIN01-HOST-01 \
	--query "{host:name,allowNewSession:allowNewSession,status:status}" -o table
```
Expected result: Host state and allowNewSession value match intended post-fix state.

6. Run this Azure CLI command to check crash events quickly on FIN01-HOST-01:
```bash
az vm run-command invoke \
	--resource-group <rg-avd-prod> \
	--name FIN01-HOST-01 \
	--command-id RunPowerShellScript \
	--scripts "Get-WinEvent -FilterHashtable @{LogName='Application'; Id=1000,9009; StartTime=(Get-Date).AddMinutes(-30)} | Select-Object TimeCreated,Id,ProviderName,Message | Format-List"
```
Expected result: No new Event 1000 with OUTLOOK.EXE and igdumd64.dll in last 30 minutes.

7. Run this Azure CLI command to verify user sessions are stable after reconnect:
```bash
az desktopvirtualization user-session list \
	--resource-group <rg-avd-prod> \
	--host-pool-name POOL-FIN-01 \
	--query "[].{sessionHost:sessionHostName,user:userPrincipalName,state:sessionState}" -o table
```
Expected result: Users are connected without rapid reconnect/disconnect churn.

8. Re-enable new sessions on FIN01-HOST-01 only after all checks pass.
Path: Azure portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts > FIN01-HOST-01 > Allow new sessions On > Save.
Expected result: Host is back in rotation with no immediate crash recurrence.

## Rollback

1. Open Azure portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts > FIN01-HOST-01.
Expected result: Affected host control page is open.

2. Keep Allow new sessions set to Off and click Save.
Expected result: No new users are routed to the unstable host.

3. Run this Azure CLI command to confirm drain mode remains enforced:
```bash
az desktopvirtualization session-host update \
	--resource-group <rg-avd-prod> \
	--host-pool-name POOL-FIN-01 \
	--name FIN01-HOST-01 \
	--allow-new-session false
```
Expected result: allowNewSession stays false.

4. Open Azure portal > Azure Virtual Desktop > Host pools > POOL-FIN-01 > Session hosts > FIN01-HOST-01 > Virtual machine > Settings > Properties > Image.
Expected result: Current image version is visible for rollback decision.

5. If the host image differs from control, restore to last known-good image version used by POOL-FIN-02-CONTROL-01.
Path: Azure portal > Compute Gallery (or Image definition source) > Versions > select last known-good > Deploy VM/Update host workflow for FIN01-HOST-01.
Expected result: Host is redeployed or updated to known-good image baseline.

6. For VMSS-based host pools, run this Azure CLI rollback command to pinned image version:
```bash
az vmss update \
	--resource-group <rg-avd-prod> \
	--name <vmss-fin01> \
	--set virtualMachineProfile.storageProfile.imageReference.id=<sig-image-version-id>

az vmss rolling-upgrade start \
	--resource-group <rg-avd-prod> \
	--name <vmss-fin01>
```
Expected result: FIN01 hosts move back to known-good image version.

7. If not VMSS, run this Azure CLI command to rebuild the single host from known-good image and keep users on alternate hosts until complete:
```bash
az vm deallocate --resource-group <rg-avd-prod> --name FIN01-HOST-01
az vm generalize --resource-group <rg-avd-prod> --name FIN01-HOST-01
```
Expected result: Host is removed from active service and prepared for controlled rebuild.

8. Keep impacted users on control capacity.
Path: Azure portal > Azure Virtual Desktop > Host pools > POOL-FIN-02 > Session hosts > POOL-FIN-02-CONTROL-01.
Expected result: Users continue working while FIN01 rollback completes.

## Preventive

1. Endpoint crash alert rule (existing control, strengthened).
Owner: DWP engineer | Timing: during deployment | Type: Automated.
Path: Azure portal > Monitor > Alerts > Create > Alert rule; signal = Application log Event ID 1000 where OUTLOOK.EXE and exception 0xc0000005, threshold >=2 in 15 minutes per host.
Pass/Fail and action: Pass when alert fires in test and routes to on-call group in <5 minutes; fail if no fire or delayed route, then halt rollout and place host in drain mode.

2. WER fault-bucket tracking workbook (existing control, strengthened) [REQUIRES: standardized Log Analytics ingestion for WER/Application logs].
Owner: Release engineer | Timing: during and after deployment | Type: Automated.
Path: Azure portal > Monitor > Workbooks > New; track Event ID 1001 APPCRASH bucket counts by host pool and 15-minute bins.
Pass/Fail and action: Pass when current bucket count stays <= baseline +20%; fail when >20% or new dominant bucket appears, then stop wave and trigger rollback review.

3. Outlook add-in allowlist policy (existing control, strengthened).
Owner: Image owner | Timing: before deployment | Type: Automated.
Path: Intune admin center > Devices > Configuration profiles > Administrative Templates > Microsoft Outlook > COM Add-ins; allow approved CLSIDs only.
Pass/Fail and action: Pass when compliance report shows >=98% targeted devices compliant; fail if <98% or unknown add-in enabled, then block release to production ring.

4. Staged release rings for Microsoft 365 Apps (existing control, strengthened).
Owner: Release engineer | Timing: during deployment | Type: Automated.
Path: Intune admin center > Apps > Microsoft 365 Apps > Update channel policy; pilot 5-10% for 7 days before broad wave.
Pass/Fail and action: Pass when pilot has <1 Outlook Event 1000 per 100 user sessions/day and no Event 9009 spike; fail otherwise, then pause deployment and rollback pilot.

5. Mandatory incident data-capture template (existing control, strengthened) [REQUIRES: ITSM form validation rules].
Owner: Service desk lead | Timing: after deployment (on incident intake) | Type: Manual.
Path: ITSM Knowledge/Ticket Template > Outlook Crash; require Event IDs 1000/1001/1026/9009, fault module, offset, add-in state, profile/OST actions.
Pass/Fail and action: Pass when >=95% tickets contain all mandatory fields; fail when incomplete, then reject ticket for completion. Automation note: enforce required fields in ticket form.

6. Pre-deployment smoke-test gate (added gap control).
Owner: DWP engineer | Timing: before deployment | Type: Manual.
Path: Azure Virtual Desktop > Host pools > POOL-FIN-01 pilot host; run 15-minute Outlook launch/send/search test and check Application log for Event 1000/9009.
Pass/Fail and action: Pass with zero Event 1000/9009 and no crash; fail on any hit, then cancel change window. Automation note: script test via az vm run-command.

7. In-flight rollout monitor window (added gap control).
Owner: Change manager | Timing: during deployment | Type: Automated.
Path: Azure portal > Monitor > Alerts + Workbook dashboard; watch Event 1000, 1001, 9009 rate every 15 minutes for active rollout pool.
Pass/Fail and action: Pass when all alert thresholds remain below trigger; fail on threshold breach, then freeze next wave and open incident bridge.

8. Post-deployment validation gate (added gap control) [REQUIRES: formal change-close checklist].
Owner: Change manager | Timing: after deployment | Type: Manual.
Path: Azure Virtual Desktop > Host pools > POOL-FIN-01 and POOL-FIN-02 control comparison + Application log check for last 24 hours.
Pass/Fail and action: Pass when no sustained increase in Event 1000/9009 and user-impact tickets do not exceed baseline; fail otherwise, keep change open and execute rollback plan.

9. Rollback trigger threshold (added gap control).
Owner: Release engineer | Timing: during deployment | Type: Automated.
Path: Alert rule + deployment pipeline guard; trigger rollback when >=3 affected users or >=5 Event 1000/9009 on one host in 30 minutes.
Pass/Fail and action: Pass when trigger executes tested rollback workflow in staging; fail if trigger does not execute, then perform manual rollback immediately and raise PIR action.

10. Knowledge and checklist update loop (added gap control) [REQUIRES: KB review workflow].
Owner: Service desk lead | Timing: after deployment/after incident closure | Type: Manual.
Path: Update [Day5/runbook_outlook_appcrash_event1000_1001_1026.md](Day5/runbook_outlook_appcrash_event1000_1001_1026.md) and [Day5/kb_l1_outlook_closes_unexpectedly.md](Day5/kb_l1_outlook_closes_unexpectedly.md) with lessons learned.
Pass/Fail and action: Pass when KB version increments and checklist is republished within 2 business days; fail if overdue, then escalate to change manager for closure hold.

## Related

1. [Day5/runbook_outlook_appcrash_event1000_1001_1026.md](Day5/runbook_outlook_appcrash_event1000_1001_1026.md)
2. [Day5/kb_l1_outlook_closes_unexpectedly.md](Day5/kb_l1_outlook_closes_unexpectedly.md)
3. [day2/triage_summary_shared_mailbox_post_migration.md](day2/triage_summary_shared_mailbox_post_migration.md)
4. [day2/triage_summary_onedrive_processing_changes_missing_local_files.md](day2/triage_summary_onedrive_processing_changes_missing_local_files.md)
5. [DAY3/rca_outlook_appcrash_20240315.md](DAY3/rca_outlook_appcrash_20240315.md)
