import 'dart:math';

enum GameMode { yoji, kotowaza }

enum PlayMode { timeattack, relax }

class Question {
  final int id;
  final String word;
  final String reading;
  final String meaning;
  late final List<_CharItem> _chars;

  Question({
    required this.id,
    required this.word,
    required this.reading,
    required this.meaning,
  }) {
    _chars = word
        .split('')
        .indexed
        .map((e) => _CharItem(index: e.$1, char: e.$2))
        .toList();
  }

  /// Fisher-Yates シャッフル（元と同順の場合は再シャッフル）
  List<CharTile> shuffled() {
    final rng = Random();
    List<_CharItem> result;
    int attempts = 0;
    do {
      result = [..._chars];
      for (int i = result.length - 1; i > 0; i--) {
        final j = rng.nextInt(i + 1);
        final tmp = result[i];
        result[i] = result[j];
        result[j] = tmp;
      }
      attempts++;
      // 全文字が同一の場合は無限ループ防止
    } while (_isSameOrder(result) && attempts < 10);
    return result.map((c) => CharTile(index: c.index, char: c.char)).toList();
  }

  bool _isSameOrder(List<_CharItem> list) {
    for (int i = 0; i < _chars.length; i++) {
      if (_chars[i].index != list[i].index) return false;
    }
    return true;
  }
}

/// 同一文字をインデックスで識別するクラス
class _CharItem {
  final int index;
  final String char;
  _CharItem({required this.index, required this.char});
}

/// ゲームで扱う文字タイル（シャッフル・選択状態を持つ）
class CharTile {
  final int index;
  final String char;
  bool selected;

  CharTile({required this.index, required this.char, this.selected = false});
}

class GameState {
  final GameMode mode;
  int score = 0;
  int totalAsked = 0;
  int remainingTime = 60;
  bool isRunning = false;

  List<Map<String, dynamic>> _pool = [];
  final Set<int> _usedIds = {};

  Question? currentQuestion;
  List<CharTile> shuffledTiles = [];
  List<CharTile> selectedTiles = [];

  GameState({required this.mode});

  void loadPool(List<Map<String, dynamic>> rows) {
    _pool = rows;
    _usedIds.clear();
  }

  bool get poolEmpty => _pool.isEmpty;
  int get totalQuestions => _pool.length;

  /// 次の問題をセット。使い切ったら false を返す。
  bool nextQuestion() {
    final candidates = _pool
        .where((r) => !_usedIds.contains(r['id'] as int))
        .toList();
    if (candidates.isEmpty) return false;

    final rng = Random();
    final row = candidates[rng.nextInt(candidates.length)];
    _usedIds.add(row['id'] as int);

    currentQuestion = Question(
      id: row['id'] as int,
      word: row['word'] as String,
      reading: row['reading'] as String? ?? '',
      meaning: row['meaning'] as String? ?? '',
    );

    shuffledTiles = currentQuestion!.shuffled();
    selectedTiles = [];
    totalAsked++;
    return true;
  }

  void tapTile(CharTile tile) {
    if (tile.selected) return;
    tile.selected = true;
    selectedTiles.add(tile);
  }

  void resetInput() {
    for (final t in selectedTiles) {
      t.selected = false;
    }
    selectedTiles = [];
  }

  bool checkAnswer() {
    final input = selectedTiles.map((t) => t.char).join();
    return input == currentQuestion?.word;
  }

  double get accuracy => totalAsked == 0 ? 0 : score / totalAsked;
}
