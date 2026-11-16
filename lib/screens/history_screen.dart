import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../data/session.dart';
import '../widgets/readouts.dart';
import 'session_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.store});

  final SessionStore store;

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  List<SessionMeta>? _items;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    final items = await widget.store.list();
    if (mounted) setState(() => _items = items);
  }

  Future<void> _open(SessionMeta meta) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SessionScreen(meta: meta, store: widget.store)),
    );
    reload();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items == null) return const Center(child: UiSpinner());
    if (items.isEmpty) {
      return const UiEmptyState(
        title: 'No sessions yet',
        message: 'Record a session on the Measure tab and it will show up here.',
        icon: Icons.history_rounded,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(UiSpace.lg),
      children: [
        UiListGroup(
          children: [
            for (final m in items)
              UiListTile(
                m.name,
                subtitle: '${fmtDuration(m.durationMs)} · RMS ${fmtAccel(m.rms)} · '
                    'peak ${fmtAccel(m.peak)} m/s² · ${fmtHz(m.dominantHz)}',
                icon: Icons.vibration_rounded,
                iconStatus: intensityStatus(m.intensity),
                value: m.intensity.label,
                chevron: true,
                onTap: () => _open(m),
              ),
          ],
        ),
      ],
    );
  }
}
