import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kamp/core/dsp.dart';
import 'package:kamp/data/session.dart';

List<double> sine(double hz, double rate, int n, {double amp = 1, double offset = 0}) =>
    [for (var i = 0; i < n; i++) offset + amp * math.sin(2 * math.pi * hz * i / rate)];

void main() {
  group('HighPassFilter', () {
    test('removes a constant (gravity) offset', () {
      final f = HighPassFilter(alpha: highPassAlpha(0.5, 100));
      var last = 0.0;
      for (var i = 0; i < 1000; i++) {
        last = f.process(9.81);
      }
      expect(last.abs(), lessThan(1e-3));
    });

    test('passes a 10 Hz vibration riding on gravity', () {
      final f = HighPassFilter(alpha: highPassAlpha(0.5, 100));
      final input = sine(10, 100, 1000, amp: 0.5, offset: 9.81);
      final out = [for (final v in input) f.process(v)].sublist(500);
      expect(peak(out), closeTo(0.5, 0.1));
      expect(rms(out), closeTo(0.5 / math.sqrt2, 0.05));
    });
  });

  group('rms and peak', () {
    test('rms of a sine is amplitude / sqrt(2)', () {
      expect(rms(sine(5, 100, 1000, amp: 2)), closeTo(2 / math.sqrt2, 0.01));
    });

    test('rms and peak of known values', () {
      expect(rms([3, 4]), closeTo(math.sqrt(12.5), 1e-9));
      expect(peak([1, -5, 3]), 5);
      expect(rms(const []), 0);
      expect(peak(const []), 0);
    });
  });

  group('dominantFrequency', () {
    test('finds a 12 Hz sine at 100 Hz sampling', () {
      final f = dominantFrequency(sine(12, 100, 200), 100);
      expect(f, isNotNull);
      expect(f!, closeTo(12, 0.3));
    });

    test('finds a 3.5 Hz sine at 50 Hz sampling, ignoring a DC offset', () {
      final f = dominantFrequency(sine(3.5, 50, 128, offset: 4), 50);
      expect(f!, closeTo(3.5, 0.3));
    });

    test('picks the stronger of two tones', () {
      final a = sine(8, 200, 400, amp: 1);
      final b = sine(30, 200, 400, amp: 0.3);
      final f = dominantFrequency([for (var i = 0; i < 400; i++) a[i] + b[i]], 200);
      expect(f!, closeTo(8, 0.4));
    });

    test('returns null for silence or too few samples', () {
      expect(dominantFrequency(List.filled(256, 0.0), 100), isNull);
      expect(dominantFrequency(const [1, 2, 3], 100), isNull);
    });
  });

  group('intensity', () {
    test('bands rise with RMS', () {
      expect(intensityOf(0.001), Intensity.calm);
      expect(intensityOf(0.05), Intensity.faint);
      expect(intensityOf(0.2), Intensity.light);
      expect(intensityOf(0.5), Intensity.moderate);
      expect(intensityOf(2), Intensity.strong);
      expect(intensityOf(5), Intensity.severe);
    });
  });

  group('session data', () {
    test('CSV round trip', () {
      final samples = [const Sample(0, 0.1, -0.2, 0.3), const Sample(10, 1, 2, 3)];
      final back = samplesFromCsv(samplesToCsv(samples));
      expect(back.length, 2);
      expect(back[1].x, closeTo(1, 1e-4));
      expect(back[1].mag, closeTo(math.sqrt(14), 1e-3));
    });

    test('downsamplePeak keeps spikes', () {
      final v = List<double>.filled(1000, 0.1)..[503] = 4;
      final d = downsamplePeak(v, 100);
      expect(d.length, 100);
      expect(peak(d), 4);
    });
  });
}
