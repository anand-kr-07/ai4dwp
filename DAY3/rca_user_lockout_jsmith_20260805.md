# RCA: User Account Lockout - jsmith (2026-08-05)

## Incident Summary

- Incident type: User account lockout
- User: jsmith
- Observation window: 08:02:14 to 08:23:44 (about 22 minutes of logged activity in a 30-minute review window)
- Affected endpoint: DESKTOP-FB001
- Domain action account observed: FINBRIDGE\helpdesk-admin

## Event ID Explanation

1. Event ID 4625 (Audit Failure)
- Meaning: Failed logon attempt.
- What it records: The account used, failure reason, source workstation, and logon type.
- In this incident:
  - 08:02:14 failed interactive sign-in (type 2) for jsmith due to bad password/unknown username.
  - 08:04:22 second failed interactive sign-in (type 2) for the same reason.
  - 08:07:45 failed unlock attempt (type 7) because account was already locked.

2. Event ID 4740 (Account Lockout)
- Meaning: A user account was locked out by account lockout policy.
- What it records: Which account was locked and the caller computer that triggered the lockout.
- In this incident:
  - 08:06:01 jsmith account locked out, caller computer DESKTOP-FB001.

3. Event ID 4722 (Audit Success)
- Meaning: A user account was enabled/unlocked by an administrator action.
- What it records: Target account and actor account performing the action.
- In this incident:
  - 08:22:10 jsmith account enabled by FINBRIDGE\helpdesk-admin.

4. Event ID 4624 (Audit Success)
- Meaning: Successful logon.
- What it records: Successful authentication details including logon type.
- In this incident:
  - 08:23:44 successful interactive sign-in (type 2) for jsmith.

## Reconstructed Sequence (Plain English)

1. At 08:02, jsmith tried to sign in at the console of DESKTOP-FB001 but entered invalid credentials.
2. At 08:04, jsmith tried again and failed for the same reason.
3. At 08:06, the domain/account lockout threshold was reached and the jsmith account was locked by policy.
4. At 08:07, jsmith attempted to unlock/sign in again, but this failed because the account was now locked.
5. At 08:22, helpdesk administrator FINBRIDGE\helpdesk-admin re-enabled/unlocked the account.
6. At 08:23, jsmith successfully signed in interactively.

## Most Likely Cause of Lockout

Most likely cause: Repeated incorrect password entry at the local interactive sign-in screen on DESKTOP-FB001, leading to automatic lockout by policy threshold.

Evidence from events:

1. Two explicit pre-lockout bad-password failures (4625 at 08:02:14 and 08:04:22) from the same source machine and same user.
2. Lockout event (4740 at 08:06:01) identifies DESKTOP-FB001 as the caller computer, matching the failed attempts source.
3. Post-lockout failure reason changes to account locked out (4625 at 08:07:45, logon type 7), confirming lockout state rather than ongoing bad password parsing.
4. Administrative unlock/enable action (4722 at 08:22:10) followed by successful sign-in (4624 at 08:23:44) indicates credentials were usable once lockout condition was removed.

## 5-Whys Analysis

Problem statement: jsmith was locked out and unable to access the workstation.

1. Why was jsmith locked out?
- Because the account exceeded the allowed failed sign-in attempts and triggered lockout policy.

2. Why were there repeated failed sign-ins?
- The user entered credentials that Active Directory/LSA rejected as unknown username or bad password during interactive logon attempts.

3. Why was the wrong credential entered more than once?
- Most probable operational reason is stale or mistyped password at the endpoint logon screen (manual input error or recently changed password not recalled correctly).

4. Why did this lead to a service-impacting lockout instead of quick self-recovery?
- The configured lockout threshold and duration require administrative intervention once triggered.

5. Why is intervention-heavy recovery still needed for this scenario?
- Preventive controls (user guidance, self-service unlock flow, or proactive lockout alerts before threshold breach) were insufficient or absent in the observed process.

## Root Cause Statement

Primary root cause:
- Consecutive invalid interactive password attempts for jsmith on DESKTOP-FB001 caused account lockout per configured policy.

Contributing factors:
- No effective early warning before threshold breach.
- Dependence on helpdesk unlock to restore access.

## Impact Assessment

- User impact: Temporary inability to log on/unlock workstation.
- Business impact: Short productivity interruption for the affected user.
- Scope: Single identified user and single endpoint in provided data.

## Corrective and Preventive Actions (CAPA)

Immediate corrective actions:

1. Helpdesk performed account enable/unlock (completed at 08:22:10).
2. User verified successful login (completed at 08:23:44).

Preventive actions:

1. User education reminder on password change handling and careful input at lock screen.
2. Enable lockout pre-threshold alerting in SIEM for repeated 4625 events from same source/user within short window.
3. Review lockout policy balance (security vs usability) with IAM/SOC stakeholders.
4. Validate no background process/service on DESKTOP-FB001 is repeatedly attempting old credentials (scheduled tasks, mapped drives, cached apps).
5. Consider self-service password reset/unlock experience improvements where policy allows.

## Confidence and Gaps

- Confidence level: High for immediate cause (failed password attempts leading to lockout).
- Remaining uncertainty: Underlying human/process reason for wrong credentials (mistype vs recent password change confusion) is not directly proven by these events alone.
- Additional data recommended: Password change history, user interview notes, and endpoint credential manager/task audit.

## Evidence Appendix

- 08:02:14 - Security 4625 - jsmith - bad password/unknown username - source DESKTOP-FB001 - logon type 2.
- 08:04:22 - Security 4625 - jsmith - bad password/unknown username - source DESKTOP-FB001 - logon type 2.
- 08:06:01 - Security 4740 - jsmith - account locked out - caller DESKTOP-FB001.
- 08:07:45 - Security 4625 - jsmith - account locked out - source DESKTOP-FB001 - logon type 7.
- 08:22:10 - Security 4722 - jsmith - account enabled by FINBRIDGE\helpdesk-admin.
- 08:23:44 - Security 4624 - jsmith - successful interactive logon - logon type 2.
