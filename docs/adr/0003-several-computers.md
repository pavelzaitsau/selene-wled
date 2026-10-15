# ADR-0003: Share the strip between computers

- Status: accepted
- Date: 2026-10-15

## Context

Pavel moves the LG cable between computers, and each computer runs Selene. Until now every client
re-sent its power state every 60 s, so a computer without the monitor re-sent `{"on":false}`. With
two computers, the idle one switched WLED off once a minute while the other one streamed. The
strip went dark for up to 60 s at a time.

WLED needs no help to go dark: 2 s after the last realtime packet it shows its own state, a black
Solid segment. Switching WLED off saves the idle current of the LEDs, about 0.5 W for 104 LEDs.

## Options considered

| # | Option | Cost | Why rejected / chosen |
| --- | --- | --- | --- |
| 1 | Never send `{"on":false}` | The board draws ~0.5 W while no computer streams | Rejected: R3 asks for the strip off, and the board stays on overnight |
| 2 | One computer as the master of WLED power | A role to configure on each computer | Rejected: the master must stay on and on the network |
| 3 | Send `off` once on release, and only when no other computer streams; the computer with the monitor checks the power state | One extra `GET` per release, one check every 10 s | Chosen |

## Decision

**The computer that loses the monitor switches WLED off once, unless another computer streams. The
computer with the monitor checks every 10 s that WLED is on.**

A release is a monitor disconnect, Stop in the menu, Quit, or a start without the monitor. The
client waits 4 s after a disconnect before it reads `/json/si`. The wait gives the computer that
gains the monitor time to start its stream. When `live` is `true` and `lip` is another address,
the client leaves WLED as it is.

## Consequences

| Direction | Consequence |
| --- | --- |
| Simpler | No role and no setting per computer; every computer runs the same build |
| Harder | Power control depends on `lip` in `/json/si`, which WLED reports only while it streams |
| Slower | The strip switches off 4 s later after an unplug, still inside the 5 s of R3 |

## Risk

The release and the new owner's `{"on":true}` can still cross on the network. The new owner then
finds WLED off in its next check and switches it on, so the strip stays dark for up to 10 s.

## Expected effect

With the cable on either computer, the strip follows the picture and never goes dark while one
computer streams, as [R11](../requirements.md#r11-two-or-more-computers) sets.
