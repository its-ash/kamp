# Kamp (package: kamp / com.itsash.kamp)

Vibration meter and seismograph for Android, offline. Live trace of the
gravity-free acceleration (X/Y/Z and magnitude), readouts (current, peak, RMS,
dominant frequency, intensity label), recording sessions, history, CSV share.
Use cases in copy: washing machine, fan, car engine, floor or bridge.

## Code layout

- `lib/core/dsp.dart`: pure functions, unit tested in `test/`. `HighPassFilter`
  and `highPassAlpha`, `rms`, `peak`, radix-2 `fft`, `dominantFrequency` (mean
  removed, Hann window, zero padded, parabolic peak), `Intensity` and
  `intensityOf` (RMS m/s2 bands). Add a test for every change.
- `lib/meter/meter.dart`: `VibrationMeter` (ChangeNotifier, notifies at ~20 Hz).
  Uses `userAccelerometerEventStream` at `SensorInterval.fastestInterval`; if it
  errors or gives no sample in 1.5 s, falls back to the raw accelerometer through
  a high-pass filter. Sensor timestamps give the true sample rate. Keeps a 5 s
  rolling window, FFT over 2 s every 250 ms, RMS over 1 s, and records samples.
- `lib/data/session.dart`: `Sample`, `SessionMeta`, CSV encode/decode,
  `downsamplePeak`, `SessionStore` (`<documents>/sessions/<id>.csv` + `<id>.json`,
  id = start time in epoch ms).
- `lib/platform/device.dart`: `com.itsash.kamp/device` method `keepScreenOn`.
- `lib/screens/`: `home_screen` (UiShell: Measure and History tabs, owns the
  meter, releases the sensor when paused unless recording), `measure_screen`,
  `history_screen`, `session_screen` (chart, rename, delete, share CSV with
  share_plus), `settings_screen` (ends with `UiAppearanceSection`,
  `UiUpdateSection(storeId: 'kamp')`, `UiDeveloperSection`).
- `lib/widgets/readouts.dart`: intensity banner and readout grid (UiStatCard).
- `android/.../MainActivity.kt`: `FLAG_KEEP_SCREEN_ON` channel only.

## Commands

- `make run`, `make build` (release APK), `make test` (`flutter analyze` +
  `flutter test`), `make clean`.
- Icon: SVG sources in `assets/icon/` (`logo`, `logo_foreground`,
  `logo_background`) exported to `*-1024.png`, then
  `dart run flutter_launcher_icons`.

## Conventions

- minSdk 26. UI only from the shared `theme` package (`../theme`, read
  `../theme/COMPONENTS.md`); no hardcoded colors. Light mode by default.
- Permissions: `INTERNET` only (update check). Accelerometer needs no permission.
  No analytics; sessions stay on the phone unless the user shares a CSV.
- Readings are uncalibrated and indicative; keep that note in the UI.

## Release (Ash Store)

- `store.json` (id `kamp`, repo its-ash/kamp), `store.mk`, `index.html` + `CNAME`
  (`kamp.itsash.in`). See `../ash-store/store-kit/STORE.md`.
- `make deploy` = bump version → build → commit, tag `vX.Y.Z`, push → GitHub
  release with `kamp.apk` → topics, homepage, Pages. Never create releases,
  tags or asset names by hand.
- Do not edit `store.mk` here. Edit `../ash-store/store-kit/store.mk`, then run
  `make store-sync` at the workspace root.
