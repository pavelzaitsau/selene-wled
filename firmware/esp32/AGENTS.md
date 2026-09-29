# Agent instructions: ESP32

The repository-wide rules are in [the root AGENTS.md](../../AGENTS.md). This file adds the rules
for `firmware/esp32/`.

## The board is shared state

A setting change on the board takes effect for every client at once. Ask Pavel before any write
to `/json/state` or `/json/cfg`, a reflash or a Wi-Fi change. Reading `/json/info` and
`/json/state` needs no approval.

A change to a board setting lands in [README.md](README.md) in the same commit. A value found on
the board that differs from the README goes into its known deviations table.

## Secrets

Settings writes need the PIN, and OTA needs the OTA password. The Keychain accounts are in
[README.md](README.md#security). Pass a secret to `curl` through a variable or stdin, never as a
literal on the command line.

A WLED configuration export (`cfg.json`, presets) can hold the Wi-Fi password and the PIN. Remove
both before a file like that enters the repository.
