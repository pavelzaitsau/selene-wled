# ADR-0001: Replace HyperHDR with Selene

- Status: accepted
- Date: 2026-09-29

## Context

HyperHDR 22 drives the strip, but the Mac runs warm. With the monitor showing a still picture and
HyperHDR at 15 fps and width 256, `top` gave:

| Process | Without HyperHDR | With HyperHDR |
| --- | --- | --- |
| `hyperhdr` | - | 15% |
| WindowServer | 40% | 55% |
| ControlCenter | - | 21% |
| opendirectoryd | - | 15% |

That is about 65% of one core for 104 LEDs. The macOS system log showed the cause: the HyperHDR
grabber calls `SCShareableContent` and registers a new `SCStream` for every frame. Control Center
redraws the recording indicator each time, and opendirectoryd answers the permission check. Going
from 20 to 15 fps and from width 512 to 256 cut the `hyperhdr` share only from 20% to 15%.

## Options considered

| # | Option | Cost | Why rejected / chosen |
| --- | --- | --- | --- |
| 1 | Tune HyperHDR settings | Tried: lower fps and width | Rejected: the session per frame is in the grabber code, not in a setting |
| 2 | Patch the HyperHDR grabber | A fork of a large C++ project | Not evaluated; Pavel used no other HyperHDR feature |
| 3 | Hyperion.ng or Prismatik | A second migration | Not evaluated |
| 4 | Own client with one persistent capture session | A small program per OS | Chosen |

## Decision

**Replace HyperHDR with Selene, an own client that keeps one capture session open.**

## Consequences

| Direction | Consequence |
| --- | --- |
| Simpler | One process, no web UI, no database |
| Harder | HDR tone mapping, black-border detection and effects are gone; none was in use |
| More expensive | Each OS needs its own client |

## Risk

A later change that recreates the capture session, for example on every display event, brings the
CPU cost back without any visible failure. [R8](../requirements.md#r8-one-capture-session) exists
to catch it.

## Expected effect

The four processes in the table add at most 5% of one core over the figures without HyperHDR, as
[R7](../requirements.md#r7-cpu-budget) sets.
