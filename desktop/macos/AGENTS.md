# Agent instructions: macOS client

The repository-wide rules are in [the root AGENTS.md](../../AGENTS.md). This file adds the rules
for `desktop/macos/`.

## Before a change lands

```bash
tools/build.sh
```

The script runs `selene-check` and stops at the first failed check. Run `tools/install.sh` only
when Pavel asks: it replaces the running daemon.

After a change to the capture path, measure CPU as
[R7](../../docs/requirements.md#r7-cpu-budget) describes, and GPU as the README's measurements
section does. Try a capture setting with `defaults` first; a rebuild is only needed for code.

## Keep in place

- **The keepalive timer.** Without it, [R5](../../docs/requirements.md#r5-still-picture) fails on
  every still picture.
- **The UDP state log line.** It is the only trace of a missing Local Network permission.
- **`SeleneCore` on Foundation only.** A system framework there takes the code out of reach of
  `selene-check`.
