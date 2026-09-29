# Requirements

Status: draft, 2026-09-29.

These requirements bind every desktop client, on every OS. The wire format and the timings are in
[protocol.md](protocol.md). The constraints of one OS are in that client's README.

## Picture

### R1 Edge colours

- Must: The client MUST light each LED with the average colour of its zone, as
  [protocol.md](protocol.md#sampling) defines the zones.
- Verified by: [tools/test-pattern.html](../tools/test-pattern.html) full screen on the monitor.
  Each side shows its colour, and the dot runs clockwise from the bottom-left corner. Pavel
  confirms by looking.
- Out of scope: HDR tone mapping, black-border detection for letterboxed video.

### R2 Target monitor

- Must: The client MUST capture only the monitor whose name contains `LG ULTRAFINE`.
- Verified by: With a second display connected, the strip follows the LG only.
- Out of scope: More than one strip, more than one monitor.

## Power

### R3 Follow the monitor

- Must: The client MUST switch WLED on when the monitor connects and off when it disconnects.
- Verified by: Unplug and replug the monitor. The strip goes dark within 5 s and comes back within
  5 s.
- Out of scope: Switching WLED from any other trigger, such as a schedule.

### R4 Monitor asleep

- Must: The client MUST stop streaming while the monitor sleeps.
- Verified by: Put the monitor to sleep. `live` in `/json/info` turns `false`, and the strip goes
  dark.
- Out of scope: Sleep of the computer; see the open questions.

### R5 Still picture

- Must: The client MUST keep WLED in realtime mode while the picture does not change.
- Verified by: Leave a still picture for 60 s. `live` stays `true` and the strip keeps its colours.
- Out of scope: None.

### R6 Start without the user

- Must: The client MUST start at login and restart after a crash, with no user action.
- Verified by: Reboot the computer and log in. The strip lights within 30 s.
- Out of scope: Streaming before login.

## Resources

### R7 CPU budget

- Must: The client MUST add at most 5% of one core over the baseline without it.
- Verified by: On macOS, sum `selene`, `WindowServer`, `ControlCenter` and `opendirectoryd` in
  `top -l 3 -s 3 -o cpu -stats command,cpu -n 12`. Measure with a still picture, with the client
  running and with it stopped.
- Out of scope: GPU load; video decoding by the application on screen.

### R8 One capture session

- Must: The client MUST keep one capture session open while the monitor is connected.
- Verified by: The client log shows one capture start per monitor connection.
- Out of scope: None. A session per frame is what made HyperHDR cost 65% of a core, see
  [ADR-0001](adr/0001-replace-hyperhdr.md).

## Operation

### R9 Log silent failures

- Must: The client MUST log a missing OS permission, a failed network send and an unreachable
  WLED.
- Verified by: Revoke each permission in turn. The log names the missing permission.
- Out of scope: Notifications to the user.

### R10 No secrets

- Must: The client MUST NOT need a secret to stream or to switch WLED.
- Verified by: The client configuration holds no password, PIN or token.
- Out of scope: Changing board settings, which needs the settings PIN.

## Open questions

| # | Question | Why it blocks | Owner | Needed by |
| --- | --- | --- | --- | --- |
| 1 | Is 5% of one core the right budget in R7? | Sets the capture rate and resolution | Pavel | Before work on the first client starts |
| 2 | Do gamma 1.5 and smoothing 0.30 match the picture? | They are a first guess, see [protocol.md](protocol.md#sampling) | Pavel | Before the switch from HyperHDR |
| 3 | What does the strip do on the lock screen and while the computer sleeps? | R3 and R4 cover the monitor only | Pavel | Before work on the first client starts |
| 4 | Is black-border detection worth adding for letterboxed video? | R1 excludes it today | Pavel | After the switch from HyperHDR |
| 5 | Does the Windows display name contain `LG ULTRAFINE`, as R2 expects? | Pavel checked R2 on macOS only | Pavel | Before work on the Windows client starts |
| 6 | What breaks when USB is connected while the 5 V supply is on? | [hardware.md](hardware.md#wiring) states the rule without its consequence | Pavel | Before the next reflash |
