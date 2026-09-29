# Selene for macOS

Prototype. `selene` is a Swift LaunchAgent that streams the edges of the LG monitor to WLED. It
aims at [docs/requirements.md](../../docs/requirements.md) and speaks
[docs/protocol.md](../../docs/protocol.md). Since 2026-09-29 it drives the strip in place of
HyperHDR.

It needs macOS 14 or later on Apple silicon and the Xcode Command Line Tools.

## Use it

Run from `desktop/macos/`:

```bash
tools/build.sh      # run the checks, build build/Selene.app, sign it ad hoc
tools/install.sh    # copy to ~/Applications, load LaunchAgent com.pavel.selene
tools/uninstall.sh  # remove the app, the LaunchAgent and the Screen Recording grant
```

`tools/install.sh` replaces a running copy. The first run asks for Screen Recording and Local
Network, both for `Selene.app`. The log is `~/Library/Logs/selene.log`.

## Signing

macOS grants Screen Recording to the app's designated requirement. With an ad-hoc signature that
requirement is the hash of the build, so every rebuild loses the grant. `tools/build.sh` therefore
signs with the certificate `Selene Local Signing` from the login Keychain when it exists, and falls
back to ad hoc when it does not. Set `SELENE_SIGN_IDENTITY` to sign with another certificate.

The certificate is self-signed, valid for code signing only, and not trusted by the system. Trust
is not needed: the requirement names the certificate by its hash. To create it on a new Mac:

```bash
cat > cs.cnf <<'CNF'
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = Selene Local Signing
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CNF
openssl req -x509 -newkey rsa:2048 -nodes -keyout key.pem -out cert.pem -days 3650 -config cs.cnf
openssl pkcs12 -export -legacy -inkey key.pem -in cert.pem -out id.p12 -passout pass:temp
security import id.p12 -k ~/Library/Keychains/login.keychain-db -P temp -T /usr/bin/codesign
rm key.pem id.p12
```

The first signature shows a Keychain prompt; answer Always Allow. After the switch from ad hoc,
reset the old grant once with `tccutil reset ScreenCapture com.pavel.selene` and grant it again.

## Configuration

Settings are constants in `Sources/SeleneCore/Config.swift`. The values follow
[docs/protocol.md](../../docs/protocol.md), which owns them; change a value there first.

Four capture settings are tunable with `defaults`, without a rebuild. A restart of the LaunchAgent
applies them:

```bash
defaults write com.pavel.selene fps -int 10
launchctl kickstart -k gui/$(id -u)/com.pavel.selene
```

| Key | Default | Effect |
| --- | --- | --- |
| `fps` | 15 | Upper bound of the capture rate |
| `captureWidth` | 128 | Width of the GPU-scaled frame; the height follows the aspect |
| `nominalResolution` | `true` | Scale from the display's points instead of its pixels |
| `smoothingTime` | 0.0935 | Time constant of the colour smoothing, in seconds |

`defaults delete com.pavel.selene` restores every default. The first log line after a start
states the values in use.

## Measurements

Measured on 2026-09-29 with the Rainbow test full screen on the LG, 1920x1080 points on 3840x2160
pixels. Each figure is the mean of two 12 s runs, compared with the daemon stopped in the same
round. GPU is `Device Utilization %` from `ioreg -c IOAccelerator`.

| Variant | GPU over baseline | CPU of `selene` and `replayd` |
| --- | --- | --- |
| 30 fps, pixels (first prototype) | +9.7 points | 2.7% |
| 30 fps, points | +2.2 points | 2.4% |
| 15 fps, points (default) | +1.1 points | 1.4% |
| 10 fps, points | +0.3 points | 1.0% |

Scaling from points removes most of the GPU cost; the frame rate sets the CPU cost. ControlCenter
and opendirectoryd stayed within noise in every variant. HyperHDR cost about 65% of one core, see
[ADR-0001](../../docs/adr/0001-replace-hyperhdr.md).

## Layout

| Path | Contents |
| --- | --- |
| `Sources/SeleneCore/` | Configuration, zone layout, DRGB encoding; Foundation only |
| `Sources/selene/` | The daemon: capture, WLED power, logging |
| `Sources/selene-check/` | Checks for `SeleneCore`, run by `tools/build.sh` |
| `bundle/Info.plist` | App bundle metadata, including the Local Network prompt text |
| `launchd/` | LaunchAgent template that `tools/install.sh` fills in |

Command Line Tools ship neither XCTest nor the swift-testing macros. The checks are therefore a
plain executable: `swift run selene-check`.

## Platform constraints

| Constraint | Consequence for the client |
| --- | --- |
| ScreenCaptureKit delivers no frames for a still picture | The client needs its own timer for the resend in [R5](../../docs/requirements.md#r5-still-picture) |
| Screen Recording permission is tied to the code signature | An ad-hoc signed rebuild loses the grant; the client logs the missing permission |
| A LaunchAgent needs Local Network permission for UDP and HTTP to the LAN | Without it, every send fails silently; the client logs the network state |
| `NSScreen.localizedName` of the monitor contains `LG ULTRAFINE` | [R2](../../docs/requirements.md#r2-target-monitor) holds on macOS |
| Each new `SCStream` wakes Control Center and opendirectoryd | [R8](../../docs/requirements.md#r8-one-capture-session): one stream per monitor connection |

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| Log shows `no Screen Recording permission` | A rebuild changed the signature | Grant Screen Recording to `Selene.app` again |
| Log shows `udp: ready`, strip stays dark | Local Network permission is missing | Allow Selene under Privacy & Security, Local Network |
| Strip glows one flat colour | WLED shows its own state, not the stream | Check `live` and `lip` in `/json/info` |
| `WLED unreachable` in the log | Board off or off the network | Read `/json/info` on the board |
