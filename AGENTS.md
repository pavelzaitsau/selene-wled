# Agent instructions

This repository drives a real LED strip behind a real monitor. A clean build proves that the code
compiles, not that the wall lights up. The rules below cover that gap.

A component directory with its own `AGENTS.md` adds rules for that directory. Read it before
working there.

## The strip is real

Confirm light, not logs. Two checks show what the strip is doing:

- `/json/info` on the board returns `live: true`, and `lip` is the streaming host. The address is
  in [the firmware README](firmware/esp32/README.md#board).
- Pavel looks at the monitor. Ask before reporting that colours match.

A strip that glows one flat colour shows WLED's own state, not the stream.

## One home per fact

| Fact | Owner |
| --- | --- |
| Client requirements, budgets, open questions | [docs/requirements.md](docs/requirements.md) |
| What a client sends to WLED and when | [docs/protocol.md](docs/protocol.md) |
| Parts, wiring, LED order | [docs/hardware.md](docs/hardware.md) |
| Board settings, address, port, Keychain accounts | [firmware/esp32/README.md](firmware/esp32/README.md) |
| Constraints of one OS | That client's README |
| A decision with rejected alternatives | A new file in [docs/adr/](docs/adr/) |

Change a fact in its owner and link to it everywhere else. A copy drifts.

## Secrets

Every secret is in the macOS Keychain under service `ambilight`. Never write a secret into the
repository, a log, a commit or a command line that shell history keeps.

## Before a change lands

```bash
tools/lint-docs.sh
```

## Writing and commits

Prose, code comments and commit bodies follow the skills under `.claude/skills/`:
`technical-writing` for prose, `markdown-formatting` for Markdown, `commit-messages` for commits,
`branch-names` for branches. Invoke the skill instead of working from memory.

Commits follow Conventional Commits, with the component as the scope: `feat(macos): ...`,
`docs(esp32): ...`. No attribution footer of any kind: no `Co-Authored-By`, no `Generated with`,
no tool credit. `tools/install-hooks.sh` installs a hook that refuses them.
