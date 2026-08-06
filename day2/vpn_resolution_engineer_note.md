Root cause: Win11 upgrade removed legacy VPN client and Intune did not re-deploy new client due to detection-rule gap.

Action taken (exact):
1. Manually removed stale VPN registry entries under HKLM\SOFTWARE<vendor>.
2. Force-triggered Intune sync.
3. New VPN client deployed.
4. Split-tunnel config applied.

Verification: Connectivity confirmed to all internal subnets.

Data impact: No data loss.

Preventive action needed: Correct/close the Intune detection-rule gap so Win11 upgrade scenarios trigger automatic re-deployment of the new VPN client.
