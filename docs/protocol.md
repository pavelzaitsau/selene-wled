# Client protocol

A desktop client samples the screen edges, streams the colours to WLED over UDP, and switches WLED
on and off with the monitor. This page defines the values and the wire format that every client
uses. [requirements.md](requirements.md) sets what the client achieves with them.

The board address and ports are in [the firmware README](../firmware/esp32/README.md#board).

## Sampling

Each LED averages one zone at the edge of the picture, in the LED order from
[hardware.md](hardware.md#led-order).

| Parameter | Value |
| --- | --- |
| Zone depth, top and bottom | 8% of the picture height |
| Zone depth, left and right | 5% of the picture width |
| Smoothing | Exponential moving average, time constant 0.0935 s; provisional |
| Output gamma | 1.5, applied by the client; provisional |
| Frame rate | At most 15 fps |

The smoothing factor for a frame is `1 - exp(-dt / 0.0935 s)`, where `dt` is the time since the
previous frame. At 30 fps that is 0.30 per frame, and at 15 fps 0.51. A factor tied to time keeps
the look of the smoothing when a client changes its frame rate.

At 15 fps the macOS client costs half the CPU of 30 fps, and the strip still follows video.
Smoothing and gamma are a first guess and wait for Pavel's judgement on the strip, see
[requirements.md](requirements.md#open-questions). The board applies no gamma to realtime data,
so a client that skips its own gamma sends a washed-out picture.

## Streaming

The client sends WLED realtime UDP protocol 2 (DRGB) to the board's realtime port.

| Byte | Content |
| --- | --- |
| 0 | `2`, the protocol |
| 1 | Timeout in seconds, `2` |
| 2 onwards | Red, green, blue for each LED, 104 x 3 bytes |

One packet is 314 bytes. WLED accepts up to 490 LEDs in one DRGB packet.

Byte 1 sets how long WLED stays in realtime mode after this packet. When no new frame arrives, the
client resends the last colours at least every 1 s. Without the resend, the strip drops to WLED's
own state 2 s after the picture stops changing.

## Power

The client switches WLED with `POST /json/state` on the board:

| Monitor | Client action |
| --- | --- |
| Connected and awake | Send `{"on":true,"bri":255}`, then stream |
| Asleep | Stop streaming; after the timeout WLED shows its own state, a black Solid segment |
| Disconnected | Stop capture, release WLED |

A client releases WLED on a monitor disconnect, on Stop in its menu, on Quit, and when it starts
without the monitor. To release, the client waits 4 s and reads `/json/si`. When `live` is
`true` and `lip` is another address, another computer streams, and the client leaves WLED alone.
Otherwise it sends `{"on":false}`. [ADR-0003](adr/0003-several-computers.md) records the choice.

A monitor that moves to another computer can take longer than 4 s to show a picture there. The old
computer then finds no stream and switches WLED off, and the new one switches it on when it sees
the monitor. The strip shows no difference: while no computer has a picture, nothing streams, and
WLED goes dark 2 s after the last packet either way.

A client with the monitor re-sends `{"on":true,"bri":255}` every 60 s. It also reads `/json/si`
every 10 s and switches WLED on when `on` is `false`. The board boots switched off, so the re-send
recovers from a board restart. The check also undoes a manual switch-off in the WLED app within
10 s; Stop in the client menu is the way to darken the strip while the monitor is connected. A
client without the monitor sends nothing after its release.

The client finds the monitor by a name that contains `LG ULTRAFINE`. Display IDs change between
ports and reboots, and the name does not.

`/json/state` and realtime UDP need no credentials.
