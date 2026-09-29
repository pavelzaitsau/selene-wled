# Selene

Selene lights an LED strip behind a desktop monitor with the colours at the edges of the screen.

A desktop client captures the screen and streams one colour per LED over UDP. An ESP32 running
[WLED](https://kno.wled.ge) drives the strip. When the monitor is off or unplugged, the strip goes
dark.

The project is at the requirements stage. HyperHDR drives the strip today, and
[docs/migration.md](docs/migration.md) describes the switch.

## Components

| Path | Component | Status |
| --- | --- | --- |
| `desktop/macos/` | macOS client | Requirements; a prototype lives on branch `feat/macos-client` |
| `desktop/windows/` | Windows client | Requirements; no code |
| `firmware/esp32/` | WLED firmware and board configuration | Running on the board |

## Repository layout

| Path | Contents |
| --- | --- |
| `docs/` | Facts shared by every component: requirements, hardware, protocol, decisions |
| `tools/` | The test pattern, the documentation gate, the git hooks, the skill refresh |
| `legacy/` | The HyperHDR watcher that runs today; deleted after the switch |
| `.claude/skills/` | The writing rules for documentation, commits and branch names |

## Documentation

- [docs/requirements.md](docs/requirements.md): the requirements for every client. Start here.
- [docs/protocol.md](docs/protocol.md): what a client sends to WLED and when.
- [docs/hardware.md](docs/hardware.md): the strip, the wiring and the LED order.
- [firmware/esp32/README.md](firmware/esp32/README.md): the settings the board holds.
- [docs/adr/](docs/adr/): decisions and the alternatives they rejected.
- [AGENTS.md](AGENTS.md): how to work on this repository.

## Checks

```bash
tools/install-hooks.sh   # once per clone: commit message and branch name checks
tools/lint-docs.sh       # markdownlint and Vale over every Markdown file
```

GitHub Actions runs `tools/lint-docs.sh` on every push and pull request.

## Licence

MIT, see [LICENSE](LICENSE). The vendored skills under `.claude/skills/` are MIT-0.
