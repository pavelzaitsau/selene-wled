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
| Smoothing | Exponential moving average, factor 0.30 per frame; provisional |
| Output gamma | 1.5, applied by the client; provisional |
| Frame rate | At most 30 fps |

Smoothing and gamma are a first guess and wait for a comparison with HyperHDR, see
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
| Disconnected | Stop capture, send `{"on":false}` |

The client re-sends the current power state every 60 s. The board boots switched off, so the
re-send also recovers from a board restart.

The client finds the monitor by a name that contains `LG ULTRAFINE`. Display IDs change between
ports and reboots, and the name does not.

`/json/state` and realtime UDP need no credentials.
