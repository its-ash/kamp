import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import 'data/session.dart';
import 'platform/device.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(KampApp(store: SessionStore(), device: const Device()));
}

class KampApp extends StatelessWidget {
  const KampApp({super.key, required this.store, required this.device});

  final SessionStore store;
  final Device device;

  @override
  Widget build(BuildContext context) {
    return UiApp(
      title: 'Kamp',
      home: HomeScreen(store: store, device: device),
    );
  }
}
