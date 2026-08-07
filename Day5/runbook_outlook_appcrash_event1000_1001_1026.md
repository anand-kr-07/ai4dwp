Title: Runbook - Outlook APPCRASH (Event ID 1000/1001/1026) - Access Violation
Version: 1.0
Date: 07/08/2026
Author: Sathishbabu
Reviewed: self
Status: draft
Change: initial version from RCA

# Runbook: Outlook APPCRASH (Event ID 1000/1001/1026) - Access Violation

## Prerequisites

1. Confirm you are working on the affected endpoint where Outlook crashes.
Expected result: You have physical or remote interactive access to the exact user session and device.

2. Confirm the user can sign in and reproduce the issue on demand.
Expected result: You can start Outlook in the affected profile and observe current behavior.

3. Obtain local administrator rights on the endpoint. [ELEVATED]
Expected result: You can run Control Panel applets and Office repair operations without permission errors.

4. Ensure you have rights to review Windows Event Viewer logs.
Expected result: You can open Application log entries for Event IDs 1000, 1001, and 1026.

5. Ensure Outlook desktop app (Microsoft Office 16) is installed on the endpoint.
Expected result: OUTLOOK.EXE is present and can be launched.

6. Ensure network connectivity to Microsoft 365 services is stable.
Expected result: The endpoint has internet access and can reach Exchange Online endpoints.

7. Ensure at least 5 GB free disk space on the system drive. [ELEVATED]
Expected result: Office repair and OST rebuild operations can complete without low-disk failure.

8. Close all Office apps before starting remediation.
Expected result: No WINWORD.EXE, EXCEL.EXE, or OUTLOOK.EXE process remains in Task Manager.

## Procedure

1. Press Windows+R, type `outlook.exe /safe`, and press Enter.
Expected result: Outlook opens in Safe Mode and the title bar shows "Microsoft Outlook (Safe Mode)".

2. If prompted to choose a profile, select the affected user profile and click OK.
Expected result: The affected mailbox opens in Safe Mode.

3. Keep Outlook open for 10 minutes without closing it.
Expected result: No crash dialog appears and Outlook remains responsive.

4. Close Outlook by selecting File > Exit.
Expected result: Outlook window closes.

5. Open Task Manager with Ctrl+Shift+Esc.
Expected result: Task Manager opens.

6. In Task Manager > Processes, confirm `OUTLOOK.EXE` is not present.
Expected result: No Outlook process is running.

7. Start Outlook in normal mode from Start menu > Outlook.
Expected result: Outlook opens without Safe Mode in the title bar.

8. In Outlook, open File > Options > Add-ins.
Expected result: Add-ins settings page is displayed.

9. In Manage, select COM Add-ins and click Go.
Expected result: COM Add-ins dialog opens with checkbox list.

10. Copy all currently enabled add-in names into the incident ticket.
Expected result: A complete pre-change add-in baseline is documented in the ticket.

11. Clear the checkbox for each non-Microsoft add-in in the COM Add-ins dialog.
Expected result: Only Microsoft add-ins remain checked.

12. Click OK in the COM Add-ins dialog.
Expected result: Add-in changes are saved with no error prompt.

13. Close Outlook by selecting File > Exit.
Expected result: Outlook closes cleanly.

14. Reopen Outlook from Start menu > Outlook.
Expected result: Outlook starts and does not crash during launch.

15. Keep Outlook open for 10 minutes.
Expected result: No crash dialog appears and user can open Inbox and Calendar.

16. Open File > Options > Add-ins > Manage COM Add-ins > Go.
Expected result: COM Add-ins dialog opens.

17. Enable exactly one previously disabled non-Microsoft add-in by checking its box.
Expected result: One non-Microsoft add-in changes from disabled to enabled.

18. Click OK in the COM Add-ins dialog.
Expected result: Updated add-in state is saved.

19. Close Outlook by selecting File > Exit.
Expected result: Outlook closes cleanly.

20. Reopen Outlook from Start menu > Outlook.
Expected result: Outlook launches with the selected add-in enabled.

21. Keep Outlook open for 5 minutes.
Expected result: Either Outlook stays stable or reproduces the crash with this add-in enabled.

22. Record the add-in test outcome in the ticket.
Expected result: Ticket contains pass/fail result for that specific add-in.

23. Repeat steps 16 through 22 for each remaining disabled non-Microsoft add-in.
Expected result: One offending add-in is identified, or all tested add-ins are excluded.

24. Leave the identified offending add-in unchecked.
Expected result: Offending add-in remains disabled.

25. Open Windows Settings > Apps > Installed apps.
Expected result: Installed apps list is visible.

26. Search for "Microsoft 365 Apps" in Installed apps.
Expected result: Microsoft 365 Apps entry is displayed.

27. Select Microsoft 365 Apps > More options (three dots) > Modify. [ELEVATED]
Expected result: Office repair dialog opens.

28. Select Quick Repair and click Repair. [ELEVATED]
Expected result: Repair completes and shows completion message.

29. Restart Windows from Start > Power > Restart.
Expected result: Device reboots and user can sign back in.

30. Launch Outlook in normal mode from Start menu > Outlook.
Expected result: Outlook opens and remains stable for at least 10 minutes.

31. If Outlook still crashes, open Windows Settings > Apps > Installed apps > Microsoft 365 Apps > More options > Modify. [ELEVATED]
Expected result: Office repair dialog opens again.

32. Select Online Repair and click Repair. [ELEVATED]
Expected result: Online Repair completes and requests/signals app relaunch completion.

33. Restart Windows from Start > Power > Restart.
Expected result: Device reboots successfully.

34. Open Control Panel > View by: Small icons > Mail (Microsoft Outlook).
Expected result: Mail Setup dialog opens.

35. Click Show Profiles.
Expected result: Profile list window opens.

36. Click Add, enter a new profile name, and click OK.
Expected result: New profile creation wizard starts.

37. Complete mailbox sign-in for the affected user in the profile wizard.
Expected result: Profile setup ends with successful account configuration.

38. In the Profiles window, set "Always use this profile" to the new profile and click Apply.
Expected result: New profile is selected as default.

39. Start Outlook from Start menu > Outlook.
Expected result: Outlook opens using the new profile.

40. Wait until status bar shows "All folders are up to date".
Expected result: Initial mailbox sync completes without crash.

41. If crashes persist, close Outlook by selecting File > Exit.
Expected result: Outlook closes fully.

42. In File Explorer address bar, enter `%LOCALAPPDATA%\Microsoft\Outlook` and press Enter.
Expected result: Outlook cache folder opens.

43. Rename the affected profile OST file from `<name>.ost` to `<name>.ost.old`.
Expected result: Original OST file is preserved with .old suffix.

44. Launch Outlook from Start menu > Outlook.
Expected result: A new OST file is created automatically.

45. Wait until status bar shows "All folders are up to date".
Expected result: OST rebuild and mailbox sync complete without crash.

46. Open Event Viewer from Start menu > Event Viewer.
Expected result: Event Viewer console opens.

47. Navigate to Windows Logs > Application.
Expected result: Application log list is visible.

48. In the Actions pane, click Filter Current Log.
Expected result: Filter dialog opens.

49. In Event IDs, enter `1000,1001,1026` and click OK.
Expected result: Only targeted crash-related events are displayed.

50. Review events generated after remediation start time.
Expected result: No new Outlook crash sequence is present after the fix steps.

## Verification

1. Open Outlook in normal mode and keep it running for 30 minutes.
Expected result: Outlook does not close unexpectedly and no APPCRASH popup appears.

2. Open one existing email message in the Inbox.
Expected result: Message opens immediately and Outlook stays responsive.

3. Send one test email from the affected mailbox to a known internal recipient.
Expected result: Message moves to Sent Items with no send error.

4. Open Calendar in Outlook.
Expected result: Calendar view loads with no freeze or crash.

5. Run one mailbox search from the Outlook search box.
Expected result: Search returns results and Outlook remains responsive.

6. In Event Viewer, go to Windows Logs > Application.
Expected result: Application log is visible for review.

7. Apply Filter Current Log with Event IDs `1000,1001,1026`.
Expected result: Only those event IDs are shown.

8. Sort by Date and Time descending.
Expected result: Newest application events appear at the top.

9. Check for Event ID 1000 entries where Faulting application name is `OUTLOOK.EXE` after remediation start time.
Expected result: Zero matching Event ID 1000 entries are present.

10. Check for Event ID 1026 entries where Application is `OUTLOOK.EXE` after remediation start time.
Expected result: Zero matching Event ID 1026 entries are present.

11. Send a test email to the affected user from another mailbox.
Expected result: Message arrives in Inbox within normal delivery time.

12. Ask the affected user to send a reply to the same test message.
Expected result: Reply is received by the sender mailbox.

13. Record remediation details in the incident ticket (offending add-in, repair type, profile change, OST rebuild, event log outcome).
Expected result: Ticket contains enough detail for peer audit and closure approval.

## Rollback

1. Press Ctrl+Shift+Esc to open Task Manager.
Expected result: Task Manager opens.

2. In Task Manager > Processes, select each `OUTLOOK.EXE` process and click End task.
Expected result: No Outlook process remains running.

3. Open Outlook in Safe Mode by pressing Windows+R, entering `outlook.exe /safe`, and pressing Enter.
Expected result: Outlook opens and title bar shows "Microsoft Outlook (Safe Mode)".

4. In Safe Mode, open File > Options > Add-ins > Manage: COM Add-ins > Go.
Expected result: COM Add-ins dialog opens.

5. Apply the original add-in state from the ticket baseline captured in Procedure step 10.
Expected result: Add-in checkboxes match the recorded pre-change baseline exactly.

6. Click OK in COM Add-ins, then close Outlook using File > Exit.
Expected result: Add-in configuration is saved and Outlook closes cleanly.

7. Open Control Panel > View by: Small icons > Mail (Microsoft Outlook) > Show Profiles.
Expected result: Mail Profiles window opens.

8. Select the original profile name, choose "Always use this profile", and click Apply.
Expected result: Original profile is set as default.

9. If an OST was renamed during remediation, open File Explorer and go to `%LOCALAPPDATA%\Microsoft\Outlook`.
Expected result: Outlook cache folder opens.

10. Rename `<name>.ost.old` back to `<name>.ost`.
Expected result: Original cache filename is restored.

11. Start Outlook from Start menu > Outlook.
Expected result: Outlook opens with original profile and original add-in state.

12. If Outlook still fails to open normally, relaunch with Windows+R > `outlook.exe /safe` and keep user on Safe Mode for temporary access.
Expected result: User regains basic mail access while escalation is raised.

## Notes

- Trigger pattern in this incident is deterministic: repeated Event 1000 with `KERNELBASE.dll`, exception `0xc0000005`, and identical fault offset.
- Safe mode stability strongly indicates add-in or profile initialization path involvement.
- OST rebuild can take significant time for large mailboxes; do not close Outlook during initial resync.
- Online Repair resets Office binaries and can require user reauthentication and add-in re-registration.
- If multiple users on the same Office build/channel show the same fault bucket, treat as possible product regression and open a broad incident.
- Related incidents to compare in this workspace: shared mailbox post-migration behavior and Teams/Outlook integration side effects in day2 triage summaries.
