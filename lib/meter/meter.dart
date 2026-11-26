import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../core/dsp.dart';
import '../data/session.dart';

enum MeterState { idle, starting, running, unavailable }

/// Reads the accelerometer with gravity removed, keeps a short rolling window
/// for the live chart and the readouts, and optionally records a session.
///
/// Uses the linear acceleration sensor; if the phone has none, falls back to
/// the raw accelerometer through a high-pass filter. Notifies about 20 times a
/// second, not once per sample.
class VibrationMeter extends ChangeNotifier {
  VibrationMeter({this.windowMs = 5000, this.rmsWindowMs = 1000, this.fftWindowMs = 2000});

  /// Length of the chart window.
  final double windowMs;

  /// Window for the RMS readout.
  final double rmsWindowMs;

  /// Window for the FFT.
  final double fftWindowMs;

  MeterState state = MeterState.idle;

  /// True when the raw accelerometer plus a high-pass filter is in use.
  bool usingFallback = false;

  double current = 0;
  double peakValue = 0;
  double rmsValue = 0;
  double? dominantHz;
  double sampleRate = 0;
  Intensity get intensity => intensityOf(rmsValue);

  // Rolling window, parallel lists (time in ms since start()).
  final _t = <double>[];
  final _x = <double>[];
  final _y = <double>[];
  final _z = <double>[];
  final _m = <double>[];

  final _clock = Stopwatch();
  StreamSubscription<Object>? _sub;
  Timer? _tick;
  Timer? _watchdog;
  double _lastFft = -1e9;
  bool _gotSample = false;
  final _hp = [HighPassFilter(alpha: 0.99), HighPassFilter(alpha: 0.99), HighPassFilter(alpha: 0.99)];
  double? _firstSensorUs;

  // Recording.
  bool recording = false;
  DateTime? recordingStartedAt;
  double _recordOriginMs = 0;
  List<Sample> _recorded = [];
  double _recordRateSum = 0;
  int _recordRateN = 0;

  double get recordingMs => recording ? _nowMs - _recordOriginMs : 0;
  int get recordedCount => _recorded.length;
  double get _nowMs => _clock.elapsedMicroseconds / 1000;

  /// Window of recent samples for the chart: (x, y, z, magnitude), each at most
  /// [maxPoints] long, peaks preserved.
  ({List<double> x, List<double> y, List<double> z, List<double> m}) chart(int maxPoints) {
    return (
      x: downsamplePeak(_x, maxPoints),
      y: downsamplePeak(_y, maxPoints),
      z: downsamplePeak(_z, maxPoints),
      m: downsamplePeak(_m, maxPoints),
    );
  }

  void start() {
    if (state == MeterState.running || state == MeterState.starting) return;
    state = MeterState.starting;
    _gotSample = false;
    _lastFft = -1e9;
    dominantHz = null;
    _clock
      ..reset()
      ..start();
    _listen(fallback: false);
    _tick = Timer.periodic(const Duration(milliseconds: 50), (_) => _update());
    notifyListeners();
  }

  void _listen({required bool fallback}) {
    _sub?.cancel();
    _watchdog?.cancel();
    usingFallback = fallback;
    for (final f in _hp) {
      f.reset();
    }
    _firstSensorUs = null;
    void onError(Object _) => _onSourceFailed();
    if (fallback) {
      _sub = accelerometerEventStream(samplingPeriod: SensorInterval.fastestInterval).listen(
        (e) => _onRaw(e.x, e.y, e.z, e.timestamp.microsecondsSinceEpoch),
        onError: onError,
      );
    } else {
      _sub = userAccelerometerEventStream(samplingPeriod: SensorInterval.fastestInterval).listen(
        (e) => ingest(e.x, e.y, e.z, _sensorMs(e.timestamp.microsecondsSinceEpoch)),
        onError: onError,
      );
    }
    _watchdog = Timer(const Duration(milliseconds: 1500), () {
      if (!_gotSample) _onSourceFailed();
    });
  }

  void _onSourceFailed() {
    if (!usingFallback) {
      _listen(fallback: true);
    } else {
      _sub?.cancel();
      _sub = null;
      _tick?.cancel();
      _tick = null;
      _watchdog?.cancel();
      _watchdog = null;
      state = MeterState.unavailable;
      notifyListeners();
    }
  }

  void _onRaw(double x, double y, double z, int us) {
    ingest(_hp[0].process(x), _hp[1].process(y), _hp[2].process(z), _sensorMs(us));
  }

  /// Sensor timestamps give the true spacing even when events arrive in
  /// batches. They are shifted to start at the current clock time.
  double _sensorMs(int us) {
    _firstSensorUs ??= us - _nowMs * 1000;
    return (us - _firstSensorUs!) / 1000;
  }

  /// Feeds one gravity-free sample taken at [tMs] (ms since [start]).
  /// Public so tests and the fallback path share one code path.
  void ingest(double x, double y, double z, double tMs) {
    if (!_gotSample) {
      _gotSample = true;
      state = MeterState.running;
    }
    final m = magnitude(x, y, z);
    _t.add(tMs);
    _x.add(x);
    _y.add(y);
    _z.add(z);
    _m.add(m);
    current = m;
    if (m > peakValue) peakValue = m;
    if (recording) {
      _recorded.add(Sample(tMs - _recordOriginMs, x, y, z));
    }
    // Trim the window; amortised so removal is not per sample.
    final cutoff = tMs - windowMs - 500;
    if (_t.length > 64 && _t.first < cutoff) {
      var n = 0;
      while (n < _t.length && _t[n] < cutoff) {
        n++;
      }
      _t.removeRange(0, n);
      _x.removeRange(0, n);
      _y.removeRange(0, n);
      _z.removeRange(0, n);
      _m.removeRange(0, n);
    }
  }

  int _firstIndexAfter(double fromMs) {
    var lo = 0;
    var hi = _t.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_t[mid] < fromMs) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// Recomputes RMS, sample rate and (a few times a second) the FFT.
  void _update() {
    if (_t.isEmpty) return;
    final last = _t.last;
    final from = _firstIndexAfter(last - rmsWindowMs);
    final n = _t.length - from;
    if (n >= 2) {
      rmsValue = rms(_m.getRange(from, _t.length));
      final span = _t.last - _t[from];
      if (span > 0) {
        sampleRate = (n - 1) / span * 1000;
        if (recording) {
          _recordRateSum += sampleRate;
          _recordRateN++;
        }
      }
    }
    if (last - _lastFft >= 250 && sampleRate > 0) {
      _lastFft = last;
      final f = _firstIndexAfter(last - fftWindowMs);
      dominantHz = dominantFrequency(_m.sublist(f), sampleRate);
    }
    notifyListeners();
  }

  void resetPeak() {
    peakValue = current;
    notifyListeners();
  }

  void startRecording() {
    if (recording) return;
    recording = true;
    recordingStartedAt = DateTime.now();
    _recordOriginMs = _t.isEmpty ? _nowMs : _t.last;
    _recorded = [];
    _recordRateSum = 0;
    _recordRateN = 0;
    notifyListeners();
  }

  /// Stops recording and returns what was captured (empty if nothing).
  ({DateTime startedAt, List<Sample> samples, double sampleRate})? stopRecording() {
    if (!recording) return null;
    recording = false;
    final out = (
      startedAt: recordingStartedAt!,
      samples: _recorded,
      sampleRate: _recordRateN == 0 ? sampleRate : _recordRateSum / _recordRateN,
    );
    _recorded = [];
    notifyListeners();
    return out;
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _tick?.cancel();
    _watchdog?.cancel();
    _tick = null;
    _clock.stop();
    if (state != MeterState.unavailable) state = MeterState.idle;
    _t.clear();
    _x.clear();
    _y.clear();
    _z.clear();
    _m.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tick?.cancel();
    _watchdog?.cancel();
    super.dispose();
  }
}
