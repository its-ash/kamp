import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../data/session.dart';
import '../meter/meter.dart';
import '../platform/device.dart';
import 'history_screen.dart';
import 'measure_screen.dart';
import 'settings_screen.dart';

/// Two tabs: Measure (live seismograph) and History (saved sessions). The
/// meter lives here so it keeps running (and recording) across tabs; the screen
/// stays on while the app is open.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store, required this.device});

  final SessionStore store;
  final Device device;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const _items = [
    UiNavItem(Icons.vibration_rounded, 'Measure'),
    UiNavItem(Icons.history_rounded, 'History'),
  ];

  final _meter = VibrationMeter();
  final _historyKey = GlobalKey<HistoryScreenState>();
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.device.keepScreenOn(true);
    _meter.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Release the sensor in the background, unless a recording is running.
    if (state == AppLifecycleState.resumed) {
      _meter.start();
    } else if (state == AppLifecycleState.paused && !_meter.recording) {
      _meter.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.device.keepScreenOn(false);
    _meter.dispose();
    super.dispose();
  }

  void _openSettings() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return UiShell(
      items: _items,
      index: _tab,
      onChanged: (i) {
        setState(() => _tab = i);
        if (i == 1) _historyKey.currentState?.reload();
      },
      appBar: UiAppBar(
        title: _items[_tab].label,
        actions: [
          UiIconButton(Icons.settings_rounded, tooltip: 'Settings', onPressed: _openSettings),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          MeasureScreen(meter: _meter, store: widget.store, onSaved: () => _historyKey.currentState?.reload()),
          HistoryScreen(key: _historyKey, store: widget.store),
        ],
      ),
    );
  }
}
