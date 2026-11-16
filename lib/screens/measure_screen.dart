import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../data/session.dart';
import '../meter/meter.dart';
import '../widgets/readouts.dart';

enum _View { magnitude, axes }

/// Live seismograph, readouts and the record button.
class MeasureScreen extends StatefulWidget {
  const MeasureScreen({super.key, required this.meter, required this.store, required this.onSaved});

  final VibrationMeter meter;
  final SessionStore store;
  final VoidCallback onSaved;

  @override
  State<MeasureScreen> createState() => _MeasureScreenState();
}

class _MeasureScreenState extends State<MeasureScreen> {
  _View _view = _View.magnitude;
  bool _saving = false;

  Future<void> _toggleRecording() async {
    final meter = widget.meter;
    if (!meter.recording) {
      meter.startRecording();
      return;
    }
    final result = meter.stopRecording();
    if (result == null) return;
    if (result.samples.length < 20) {
      context.showToast('Too short to save. Record for a few seconds.', status: UiStatus.warning);
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.store.save(
        startedAt: result.startedAt,
        samples: result.samples,
        sampleRate: result.sampleRate,
      );
      widget.onSaved();
      if (mounted) context.showToast('Session saved to History', status: UiStatus.success);
    } catch (_) {
      if (mounted) context.showToast('Could not save the session', status: UiStatus.danger);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meter = widget.meter;
    return ListenableBuilder(
      listenable: meter,
      builder: (context, _) {
        if (meter.state == MeterState.unavailable) {
          return const UiEmptyState(
            title: 'No accelerometer',
            message: 'This phone does not report acceleration, so Kamp cannot measure vibration.',
            icon: Icons.sensors_off_rounded,
          );
        }
        final chart = meter.chart(160);
        final series = _view == _View.magnitude
            ? [UiChartSeries('Magnitude', chart.m)]
            : [
                UiChartSeries('X', chart.x),
                UiChartSeries('Y', chart.y),
                UiChartSeries('Z', chart.z),
              ];
        return ListView(
          padding: const EdgeInsets.all(UiSpace.lg),
          children: [
            IntensityBanner(intensity: meter.intensity),
            const SizedBox(height: UiSpace.md),
            UiCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  UiSegmentedControl<_View>(
                    const [
                      UiSegment(_View.magnitude, label: 'Magnitude'),
                      UiSegment(_View.axes, label: 'X Y Z'),
                    ],
                    value: _view,
                    size: UiSize.sm,
                    expand: true,
                    onChanged: (v) => setState(() => _view = v),
                  ),
                  const SizedBox(height: UiSpace.md),
                  if (chart.m.length < 2)
                    const SizedBox(height: 200, child: Center(child: UiSpinner()))
                  else
                    UiLineChart(
                      series: series,
                      height: 200,
                      curved: false,
                      area: false,
                      animateUpdates: false,
                      tickCount: 4,
                      yFormat: (v) => v.toStringAsFixed(2),
                      semanticLabel: 'Live vibration trace, last 5 seconds',
                    ),
                  Text(
                    'Last 5 seconds, m/s²'
                    '${meter.sampleRate > 0 ? ' · ${meter.sampleRate.round()} samples/s' : ''}'
                    '${meter.usingFallback ? ' · filtered accelerometer' : ''}',
                    style: context.text.bodySmall?.copyWith(color: context.colors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: UiSpace.md),
            ReadoutGrid(
              current: meter.current,
              peak: meter.peakValue,
              rms: meter.rmsValue,
              hz: meter.dominantHz,
              onPeakTap: meter.resetPeak,
            ),
            Padding(
              padding: const EdgeInsets.only(top: UiSpace.xs),
              child: Text(
                'Tap Peak to reset it.',
                style: context.text.bodySmall?.copyWith(color: context.colors.textMuted),
              ),
            ),
            const SizedBox(height: UiSpace.lg),
            UiButton(
              meter.recording ? 'Stop and save · ${fmtDuration(meter.recordingMs)}' : 'Record session',
              icon: meter.recording ? Icons.stop_rounded : Icons.fiber_manual_record_rounded,
              status: meter.recording ? UiStatus.danger : null,
              loading: _saving,
              expand: true,
              onPressed: _saving ? null : _toggleRecording,
            ),
            const SizedBox(height: UiSpace.lg),
            UiAlert(
              'Rest the phone flat on a washing machine, fan, car engine, or a floor or bridge, '
              'and keep your hands off it. Compare readings before and after a fix.',
              title: 'How to use',
              status: UiStatus.info,
            ),
          ],
        );
      },
    );
  }
}
