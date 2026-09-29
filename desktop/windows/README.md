# Selene for Windows

Requirements stage. No code yet.

The Windows client meets [docs/requirements.md](../../docs/requirements.md) and speaks
[docs/protocol.md](../../docs/protocol.md), the same as the macOS client.

## Platform constraints

| Constraint | Consequence for the client |
| --- | --- |
| A Windows service runs in session 0 and cannot capture the interactive desktop | The client runs in the user session, for example as a tray app started at login |

## Open questions

| # | Question | Why it blocks | Owner | Needed by |
| --- | --- | --- | --- | --- |
| 1 | Which language and capture API, for example C# or Rust with Windows.Graphics.Capture? | Sets the toolchain and the layout of this directory | Pavel | Before work on the Windows client starts |
