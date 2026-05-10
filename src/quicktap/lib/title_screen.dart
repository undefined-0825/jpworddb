import 'package:flutter/material.dart';
import 'game_state.dart';
import 'mode_menu_screen.dart';
import 'settings_screen.dart';

class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key});

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/background.png', fit: BoxFit.fill),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'クイックタップ',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4E342E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '文字をタップして語句を完成させよう！',
                      style: TextStyle(fontSize: 14, color: Color(0xFF795548)),
                    ),
                    const SizedBox(height: 48),
                    const Text(
                      'トップメニュー',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4E342E),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _MenuButton(
                      label: '四字熟語',
                      filled: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const ModeMenuScreen(mode: GameMode.yoji),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _MenuButton(
                      label: 'ことわざ',
                      filled: false,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const ModeMenuScreen(mode: GameMode.kotowaza),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: IconButton(
                  iconSize: 30,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withAlpha(220),
                    foregroundColor: const Color(0xFF6D4C41),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SettingsScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.settings),
                  tooltip: '設定',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _MenuButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: filled ? const Color(0xFF6D4C41) : Colors.white,
          border: Border.all(color: const Color(0xFF6D4C41), width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: filled ? Colors.white : const Color(0xFF6D4C41),
            ),
          ),
        ),
      ),
    );
  }
}
