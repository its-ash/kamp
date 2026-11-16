import 'dart:math' as math;

/// First-order high-pass filter: removes the slowly changing part (gravity)
/// from an acceleration axis. `y[n] = a * (y[n-1] + x[n] - x[n-1])`.
class HighPassFilter {
  HighPassFilter({this.alpha = 0.95});

  /// Closer to 1 passes lower frequencies. At 100 Hz, 0.95 cuts below ~0.8 Hz.
  final double alpha;
  double _y = 0;
  double _x = 0;
  bool _primed = false;

  double process(double x) {
    if (!_primed) {
      _primed = true;
      _x = x;
      _y = 0;
      return 0;
    }
    _y = alpha * (_y + x - _x);
    _x = x;
    return _y;
  }

  void reset() {
    _primed = false;
    _y = 0;
    _x = 0;
  }
}

/// Alpha for a high-pass with the given cutoff at the given sample rate.
double highPassAlpha(double cutoffHz, double sampleRateHz) {
  final rc = 1 / (2 * math.pi * cutoffHz);
  final dt = 1 / sampleRateHz;
  return rc / (rc + dt);
}

double magnitude(double x, double y, double z) => math.sqrt(x * x + y * y + z * z);

/// Root mean square of [values]. 0 for an empty list.
double rms(Iterable<double> values) {
  var sum = 0.0;
  var n = 0;
  for (final v in values) {
    sum += v * v;
    n++;
  }
  return n == 0 ? 0 : math.sqrt(sum / n);
}

/// Largest absolute value of [values]. 0 for an empty list.
double peak(Iterable<double> values) {
  var p = 0.0;
  for (final v in values) {
    final a = v.abs();
    if (a > p) p = a;
  }
  return p;
}

/// In-place radix-2 FFT. [re] and [im] must have the same power-of-two length.
void fft(List<double> re, List<double> im) {
  final n = re.length;
  assert(n == im.length && n > 0 && (n & (n - 1)) == 0, 'length must be a power of two');
  // Bit reversal.
  var j = 0;
  for (var i = 1; i < n; i++) {
    var bit = n >> 1;
    for (; j & bit != 0; bit >>= 1) {
      j ^= bit;
    }
    j ^= bit;
    if (i < j) {
      final tr = re[i];
      re[i] = re[j];
      re[j] = tr;
      final ti = im[i];
      im[i] = im[j];
      im[j] = ti;
    }
  }
  for (var len = 2; len <= n; len <<= 1) {
    final ang = -2 * math.pi / len;
    final wr = math.cos(ang);
    final wi = math.sin(ang);
    for (var i = 0; i < n; i += len) {
      var cr = 1.0;
      var ci = 0.0;
      for (var k = 0; k < len ~/ 2; k++) {
        final a = i + k;
        final b = a + len ~/ 2;
        final xr = re[b] * cr - im[b] * ci;
        final xi = re[b] * ci + im[b] * cr;
        re[b] = re[a] - xr;
        im[b] = im[a] - xi;
        re[a] += xr;
        im[a] += xi;
        final ncr = cr * wr - ci * wi;
        ci = cr * wi + ci * wr;
        cr = ncr;
      }
    }
  }
}

/// Smallest power of two >= [n].
int nextPow2(int n) {
  var p = 1;
  while (p < n) {
    p <<= 1;
  }
  return p;
}

/// Dominant frequency (Hz) of [samples] taken at [sampleRate] Hz, or null if
/// the signal is too small or too short. The mean is removed, a Hann window is
/// applied, the spectrum is zero-padded and the peak is refined by parabolic
/// interpolation. Frequencies below [minHz] are ignored.
double? dominantFrequency(
  List<double> samples,
  double sampleRate, {
  double minHz = 0.5,
  double minAmplitude = 1e-4,
}) {
  final count = samples.length;
  if (count < 16 || sampleRate <= 0) return null;
  var mean = 0.0;
  for (final s in samples) {
    mean += s;
  }
  mean /= count;

  final n = nextPow2(count) * 2;
  final re = List<double>.filled(n, 0);
  final im = List<double>.filled(n, 0);
  for (var i = 0; i < count; i++) {
    final w = 0.5 - 0.5 * math.cos(2 * math.pi * i / (count - 1));
    re[i] = (samples[i] - mean) * w;
  }
  fft(re, im);

  final half = n ~/ 2;
  final mag = List<double>.filled(half, 0);
  for (var i = 0; i < half; i++) {
    mag[i] = math.sqrt(re[i] * re[i] + im[i] * im[i]);
  }
  final binHz = sampleRate / n;
  final first = math.max(1, (minHz / binHz).ceil());
  var best = first;
  for (var i = first; i < half - 1; i++) {
    if (mag[i] > mag[best]) best = i;
  }
  if (best >= half - 1) return null;
  // Amplitude of the peak, compensated for the window (sum of Hann = count/2).
  final amplitude = 2 * mag[best] / (count / 2);
  if (amplitude < minAmplitude) return null;

  var offset = 0.0;
  if (best > 0) {
    final a = mag[best - 1];
    final b = mag[best];
    final c = mag[best + 1];
    final denom = a - 2 * b + c;
    if (denom != 0) offset = 0.5 * (a - c) / denom;
  }
  return (best + offset) * binHz;
}

/// A named band of shaking strength, by RMS acceleration in m/s2.
enum Intensity {
  calm('Calm', 'Barely any vibration'),
  faint('Faint', 'Only a sensitive meter sees it'),
  light('Light', 'You can feel it with a hand on it'),
  moderate('Moderate', 'Clearly felt, things may rattle'),
  strong('Strong', 'Strong shaking'),
  severe('Severe', 'Violent shaking');

  const Intensity(this.label, this.hint);
  final String label;
  final String hint;
}

/// Classifies an RMS acceleration (m/s2, gravity removed).
Intensity intensityOf(double rmsAccel) {
  if (rmsAccel < 0.02) return Intensity.calm;
  if (rmsAccel < 0.08) return Intensity.faint;
  if (rmsAccel < 0.3) return Intensity.light;
  if (rmsAccel < 1.0) return Intensity.moderate;
  if (rmsAccel < 3.0) return Intensity.strong;
  return Intensity.severe;
}
