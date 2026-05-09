import 'package:flutter/material.dart';

import 'game_screen.dart';
import 'game_state.dart';

class _DifficultyOption {
  final int level;
  final String label;

  const _DifficultyOption({required this.level, required this.label});
}

const _difficultyOptions = [
  _DifficultyOption(level: 1, label: '難易度低'),
  _DifficultyOption(level: 2, label: '難易度中'),
  _DifficultyOption(level: 3, label: '難易度高'),
];

class ModeMenuScreen extends StatefulWidget {
  final GameMode mode;

  const ModeMenuScreen({super.key, required this.mode});

  @override
  State<ModeMenuScreen> createState() => _ModeMenuScreenState();
}

class _ModeMenuScreenState extends State<ModeMenuScreen> {
  final Set<int> _selectedLevels = {1};  // Default to level 1 only

  bool get _isYoji => widget.mode == GameMode.yoji;

  void _startGame(PlayMode playMode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          mode: widget.mode,
          playMode: playMode,
          levelFilters: _selectedLevels.toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canStart = _selectedLevels.isNotEmpty;
    final title = _isYoji ? '四字熟語メニュー' : 'ことわざメニュー';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF6D4C41),
        foregroundColor: Colors.white,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/background.png', fit: BoxFit.fill),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  const SizedBox(height: 8),
                  Text(
                    'チェックした難易度の問題だけを出題します。',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF795548)),
                  ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _difficultyOptions.map((option) {
                        final selected = _selectedLevels.contains(option.level);
                        return FilterChip(
                          label: Text(option.label),
                          selected: selected,
                          selectedColor: const Color(0xFFD7CCC8),
                          backgroundColor: Colors.white.withAlpha(225),
                          checkmarkColor: const Color(0xFF4E342E),
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4E342E),
                          ),
                          onSelected: (checked) {
                            setState(() {
                              if (checked) {
                                _selectedLevels.add(option.level);
                              } else {
                                _selectedLevels.remove(option.level);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  if (_selectedLevels.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        '少なくとも1つの難易度を選択してください。',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFFD32F2F),
                        ),
                      ),
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
