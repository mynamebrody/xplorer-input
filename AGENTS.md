# XplorerRemap

A pure-SPM macOS app (no Xcode project, no Apple Developer account) that talks
to the Guitar Hero X-plorer over raw USB and synthesizes keyboard events so it
can play Clone Hero.

## Device facts (verified live on hardware, 2026-06-09)

- VID `0x1430`, PID `0x4748`, "Guitar Hero X-plorer", full-speed USB,
  `bDeviceClass 0xFF` — classic XInput, **not** HID; invisible to
  hidutil/GameController.
- macOS attaches **no driver**; device enumerates **unconfigured**
  (`GetConfiguration == 0`). Chrome/Zoom may hold passive
  AppleUSBHostDeviceUserClient handles — seize wins over them.
- After `SetConfiguration(1)`: 20-byte XInput reports stream on interrupt IN.
  Input interface is class `0xFF` / subclass `0x5D` / protocol `0x01`.
- Report: byte0=0x00, byte1=0x14 (anything else, e.g. LED status `01 03 xx`,
  must be ignored). Full wired-360 bitfield — byte2: 0=DpadUp(StrumUp)
  1=DpadDown(StrumDown) 2=DpadLeft 3=DpadRight 4=Start 5=Back(Select) 6=L3
  7=R3; byte3: 0=LB(Orange) 1=RB 2=Guide 4=A(Green) 5=B(Red) 6=X(Blue)
  7=Y(Yellow). Bytes 4/5 = triggers; 6–7 LX, 8–9 LY, 10–11 RX, 12–13 RY
  (int16 LE). Whammy = RX: rest -32768 → full press +32767. Tilt = RY:
  rest ≈ +3000 with ±300 jitter, neck vertical +32767, negative when pointed
  down. All button bits + both axes confirmed against hardware.
- LED command on interrupt OUT: `{0x01, 0x03, code}` (0x06 = player-1 solid).
- Diagnosing the device from a shell:
  `ioreg -p IOUSB -l -w0 | grep -iE "guitar|idVendor|bDeviceClass"` —
  XInput territory = `bDeviceClass 255`, no driver children on the node.

## Architecture

- `Sources/CXplorerUSB/` — C wrapper over deprecated-but-working IOUSBLib
  (only userspace USB API with seize). Blocking `ReadPipe` + `xplorer_abort()`
  from another thread; **interrupt pipes do not support read timeouts**
  (`ReadPipeTO` is bulk-only — don't "fix" this).
- `Sources/XplorerKit/` — UI-free, unit-tested: `ReportParser`,
  `MappingEngine` (state diffing, per-keycode refcounts since Tilt+Select both
  default to H, analog hysteresis on>0.50/off<0.40, `releaseAll()` stuck-key
  protection, `setSuspended()` so key-recording can't capture the guitar's own
  synthesized keys), `KeyMapStore` (JSON in
  `~/Library/Application Support/XplorerRemap/mapping.json`).
- `Sources/XplorerRemap/` — SwiftUI window app. `ControllerReader` runs a
  background thread: 1s open-poll (doubles as replug/wake recovery) → blocking
  read loop → `engine.apply` on the reader thread (no main-thread hop before
  CGEventPost), ~30Hz throttled UI publishes. `AppDelegate` forces
  `.regular` activation policy (pure-SPM executables otherwise get no Dock
  icon under `swift run`) and `beginActivity(.latencyCritical)` against App
  Nap.
- `Sources/xplorer-probe/` — CLI that dumps raw reports (`make probe`);
  `--play` adds CGEvent posting for smoke tests.

## Build & permissions

- `make app` → `dist/XplorerRemap.app`, ad-hoc signed
  (`codesign -s - --identifier com.brody.xplorer-remap`). `make zip` for
  release artifacts (uses `ditto`, preserves signatures). Universal build:
  `FLAGS="--arch arm64 --arch x86_64"`.
- Only permission: **Accessibility** (TCC) for `CGEventPost`. Ad-hoc
  signatures change per build → bundled-app grants go stale after rebuilds
  (re-toggle in System Settings, or `tccutil reset Accessibility
  com.brody.xplorer-remap`). **Dev loop: `make dev`** — running via
  `swift run` from a terminal rides the terminal's Accessibility grant, no
  churn.
- Release: push a `v*` tag → `.github/workflows/release.yml` builds a
  universal zip and attaches it to the GitHub Release.
- `make test` before committing; all logic lives in `XplorerKit` so it stays
  unit-testable without hardware.

## Gotchas

1. Never leave keys held: any new exit/disconnect path must call
   `engine.releaseAll()`.
2. `XplorerResult` is a C enum — compare Swift-side ints against
   `XPLORER_*.rawValue`.
3. The whammy floods reports with axis jitter; UI publishes are throttled —
   keep `engine.apply` on the reader thread for latency.
4. Other GH guitars (World Tour etc., also VID 0x1430) have different report
   semantics — exact-PID match only.
5. Only one process can hold the device: quit `xplorer-probe` before running
   the app (and vice versa) or you'll get the "another app is using it"
   status.
