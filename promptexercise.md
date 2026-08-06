Prompt template

You are a DWP service-desk analyst writing structured known-error
records for the knowledge base. Study the two worked examples below,
then write the known-error record for the new RCA in exactly the
same structure. Only use facts present in the RCA — mark anything
uncertain as “to confirm”. Return only the record.

Example 1
RCA: verified root-cause text
Known-error record: structured record

Example 2
RCA: verified root-cause text
Known-error record: structured record

New RCA: paste new RCA
Known-error record:

Worked example (fill-in reference)

Example 1
RCA: “AVD black screens traced to a graphics driver regression in the
overnight host-pool image update; affected ~40% of one pool.”
Known-error record:
Symptom: Users see a black screen for 30s+ after AVD login.
Cause: Graphics driver regression in host image.
Scope: One host pool, image-update dependent.
Workaround: Move affected users to the healthy pool.
Permanent fix: Roll back/patch the image, re-test before redeploy.

Example 2
RCA: “Company Portal app install failures (0x87D1041C) traced to an
outdated detection rule after an app version bump.”
Known-error record:
Symptom: App shows ‘failed’ in Company Portal, error 0x87D1041C.
Cause: Detection rule not updated for new app version.
Scope: All devices assigned the app after the version bump.
Workaround: Manually reinstall via IT; not user-fixable.
Permanent fix: Update detection rule to match new version, redeploy.

Saved triage output

Ticket: cant print from the 3rd floor since this morning, whole team affected, big client meeting at 2
Triage: Summary: Unable to print from the 3rd floor since this morning, reported as team-wide, with urgent business impact due to a 2pm client meeting. Impact: multiple users (whole team), high urgency, potential meeting disruption. Known facts: issue started this morning, location is 3rd floor, whole team affected, client meeting at 2. Missing info: exact printer name/queue, exact error message, whether printer appears offline or missing, whether jobs are stuck in queue, whether nearby printers work, exact number of users affected. Likely category: shared network printer outage or print queue/publication issue. First step: check printer status and print queue immediately (device panel plus print server) to confirm hardware outage vs queue/network issue.