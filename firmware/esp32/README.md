# ESP32 firmware and configuration

The ESP32 runs stock WLED. Its settings live on the board, and nothing in this repository writes
them. This page lists the values the board holds. The parts and the wiring are in
[docs/hardware.md](../../docs/hardware.md).

## Board

| Setting | Value |
| --- | --- |
| Firmware | WLED 16.0.1, `WLED_16.0.1_ESP32.bin`; `ver` in `/json/info` confirms it |
| Address | `192.168.1.35`, reserved in the router's DHCP |
| mDNS | `wled-monitor.local`; does not always resolve, so clients use the address |
| Name | Monitor Ambilight |
| Wi-Fi | The home network, set over Improv or the `WLED-AP` access point |

## LEDs

| Setting | Value |
| --- | --- |
| Type | WS281x |
| GPIO | 18 |
| Count | 104 |
| Colour order | GRB |
| Current limit (ABL) | 2500 mA, below the 3 A of the supply |
| Power-on state | Off (`def.on=false`) |
| Segment | Effect Solid, colour black |

The power-on state keeps the strip dark until a client switches it on. The black Solid segment is
what the strip shows when a client stops streaming.

## Realtime

| Setting | Value |
| --- | --- |
| UDP realtime | On, port 21324 |
| Timeout in the UI | 2.5 s |
| Gamma correction for realtime data | Off (`no-gc`) |

A DRGB packet carries its own timeout in byte 1, and that value overrides the UI timeout for the
packet. The 2.5 s setting therefore does not apply to DRGB clients. Clients apply their own gamma,
see [docs/protocol.md](../../docs/protocol.md#sampling).

## Security

| Setting | Value | Keychain account |
| --- | --- | --- |
| Settings PIN | Set; `/json/cfg` writes return 401 without it | `wled-pin` |
| OTA lock | On; firmware upload needs the password | `wled-ota` |
| Wi-Fi settings lock | On, same password | `wled-ota` |
| ArduinoOTA | Off | - |
| Same-subnet OTA only | On | - |
| WLED-AP password | Set; the AP opens only when Wi-Fi fails at boot | `wled-ap` |

The Keychain service is `ambilight`.

`/json/state` and realtime UDP stay open to the LAN by WLED's design. Anyone on the network can
switch the strip on or off.

To reflash or change Wi-Fi: open Config, then Security, enter the PIN and the OTA password, and
clear the OTA lock. Set the lock again afterwards.

## Flashing from scratch

Use [`install.wled.me`](https://install.wled.me) from Chrome, with WLED 16.0.1 for ESP32. Switch the
5 V supply off before connecting USB, see [docs/hardware.md](../../docs/hardware.md#wiring).

Then set Wi-Fi over serial with the Improv protocol, or through the `WLED-AP` access point. After
that, set the LEDs, the power-on state, the segment and the security settings from the tables
above.

## Known deviations

| Date | Setting | Expected | Found on the board |
| --- | --- | --- | --- |
| 2026-09-29 | Segment colour | Black | `[255,160,0]`, orange; the strip glows orange when streaming stops |
