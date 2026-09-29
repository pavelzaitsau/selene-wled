# Selene for macOS

Requirements stage. No code on this branch.

The macOS client meets [docs/requirements.md](../../docs/requirements.md) and speaks
[docs/protocol.md](../../docs/protocol.md). A working prototype lives on branch
`feat/macos-client`. It is a Swift LaunchAgent with one persistent `SCStream`.

## Platform constraints

These facts about macOS shape any client, and the prototype ran into each one.

| Constraint | Consequence for the client |
| --- | --- |
| ScreenCaptureKit delivers no frames for a still picture | The client needs its own timer for the resend in [R5](../../docs/requirements.md#r5-still-picture) |
| Screen Recording permission is tied to the code signature | An ad-hoc signed rebuild loses the grant; the client logs the missing permission |
| A LaunchAgent needs Local Network permission for UDP and HTTP to the LAN | Without it, every send fails silently; the client logs the network state |
| `NSScreen.localizedName` of the monitor contains `LG ULTRAFINE` | [R2](../../docs/requirements.md#r2-target-monitor) holds on macOS |
| Each new `SCStream` wakes Control Center and opendirectoryd | [R8](../../docs/requirements.md#r8-one-capture-session): one stream per monitor connection |
