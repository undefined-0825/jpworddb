import 'package:flutter/material.dart';

import 'app_header.dart';
import 'game_screen.dart';
import 'game_state.dart';

class _DifficultyOption {
  final int level;
  final String label;

  const _DifficultyOption({required this.level, required this.label});
}

const _difficultyOptions = [
  _DifficultyOption(level: 1, label: '簡単'),
  _DifficultyOption(level: 2, label: '普通'),
  _DifficultyOption(level: 3, label: '難しい'),
  _DifficultyOption(level: 4, label: '超高'),
];

enum _StartOption { fresh, resume }

class ModeMenuScreen extends StatefulWidget {
  final GameMode mode;

  const ModeMenuScreen({super.key, required this.mode});

  @override
  State<ModeMenuScreen> createState() => _ModeMenuScreenState();
}

class _ModeMenuScreenState extends State<ModeMenuScreen> {
  int _selectedLevel = 1;
  _StartOption _startOption = _StartOption.fresh;

  void _startGame(PlayMode playMode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          mode: widget.mode,
          playMode: playMode,
          levelFilters: [_selectedLevel],
          resumeProgress: _startOption == _StartOption.resume,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const canStart = true;

    return Scaffold(
      appBar: const KotonohaHeader(),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/background.png', fit: BoxFit.cover),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.only(
              top: 16,
              left: 24,
              right: 24,
              bottom: 24,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Image.asset(
                      'assets/mode_select.png',
                      width: 300,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'プレイモード',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4E342E),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ModeActionButton(
                    label: 'タイムアタック',
                    filled: true,
                    onTap: canStart
                        ? () => _startGame(PlayMode.timeattack)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _ModeActionButton(
                    label: 'リラックス',
                    filled: false,
                    onTap: canStart ? () => _startGame(PlayMode.relax) : null,
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    '難易度',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4E342E),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _difficultyOptions.map((option) {
                      final selected = _selectedLevel == option.level;
                      return ChoiceChip(
                        label: Text(option.label),
                        selected: selected,
                        selectedColor: const Color(0xFFD7CCC8),
                        backgroundColor: Colors.white.withAlpha(225),
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4E342E),
                        ),
                        onSelected: (checked) {
                          if (!checked) return;
                          setState(() {
                            _selectedLevel = option.level;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    '開始方法',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4E342E),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ChoiceChip(
                        label: const Text('最初から'),
                        selected: _startOption == _StartOption.fresh,
                        selectedColor: const Color(0xFFD7CCC8),
                        backgroundColor: Colors.white.withAlpha(225),
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4E342E),
                        ),
                        onSelected: (_) {
                          setState(() => _startOption = _StartOption.fresh);
                        },
                      ),
                      ChoiceChip(
                        label: const Text('つづきから'),
                        selected: _startOption == _StartOption.resume,
                        selectedColor: const Color(0xFFD7CCC8),
                        backgroundColor: Colors.white.withAlpha(225),
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4E342E),
                        ),
                        onSelected: (_) {
                          setState(() => _startOption = _StartOption.resume);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeActionButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  const _ModeActionButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: filled
              ? const Color(0xFF6D4C41)
              : const Color(0xFFBCAAA4),
          foregroundColor: filled ? Colors.white : const Color(0xFF4E342E),
          disabledBackgroundColor: const Color(0xFFD7CCC8),
          disabledForegroundColor: const Color(0xFF8D6E63),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        onPressed: onTap,
        child: Text(label),
      ),
    );
  }
}
