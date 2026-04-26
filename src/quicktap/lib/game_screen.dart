import 'dart:async';
import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'game_state.dart';
import 'result_screen.dart';

class GameScreen extends StatefulWidget {
  final GameMode mode;
  const GameScreen({super.key, required this.mode});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameState _state;
  Timer? _timer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _state = GameState(mode: widget.mode);
    _loadAndStart();
  }

  Future<void> _loadAndStart() async {
    final rows = widget.mode == GameMode.yoji
        ? await DbHelper.fetchAllYoji()
        : await DbHelper.fetchAllKotowaza();

    if (!mounted) return;
    setState(() {
      _state.loadPool(rows);
      _state.nextQuestion();
      _loading = false;
      _state.isRunning = true;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _state.remainingTime--;
        if (_state.remainingTime <= 0) {
          _timer?.cancel();
          _state.isRunning = false;
          _goToResult();
        }
      });
    });
  }

  void _goToResult() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ResultScreen(score: _state.score, totalAsked: _state.totalAsked),
      ),
    );
  }

  void _onTileTap(CharTile tile) {
    if (!_state.isRunning) return;
    setState(() {
      _state.tapTile(tile);
      if (_state.selectedTiles.length == _state.currentQuestion!.word.length) {
        if (_state.checkAnswer()) {
          _state.score++;
          _state.nextQuestion();
        } else {
          // 不正解：入力リセット
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) setState(() => _state.resetInput());
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFAF3E0),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final q = _state.currentQuestion!;
    final timeColor = _state.remainingTime <= 10
        ? Colors.red
        : const Color(0xFF4E342E);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF3E0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // ヘッダー（時間・スコア）
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _InfoChip(
                    label: '残り時間',
                    value: '${_state.remainingTime}秒',
                    valueColor: timeColor,
                  ),
                  _InfoChip(
                    label: 'スコア',
                    value: '${_state.score}',
                    valueColor: const Color(0xFF4E342E),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ヒント
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBCAAA4)),
                ),
                child: Text(
                  q.meaning.isNotEmpty ? q.meaning : '（ヒントなし）',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF5D4037),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 入力エリア
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 8,
                ),
                constraints: const BoxConstraints(minHeight: 56),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFEBE9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF6D4C41),
                    width: 1.5,
                  ),
                ),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _state.selectedTiles
                      .map((t) => _CharBubble(char: t.char, filled: true))
                      .toList(),
                ),
              ),
              const SizedBox(height: 24),

              // シャッフルボタン群
              Expanded(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: _state.shuffledTiles.map((tile) {
                    return _TileButton(
                      tile: tile,
                      onTap: () => _onTileTap(tile),
                    );
                  }).toList(),
                ),
              ),

              // リセットボタン
              TextButton.icon(
                onPressed: () => setState(() => _state.resetInput()),
                icon: const Icon(Icons.refresh, color: Color(0xFF795548)),
                label: const Text(
                  'リセット',
                  style: TextStyle(color: Color(0xFF795548), fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _InfoChip({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF795548)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _TileButton extends StatelessWidget {
  final CharTile tile;
  final VoidCallback onTap;

  const _TileButton({required this.tile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: tile.selected ? null : onTap,
      child: AnimatedOpacity(
        opacity: tile.selected ? 0.3 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: tile.selected ? Colors.grey[300] : const Color(0xFF6D4C41),
            borderRadius: BorderRadius.circular(10),
            boxShadow: tile.selected
                ? []
                : [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Center(
            child: Text(
              tile.char,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: tile.selected ? Colors.grey : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CharBubble extends StatelessWidget {
  final String char;
  final bool filled;

  const _CharBubble({required this.char, required this.filled});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: filled ? const Color(0xFF8D6E63) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: filled ? null : Border.all(color: const Color(0xFF6D4C41)),
      ),
      child: Center(
        child: Text(
          char,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
