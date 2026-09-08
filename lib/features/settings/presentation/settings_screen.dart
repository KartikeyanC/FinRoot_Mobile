import 'package:flutter/material.dart';

import '../../../design/design.dart';

/// Settings — profile, workspace switcher, app lock (PIN / biometric),
/// theme, sign-out. Built in M3.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Settings',
      milestone: 'M3',
      icon: Icons.settings_outlined,
    );
  }
}
