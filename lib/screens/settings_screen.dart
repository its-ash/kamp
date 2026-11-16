import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const UiScaffold(
      appBar: UiAppBar(title: 'Settings'),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UiListGroup(
            header: 'Using Kamp',
            footer: 'Lay the phone flat on the surface you want to check, such as a washing machine, '
                'a fan, a car engine, or a floor or bridge. Keep it still and let the readings settle.',
            children: [
              UiListTile(
                'Gravity is removed',
                subtitle: 'Kamp shows only the shaking, in m/s², from the linear acceleration '
                    'sensor or a high-pass filter.',
                icon: Icons.vibration_rounded,
              ),
              UiListTile(
                'Indicative, not calibrated',
                subtitle: 'Phone sensors differ. Use the readings to compare, not as a certified measurement.',
                icon: Icons.info_outline_rounded,
                iconStatus: UiStatus.info,
              ),
            ],
          ),
          UiGap(UiSpace.lg),
          UiListGroup(
            header: 'Privacy',
            children: [
              UiListTile(
                'Everything stays on this phone',
                subtitle: 'Sessions are saved on the device and shared only when you choose. '
                    'Kamp uses the internet only to check for app updates.',
                icon: Icons.lock_rounded,
                iconStatus: UiStatus.success,
              ),
            ],
          ),
          UiGap(UiSpace.lg),
          UiAppearanceSection(),
          UiGap(UiSpace.lg),
          UiUpdateSection(storeId: 'kamp'),
          UiGap(UiSpace.lg),
          UiDeveloperSection(),
        ],
      ),
    );
  }
}
