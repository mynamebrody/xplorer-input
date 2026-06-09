# Xplorer Remap

Play [Clone Hero](https://clonehero.net) on a Mac with the original **Guitar
Hero X-plorer** (the wired Xbox 360 Gibson Explorer, VID `1430:4748`).

macOS has no driver for classic XInput devices — the guitar enumerates but no
input ever reaches games. This little utility talks to the guitar directly
over USB (no kernel extension, no driver install) and turns every fret, strum,
whammy wiggle, and neck tilt into ordinary keyboard presses that any game can
read.

- Live remapping UI: click any binding, press a key, done
- Ships with Clone Hero's default keyboard controls out of the box
- No Apple Developer account anywhere in the chain: ad-hoc signed, built with
  plain `swift build`
- The only permission it needs is **Accessibility** (to synthesize key
  presses)

| Control | Default key |
|---|---|
| Green / Red / Yellow / Blue / Orange | A / S / J / K / L |
| Strum up / down | ↑ / ↓ |
| Start/Pause | Return |
| Select/Star Power | H |
| Whammy | ; |
| Tilt (Star Power) | H |

## Install (released build)

1. Download `XplorerRemap-x.y.z.zip` from
   [Releases](../../releases), unzip, drag **XplorerRemap.app** to
   `/Applications`.
2. Clear the quarantine flag (the app is ad-hoc signed, not notarized):
   ```sh
   xattr -dr com.apple.quarantine /Applications/XplorerRemap.app
   ```
3. Launch it. When the yellow banner appears, click **Open Settings** and
   enable XplorerRemap under **Privacy & Security → Accessibility**, then
   relaunch the app.
4. Plug in the guitar — the status dot turns green. Play.

> **After updating the app**, re-toggle its Accessibility checkbox (off → on).
> Ad-hoc signatures change with every build, and macOS ties the permission to
> the signature.

## Build from source

Requires Xcode Command Line Tools (`xcode-select --install`) — no Xcode, no
Apple ID.

```sh
make app        # → dist/XplorerRemap.app (ad-hoc signed)
make run        # build + launch
make dev        # run via swift run — the terminal's Accessibility grant
                #   covers it, so no per-rebuild permission churn
make probe      # CLI probe: dumps raw USB reports (debugging)
make test       # unit tests
```

## Troubleshooting

- **Status dot stays red** — replug the guitar; check it appears in
  System Information → USB as "Guitar Hero X-plorer".
- **Orange dot ("another app is using it")** — quit apps that grab USB
  devices wholesale (VMs, some conferencing tools), replug.
- **Connected but no keystrokes** — Accessibility isn't granted (or the grant
  went stale after an update). Re-toggle it in System Settings.
- **Keys stuck after unplugging mid-song** — shouldn't happen (the app
  releases all held keys on disconnect/sleep/quit); if it ever does, tap the
  physical key once.

## How it works

The X-plorer is a classic XInput device (`bDeviceClass 0xFF`) that macOS
leaves unconfigured and driverless. The app:

1. finds the device by VID/PID via IOKit and opens it with seize semantics,
2. issues `SetConfiguration(1)` — after which the guitar streams 20-byte
   XInput reports on the interrupt IN endpoint,
3. decodes frets/strum/start/select from the button bitfield, whammy from the
   RX axis, tilt from the RY axis (with hysteresis so axis noise never
   chatters keys), and
4. posts `CGEvent` keyboard events at the HID tap — with per-keycode
   refcounting, edge-only transitions (no autorepeat), and stuck-key
   protection on disconnect, sleep, rebind, and quit.

MIT licensed. Inspired by
[xinput-controller](https://github.com/mynamebrody/xinput-controller).
