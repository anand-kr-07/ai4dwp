# RCA: Outlook Application Crash (Event ID 1000/1001/1026) - 2024-03-15

## Incident Summary

- Incident type: Repeated Outlook application crash
- Application: OUTLOOK.EXE (Microsoft Office 16)
- Observation window: 09:14:22 to 09:18:05
- Host context: Windows 11 build family (KERNELBASE.dll version 10.0.22621.3155)
- Business impact: User mail client instability and inability to reliably use Outlook

## Event ID Explanation

1. Event ID 1000 (Source: Application Error, Level: Error)
- What it records: A process crash at the OS application layer.
- Key fields captured: faulting application, faulting module, exception code, fault offset, process ID, and paths.
- In this incident:
  - OUTLOOK.EXE crashed at 09:14:22.
  - OUTLOOK.EXE crashed again at 09:17:45.
  - Both crashes show KERNELBASE.dll as faulting module with exception code 0xc0000005 and same fault offset 0x000000000003a4b2.
- Why this matters: Repeated identical crash signature strongly suggests deterministic failure path (same code path, same trigger).

2. Event ID 1001 (Source: Windows Error Reporting, Level: Information)
- What it records: Windows Error Reporting (WER) crash classification and telemetry metadata.
- Key fields captured: fault bucket ID, event name, response, cab ID.
- In this incident:
  - Fault bucket: 1847362910, event name APPCRASH, cab ID 0.
- Why this matters: Confirms OS-level crash triage captured a specific crash signature bucket for grouping and correlation.

3. Event ID 1026 (Source: .NET Runtime, Level: Error)
- What it records: .NET runtime termination due to unhandled managed exception.
- Key fields captured: application name, .NET framework version, managed exception details.
- In this incident:
  - Process terminated due to unhandled System.AccessViolationException.
- Why this matters: Indicates memory access violation at runtime, consistent with 0xc0000005 access violation and suggests either unstable add-in/component interaction or corrupted runtime state.

## Reconstructed Sequence (Plain English)

1. Outlook started at 09:13:44.
2. About 38 seconds later, Outlook crashed (09:14:22) with access violation 0xc0000005 in KERNELBASE.dll.
3. User or auto-restart behavior launched/used Outlook again; within a few minutes, the same crash recurred (09:17:45) with the identical module and fault offset.
4. Windows Error Reporting logged APPCRASH telemetry (09:18:01), assigning the crash to a known fault bucket.
5. .NET Runtime then logged an unhandled System.AccessViolationException (09:18:05), confirming the process ended due to a fatal memory access violation path.

## Most Likely Cause with Evidence

Most likely cause:
- A repeatable memory access violation in Outlook runtime path, most likely triggered by a problematic Outlook add-in/profile/data interaction after startup (rather than a random one-off OS fault).

Evidence from events:

1. Repetition with identical signature:
- Event 1000 appears twice with same app version, same module (KERNELBASE.dll), same exception code (0xc0000005), same fault offset.
- This pattern indicates stable/reproducible trigger instead of transient noise.

2. Managed runtime corroboration:
- Event 1026 reports unhandled System.AccessViolationException, aligning with 0xc0000005 in Event 1000.

3. Timing behavior:
- First crash occurs shortly after startup (09:13:44 start, 09:14:22 crash), consistent with startup-time initialization activities such as add-ins, profile loads, mailbox sync initialization, or corrupted local data read.

4. WER classification:
- Event 1001 APPCRASH with a fault bucket indicates crash triage coherence, useful for matching known product regressions/signatures.

## 5-Whys Analysis

Problem statement: Outlook repeatedly crashes and becomes unusable for the user.

1. Why did Outlook become unusable?
- Because OUTLOOK.EXE terminated unexpectedly during normal use/startup.

2. Why did OUTLOOK.EXE terminate unexpectedly?
- Because a fatal access violation occurred (exception code 0xc0000005; .NET AccessViolationException unhandled).

3. Why did an access violation occur repeatedly?
- Because Outlook hit the same failing execution path twice (same faulting module and identical offset), indicating a persistent trigger.

4. Why is the trigger persistent across restarts?
- The trigger is likely tied to startup/runtime state that reloads each launch, such as an add-in, mailbox/profile object, or local cache/data artifact.

5. Why was the issue not self-healed after restart?
- There was no immediate containment step (safe mode, add-in isolation, profile/cache repair) before relaunch, so Outlook retriggered the same fault path.

## Root Cause Statement

Primary root cause:
- Reproducible access violation in Outlook runtime path during initialization/use, resulting in repeated APPCRASH events.

Most probable technical trigger class:
- Faulty Outlook add-in or corrupted Outlook profile/cache object causing deterministic crash path mapped to KERNELBASE.dll + 0xc0000005.

Contributing factors:
- Immediate relaunch without isolation/testing allowed recurrence.
- No evidence yet of prior mitigation (safe mode/add-in disable/profile repair) in provided logs.

## Impact Assessment

- User impact: Intermittent to continuous inability to use Outlook for email/calendar tasks.
- Service impact: Endpoint-local client failure; backend service outage not evidenced in provided data.
- Scope: At least one user/session on this endpoint.

## Corrective and Preventive Actions (CAPA)

Immediate corrective actions (recommended):

1. Launch Outlook in safe mode to bypass COM add-ins and verify crash suppression.
2. Disable non-Microsoft Outlook add-ins and re-enable one by one to isolate offender.
3. Run Office Quick Repair, then Online Repair if issue persists.
4. Create a new Outlook profile and test with same mailbox.
5. Rebuild OST (after ensuring sync integrity) if cache corruption suspected.
6. Correlate WER fault bucket 1847362910 with known Microsoft advisories and Office channel build issues.

Preventive actions:

1. Add proactive monitoring for repeated Event 1000 signatures per process/module/offset.
2. Standardize add-in governance (approval, version pinning, controlled rollout).
3. Keep Office build cadence aligned with tested enterprise update rings.
4. Create troubleshooting runbook for Outlook APPCRASH with decision tree (safe mode, add-ins, profile, repair).
5. Capture and retain crash dumps for recurring signatures to accelerate engineering escalation.

## Confidence and Gaps

- Confidence level: Medium-high for immediate crash mechanism (access violation).
- Confidence level: Medium for exact underlying component (add-in/profile/cache) because provided logs do not include dump-stack or add-in list.
- Data gaps:
  - No crash dump stack trace.
  - No add-in inventory state at crash time.
  - No Office repair/profile test outcomes.

## Evidence Appendix

- 2024-03-15 09:14:22 - Application Error 1000 - OUTLOOK.EXE crash - KERNELBASE.dll - 0xc0000005 - offset 0x000000000003a4b2 - PID 0x1f4c.
- 2024-03-15 09:17:45 - Application Error 1000 - OUTLOOK.EXE crash repeated - same module/exception/offset.
- 2024-03-15 09:18:01 - Windows Error Reporting 1001 - APPCRASH - fault bucket 1847362910.
- 2024-03-15 09:18:05 - .NET Runtime 1026 - unhandled System.AccessViolationException - process terminated.
