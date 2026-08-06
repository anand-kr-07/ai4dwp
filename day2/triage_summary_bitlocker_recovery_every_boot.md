# Triage Summary - T-1001

## Summary (one line)
New Windows 11 laptop is prompting for a BitLocker recovery key on every boot, indicating likely repeated TPM/boot integrity validation failure (to-verify).

## Impact (who/how many/business urgency)
- Who: Single end user on a new Windows 11 laptop (to-verify).
- How many: Currently one reported device/ticket.
- Business urgency: Medium-High (to-verify) because repeated recovery prompts can block user access and cause ongoing service disruption.

## Known facts
- Ticket ID: T-1001.
- Device: New Windows 11 laptop.
- Symptom: BitLocker recovery key prompt appears every boot.
- Frequency: Every boot, based on user statement.

## Missing information to gather
- Whether the user can successfully enter the recovery key and reach desktop each time.
- Whether any hardware/firmware changes occurred after provisioning (dock, BIOS/UEFI setting change, TPM state change) (to-verify).
- Whether Secure Boot or firmware updates were recently applied (to-verify).
- Whether this affects only this device or additional new laptops from same build batch (to-verify).
- Whether issue started immediately after first boot or after a specific change.
- Device join/provisioning context (for example, Autopilot/domain management) (to-verify).
- Whether suspend/resume behavior differs from full reboot.

## Likely catagory
Endpoint Security - BitLocker/Device Encryption (to-verify).

## First diagnostic step
Validate and compare BitLocker protector and TPM status from an elevated session after successful login, then perform one controlled reboot to confirm trigger pattern while capturing exact pre-boot sequence; this establishes whether protectors/TPM state are stable or changing between boots (to-verify).
