# ADR-0002: One repository, one directory per component

- Status: accepted
- Date: 2026-09-29

## Context

Selene has board configuration today, and a macOS and a Windows client to come. All of them depend
on the same facts: the requirements, the LED order, the zone sizes and the WLED protocol.

## Options considered

| # | Option | Cost | Why rejected / chosen |
| --- | --- | --- | --- |
| 1 | One repository per component | Each repository keeps its own copy of the shared facts | Rejected: the copies drift |
| 2 | One repository, `desktop/<os>/` and `firmware/<board>/` | Commits need a component scope | Chosen |

## Decision

**Keep every component in this repository, with shared facts in `docs/`.**

## Consequences

| Direction | Consequence |
| --- | --- |
| Simpler | One change updates the protocol and every client that follows it |
| Harder | Each component brings its own toolchain; a future CI builds only the component that changed |
| More expensive | None |

## Risk

A client copies a number from [protocol.md](../protocol.md) into its code and later changes it
only in the code. The clients then disagree on the picture.

## Expected effect

None.
