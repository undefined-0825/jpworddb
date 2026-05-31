import 'package:flutter/material.dart';

import 'settings_screen.dart';

class KotonohaHeader extends StatelessWidget implements PreferredSizeWidget {
  final bool enableSettingsNavigation;

  const KotonohaHeader({super.key, this.enableSettingsNavigation = true});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF6D4C41),
      foregroundColor: Colors.white,
      title: const Text('コトノハ', style: TextStyle(fontWeight: FontWeight.bold)),
      actions: [
        IconButton(
          onPressed: enableSettingsNavigation
              ? () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                )
              : null,
          icon: const Icon(Icons.settings),
          tooltip: '設定',
        ),
      ],
    );
  }
}
