# RCA: RDP Connection Failure and User Lockout - FINBRIDGE\\bwalker (2024-03-15)

## Incident Summary

- Incident type: Remote Desktop authentication failure leading to account lockout
- User: FINBRIDGE\bwalker
- Observation window: 14:01:02 to 14:22:09 (within a 30-minute review period)
- Primary source IP / caller: 10.10.5.44
- Logs involved: System (TermDD, RemoteDesktopServices-RdpCoreTS) and Security
- Business impact: User was unable to access the target system over RDP until lockout condition was cleared

## Event ID Explanation

1. Event ID 56 (System, Source: TermDD, Level: Error)
- What it records: RDP transport/security-layer protocol stream error causing server-side disconnect of the client session.
- In this incident:
  - 14:01:02: Terminal Server security layer detected protocol stream error and disconnected client 10.10.5.44.
- Why this matters: Indicates RDP session setup failed at security/protocol stage; often observed alongside failed authentication or malformed session negotiation.

2. Event ID 140 (System, Source: RemoteDesktopServices-RdpCoreTS, Level: Warning)
- What it records: RDP connection failure due to invalid credentials (username/password not correct).
- In this incident:
  - 14:01:02: Connection from 10.10.5.44 failed because username or password was not correct.
- Why this matters: Provides explicit RDP subsystem confirmation of credential failure.

3. Event ID 4625 (Security, Audit Failure)
- What it records: Failed logon attempt including account, reason, source IP, and logon type.
- In this incident:
  - 14:01:04: Failed remote interactive logon (type 10) for FINBRIDGE\bwalker from 10.10.5.44; unknown username or bad password.
  - 14:03:18: Second failed remote interactive logon (type 10) for same account/source/reason.
  - 14:05:33: Third failed remote interactive logon (type 10) for same account/source/reason.
- Why this matters: Definitive evidence of repeated bad-credential attempts over RDP.

4. Event ID 4740 (Security, Audit Failure)
- What it records: Account lockout event triggered by lockout policy, including caller computer/source.
- In this incident:
  - 14:05:34: Account FINBRIDGE\bwalker locked out; caller 10.10.5.44.
- Why this matters: Confirms lockout policy threshold was reached and attributes trigger source.

5. Event ID 131 (System, Source: RemoteDesktopServices-RdpCoreTS, Level: Information)
- What it records: Server accepted a new inbound TCP connection for RDP from a client IP/port.
- In this incident:
  - 14:22:07: Server accepted new TCP connection from 10.10.5.44:52341.
- Why this matters: Shows transport connectivity to RDP endpoint was working later; issue shifted from lockout/credentials to successful reconnect flow.

6. Event ID 4624 (Security, Audit Success)
- What it records: Successful logon event with account, logon type, and source details.
- In this incident:
  - 14:22:09: Successful remote interactive logon (type 10) for FINBRIDGE\bwalker from 10.10.5.44.
- Why this matters: Confirms recovery and restored access once valid authentication succeeded.

## Reconstructed Sequence (Plain English)

1. At 14:01:02, an RDP session attempt from 10.10.5.44 hit a protocol/security-layer disconnect and a credential error warning at the same time.
2. Immediately after, Security logs recorded failed RDP logon attempts for FINBRIDGE\bwalker due to bad username/password (14:01:04).
3. Additional failed attempts happened at 14:03:18 and 14:05:33 from the same source IP and same account using logon type 10 (RDP RemoteInteractive).
4. One second later, at 14:05:34, the account was locked out by policy (4740), with caller 10.10.5.44.
5. About 16 minutes later, the server accepted a new TCP RDP connection from the same IP (14:22:07), followed by a successful remote interactive logon (4624) at 14:22:09.

## Most Likely Cause of Lockout with Evidence

Most likely cause:
- Repeated incorrect RDP credentials entered (or replayed by an RDP client session) from 10.10.5.44 for FINBRIDGE\bwalker, triggering account lockout threshold.

Evidence from events:

1. Credential-specific RDP failure signal:
- Event 140 explicitly states username/password not correct for client 10.10.5.44.

2. Repeated failed RDP authentications:
- Three 4625 events for the same account, source IP, failure reason, and logon type 10 (RemoteInteractive).

3. Direct lockout correlation:
- Event 4740 occurs immediately after third 4625 and identifies 10.10.5.44 as caller.

4. Later successful RDP login from same source:
- Event 4624 success at 14:22:09 from 10.10.5.44 indicates account and path were valid once authentication succeeded, reinforcing bad/stale credentials as primary trigger earlier.

Interpretation of TermDD 56 in this incident:
- Event 56 is treated as a concurrent symptom of failed RDP security negotiation/disconnect, not the root lockout cause. The lockout mechanism is evidenced directly by 4625 + 4740.

## 5-Whys Analysis

Problem statement: FINBRIDGE\bwalker was locked out during RDP access attempts.

1. Why was the user locked out?
- Because account lockout policy triggered after repeated failed authentication attempts.

2. Why were authentication attempts failing?
- RDP logons from 10.10.5.44 used credentials rejected as unknown username or bad password.

3. Why were bad credentials retried multiple times?
- Most likely stale/mistyped password or saved RDP credential mismatch repeatedly submitted during reconnect attempts.

4. Why did retries progress to lockout rather than being corrected early?
- No effective intervention occurred before the policy threshold was reached (for example immediate credential verification after first/second failure).

5. Why is this recurring risk present operationally?
- Credential hygiene and alerting around repeated 4625 type-10 events from single source/account were insufficient to prevent threshold breach.

## Root Cause Statement

Primary root cause:
- Consecutive failed RDP credential submissions for FINBRIDGE\bwalker from 10.10.5.44 caused account lockout per domain lockout policy.

Contributing factors:
- Potential cached/stale credential in RDP client profile.
- Lack of early alert/escalation on repeated failed remote interactive attempts.

## Impact Assessment

- User impact: Temporary inability to access system via RDP.
- Business impact: Productivity interruption during lockout window.
- Scope: Single user account in provided evidence; source concentrated to one client IP.

## Corrective and Preventive Actions (CAPA)

Immediate corrective actions:

1. Clear cached credentials for target host in client credential store and re-enter verified password.
2. Confirm account lockout status and perform unlock per IAM/helpdesk process.
3. Validate no scheduled tasks/services on 10.10.5.44 are using old credentials for this account.
4. Re-test RDP with verified credentials and confirm successful 4624 (type 10) outcome.

Preventive actions:

1. Add SIEM alert for burst of Security 4625 with logon type 10 by same account/source within short interval.
2. Enable analyst playbook to intervene before lockout threshold (user contact + credential reset guidance).
3. Review and tune lockout policy/user guidance balance to reduce avoidable lockouts while maintaining security posture.
4. Standardize RDP client profile hygiene checks after password changes.
5. Monitor for paired System 140 + Security 4625 patterns as early warning of remote authentication issues.

## Confidence and Gaps

- Confidence level: High for lockout mechanism and source attribution.
- Confidence level: Medium-high for specific upstream reason (stale/mistyped/cached credentials), as exact user action path is not directly logged.
- Data gaps:
  - No explicit account unlock event provided in this dataset.
  - No client-side RDP credential manager/task telemetry included.
  - No domain policy threshold configuration values included.

## Evidence Appendix

- 2024-03-15 14:01:02 - System TermDD 56 - protocol stream error; client disconnected - IP 10.10.5.44.
- 2024-03-15 14:01:02 - System RdpCoreTS 140 - connection failed; username/password incorrect - IP 10.10.5.44.
- 2024-03-15 14:01:04 - Security 4625 - FINBRIDGE\bwalker failed logon - bad password/unknown username - type 10 - source 10.10.5.44.
- 2024-03-15 14:03:18 - Security 4625 - FINBRIDGE\bwalker failed logon - bad password/unknown username - type 10 - source 10.10.5.44.
- 2024-03-15 14:05:33 - Security 4625 - FINBRIDGE\bwalker failed logon - bad password/unknown username - type 10 - source 10.10.5.44.
- 2024-03-15 14:05:34 - Security 4740 - FINBRIDGE\bwalker account locked out - caller 10.10.5.44.
- 2024-03-15 14:22:07 - System RdpCoreTS 131 - accepted new TCP connection from 10.10.5.44:52341.
- 2024-03-15 14:22:09 - Security 4624 - FINBRIDGE\bwalker successful logon - type 10 - source 10.10.5.44.