# Triage Summary - T-1005

## Summary (one line)
Teams audio is not working on three machines in the same meeting room, suggesting a shared room audio path, device selection, or local endpoint configuration issue (to-verify).

## Impact (who/how many/business urgency)
- Who: Users joining meetings from one meeting room.
- How many: Three affected machines in the same room.
- Business urgency: High (to-verify) due to immediate meeting disruption for multiple participants.

## Known facts
- Ticket ID: T-1005.
- Application: Microsoft Teams.
- Symptom: Audio is dead.
- Scope clue: Three machines in the same meeting room are affected.

## Missing information to gather
- Whether both microphone input and speaker output fail, or only one direction.
- Whether issue is in Teams only or also in Windows sound test/other apps.
- Selected Teams audio devices and whether they reset to unexpected defaults.
- Whether room peripherals (USB audio device/dock/speakerphone) are shared and currently connected/recognized.
- Whether recent Windows/driver/Teams updates were applied on affected machines (to-verify).
- Whether users on non-room devices in same meeting have normal audio.
- Exact meeting time and any recurring pattern.

## Likely catagory
Messaging and Collaboration - Teams audio/peripheral endpoint issue (to-verify).

## First diagnostic step
On one affected machine, validate Windows and Teams audio device selection and run a Teams test call while checking if the expected room peripheral is detected and active; this quickly confirms whether the failure is app-level selection or shared room hardware path (to-verify).
