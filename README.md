# Kamp

Vibration meter and seismograph for washing machines, fans, engines and floors.

**[Website](https://kamp.itsash.in)** · **[Download APK](https://github.com/its-ash/kamp/releases/latest/download/kamp.apk)** · Get it in **[Ash Store](https://store.itsash.in)**

## Features

- **Live seismograph**: a scrolling trace of the last 5 seconds, as magnitude or
  as separate X, Y and Z axes, with gravity removed and the fastest sample rate
  the phone offers.
- **Readouts**: current, peak (tap to reset), RMS, dominant frequency from an
  FFT, and an intensity label from calm to severe.
- **Record sessions**: record, save, browse the history, reopen a saved trace,
  rename or delete it, and share it as a CSV file.
- **Use it for**: checking a washing machine or fan for imbalance, an engine's
  idle, or the vibration of a floor or bridge.
- The screen stays on while Kamp is open.
- **Private**: no accounts, no ads. The only network call is the update check
  in Settings.

Phone sensors are not calibrated, so use the readings to compare, not as a
certified measurement.

## Install

- **Ash Store**: install [Ash Store](https://store.itsash.in) once, then install and update Kamp from it.
- **APK**: download the [latest APK](https://github.com/its-ash/kamp/releases/latest/download/kamp.apk) on your phone and open it. Allow your browser to install unknown apps if Android asks.

Requires Android 8.0 (API 26) or later and an accelerometer.

## Develop

Needs Flutter ≥ 3.44 and the shared theme package at `../theme`.

```bash
make run      # run on a connected device
make test     # flutter analyze + flutter test
make build    # release APK
make deploy   # bump version, build, tag, push, GitHub release (see store.mk)
```

## Release

`make deploy` follows the Ash Store kit (`store.mk`, `store.json`): it bumps the
version in `pubspec.yaml`, builds, commits, tags `vX.Y.Z`, pushes, and publishes
a GitHub release with `kamp.apk`. Ash Store and the website pick up the new
version from that release.

## Project layout

```
lib/
├── main.dart                    # UiApp + HomeScreen
├── core/dsp.dart                # high-pass filter, RMS, peak, FFT, intensity (tested)
├── meter/meter.dart             # sensor stream, rolling window, stats, recording
├── data/session.dart            # samples, CSV, SessionStore (documents/sessions)
├── platform/device.dart         # keep-screen-on channel
├── widgets/readouts.dart        # intensity banner, 2x2 readout grid
└── screens/                     # home (UiShell), measure, history, session, settings
android/app/src/main/kotlin/com/itsash/kamp/MainActivity.kt   # keepScreenOn
```

See `CLAUDE.md` for details.

## License

No license file is included yet.

Built by [itsash.in](https://itsash.in).
