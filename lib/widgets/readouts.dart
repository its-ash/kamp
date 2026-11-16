import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../core/dsp.dart';

/// Acceleration in m/s2 with a precision that suits its size.
String fmtAccel(double v) => v < 1 ? v.toStringAsFixed(3) : v.toStringAsFixed(2);

String fmtHz(double? hz) => hz == null ? '--' : '${hz.toStringAsFixed(hz < 10 ? 1 : 0)} Hz';

String fmtDuration(double ms) {
  final s = (ms / 1000).floor();
  final m = s ~/ 60;
  final r = s % 60;
  return m > 0 ? '${m}m ${r.toString().padLeft(2, '0')}s' : '${(ms / 1000).toStringAsFixed(1)}s';
}

UiStatus intensityStatus(Intensity i) => switch (i) {
      Intensity.calm || Intensity.faint => UiStatus.success,
      Intensity.light => UiStatus.info,
      Intensity.moderate => UiStatus.warning,
      Intensity.strong || Intensity.severe => UiStatus.danger,
    };

/// The big intensity label with its hint.
class IntensityBanner extends StatelessWidget {
  const IntensityBanner({super.key, required this.intensity});

  final Intensity intensity;

  @override
  Widget build(BuildContext context) {
    final tone = context.colors.tone(intensityStatus(intensity));
    return UiCard(
      child: Row(
        children: [
          UiIconBox(Icons.vibration_rounded, status: intensityStatus(intensity)),
          const SizedBox(width: UiSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(intensity.label, style: context.text.headlineSmall?.copyWith(color: tone.color)),
                Text(intensity.hint, style: context.text.bodyMedium?.copyWith(color: context.colors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Four readouts in a 2x2 grid: current, peak, RMS, dominant frequency.
class ReadoutGrid extends StatelessWidget {
  const ReadoutGrid({
    super.key,
    required this.current,
    required this.peak,
    required this.rms,
    required this.hz,
    this.currentLabel = 'Current',
    this.onPeakTap,
  });

  final double current;
  final double peak;
  final double rms;
  final double? hz;
  final String currentLabel;
  final VoidCallback? onPeakTap;

  @override
  Widget build(BuildContext context) {
    Widget tile(String label, String value, IconData icon, {VoidCallback? onTap}) => Expanded(
          child: UiStatCard(label: label, value: value, icon: icon, onTap: onTap),
        );
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            tile(currentLabel, '${fmtAccel(current)} m/s²', Icons.speed_rounded),
            const SizedBox(width: UiSpace.md),
            tile('Peak', '${fmtAccel(peak)} m/s²', Icons.north_rounded, onTap: onPeakTap),
          ],
        ),
        const SizedBox(height: UiSpace.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            tile('RMS', '${fmtAccel(rms)} m/s²', Icons.equalizer_rounded),
            const SizedBox(width: UiSpace.md),
            tile('Frequency', fmtHz(hz), Icons.waves_rounded),
          ],
        ),
      ],
    );
  }
}
