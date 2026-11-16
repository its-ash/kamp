import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:theme/theme.dart';

import '../data/session.dart';
import '../widgets/readouts.dart';

/// A saved trace: chart, summary, rename, share as CSV, delete.
class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key, required this.meta, required this.store});

  final SessionMeta meta;
  final SessionStore store;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  late SessionMeta _meta = widget.meta;
  List<Sample>? _samples;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await widget.store.load(_meta.id);
      if (mounted) setState(() => _samples = s);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _share() async {
    final file = await widget.store.csvFile(_meta.id);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: 'text/csv')], subject: 'Kamp: ${_meta.name}'),
    );
  }

  Future<void> _rename() async {
    final name = await UiDialog.prompt(
      context,
      title: 'Rename session',
      initialValue: _meta.name,
      validator: (v) => v.trim().isEmpty ? 'Enter a name' : null,
    );
    if (name == null) return;
    await widget.store.rename(_meta, name.trim());
    if (mounted) setState(() => _meta = _meta.copyWith(name: name.trim()));
  }

  Future<void> _delete() async {
    final ok = await UiDialog.confirm(
      context,
      title: 'Delete this session?',
      message: 'The trace and its CSV are removed from this phone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    await widget.store.delete(_meta.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final samples = _samples;
    return UiScaffold(
      appBar: UiAppBar(
        title: _meta.name,
        actions: [
          UiIconButton(Icons.edit_rounded, tooltip: 'Rename', onPressed: _rename),
          UiIconButton(Icons.delete_outline_rounded, tooltip: 'Delete', onPressed: _delete),
        ],
      ),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntensityBanner(intensity: _meta.intensity),
          const SizedBox(height: UiSpace.md),
          if (_failed)
            const UiEmptyState(title: 'Could not open the trace', icon: Icons.error_outline_rounded, compact: true)
          else if (samples == null)
            const SizedBox(height: 200, child: Center(child: UiSpinner()))
          else
            UiCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UiLineChart(
                    series: [
                      UiChartSeries('Magnitude', downsamplePeak([for (final s in samples) s.mag], 240)),
                    ],
                    height: 220,
                    curved: false,
                    area: false,
                    animateUpdates: false,
                    yFormat: (v) => v.toStringAsFixed(2),
                    semanticLabel: 'Saved vibration trace',
                  ),
                  Text(
                    'm/s² over ${fmtDuration(_meta.durationMs)}',
                    style: context.text.bodySmall?.copyWith(color: context.colors.textMuted),
                  ),
                ],
              ),
            ),
          const SizedBox(height: UiSpace.md),
          ReadoutGrid(
            current: samples == null || samples.isEmpty ? 0 : samples.last.mag,
            currentLabel: 'Last',
            peak: _meta.peak,
            rms: _meta.rms,
            hz: _meta.dominantHz,
          ),
          const SizedBox(height: UiSpace.md),
          UiListGroup(
            children: [
              UiListTile('Recorded', value: _fmtDate(_meta.startedAt), icon: Icons.event_rounded),
              UiListTile('Duration', value: fmtDuration(_meta.durationMs), icon: Icons.timer_outlined),
              UiListTile(
                'Samples',
                value: '${_meta.count} at ~${_meta.sampleRate.round()}/s',
                icon: Icons.scatter_plot_rounded,
              ),
            ],
          ),
          const SizedBox(height: UiSpace.lg),
          UiButton('Share CSV', icon: Icons.ios_share_rounded, expand: true, onPressed: _share),
        ],
      ),
    );
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

String _fmtDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';
