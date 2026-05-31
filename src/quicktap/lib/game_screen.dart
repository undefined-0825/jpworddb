import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'app_header.dart';
import 'app_settings.dart';
import 'db_helper.dart';
import 'game_state.dart';
import 'purchase_service.dart';
import 'result_screen.dart';

class GameScreen extends StatefulWidget {
  final GameMode mode;
  final PlayMode playMode;
  final List<int>? levelFilters;

  const GameScreen({
    super.key,
    required this.mode,
    required this.playMode,
    this.levelFilters,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameState _state;
  final _settings = AppSettings.instance;
  Timer? _timer;
  bool _loading = true;
  bool _isLevelCleared = false;
  bool? _answerResult; // true=◁E false=ÁE null=非表示
  String? _revealWord; // 正解/スキチE�E時に表示する語句
  String? _revealReading; // 正解/スキチE�E時に表示する読み

  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  int get _perQuestionLimitSeconds {
    if (widget.mode == GameMode.yoji) {
      return 30;
    }
    return 60;
  }

  void _onFontSizeChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _initBannerAd() {
    if (PurchaseService.instance.adsDisabledNotifier.value) return;

    _isBannerAdLoaded = false;
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-4954876478259153/4155796641',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) {
            setState(() => _isBannerAdLoaded = true);
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerAd = null;
        },
      ),
    );
    _bannerAd!.load();
  }

  void _onAdsDisabledChanged() {
    if (!mounted) return;

    if (PurchaseService.instance.adsDisabledNotifier.value) {
      _bannerAd?.dispose();
      _bannerAd = null;
      if (_isBannerAdLoaded) {
        setState(() => _isBannerAdLoaded = false);
      }
      return;
    }

    if (_bannerAd == null) {
      _initBannerAd();
    }
  }

  @override
  void initState() {
    super.initState();
    _state = GameState(mode: widget.mode);
    _settings.fontSizeOption.addListener(_onFontSizeChanged);
    PurchaseService.instance.adsDisabledNotifier.addListener(
      _onAdsDisabledChanged,
    );
    _initBannerAd();
    _loadAndStart();
  }

  Future<void> _loadAndStart() async {
    final rows = widget.mode == GameMode.yoji
        ? await DbHelper.fetchAllYoji(levelFilters: widget.levelFilters)
        : await DbHelper.fetchAllKotowaza(levelFilters: widget.levelFilters);

    if (!mounted) return;
    setState(() {
      _state.loadPool(rows);
      final started = _state.nextQuestion();
      _state.remainingTime = _perQuestionLimitSeconds;
      _isLevelCleared = false;
      _loading = false;
      _state.isRunning = started;
    });
    if (widget.playMode == PlayMode.timeattack && _state.isRunning) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _state.remainingTime = _perQuestionLimitSeconds;
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

  void _moveToNextQuestion() {
    final hasNext = _state.nextQuestion();
    if (!hasNext) {
      _state.isRunning = false;
      _timer?.cancel();
      _isLevelCleared = _state.score == _state.totalQuestions;
      _goToResult();
      return;
    }

    if (widget.playMode == PlayMode.timeattack) {
      _startTimer();
    }
  }

  void _goToResult() {
    final initialTime = widget.playMode == PlayMode.relax
        ? null
        : _perQuestionLimitSeconds;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          score: _state.score,
          totalAsked: _state.totalAsked,
          totalQuestions: _state.totalQuestions,
          isLevelCleared: _isLevelCleared,
          mode: widget.mode,
          playMode: widget.playMode,
          initialTime: initialTime,
          levelFilters: widget.levelFilters,
        ),
      ),
    );
  }

  void _onTileTap(CharTile tile) {
    if (!_state.isRunning || _answerResult != null || _revealWord != null) {
      return;
    }
    setState(() {
      _state.tapTile(tile);

      // 最後かめE斁E��目の入力時は、残り1斁E��を自動で配置する、E
      final tileCount = _state.currentQuestion!.tileCount;
      if (tileCount >= 2 && _state.selectedTiles.length == tileCount - 1) {
        CharTile? remaining;
        for (final t in _state.shuffledTiles) {
          if (!t.selected) {
            remaining = t;
            break;
          }
        }
        if (remaining != null) {
          _state.tapTile(remaining);
        }
      }
    });
    if (_state.selectedTiles.length == _state.currentQuestion!.tileCount) {
      if (_state.checkAnswer()) {
        _state.score++;
        if (_state.score == _state.totalQuestions) {
          _isLevelCleared = true;
        }
        setState(() {
          _answerResult = true;
          _revealWord = _state.currentQuestion!.word;
          _revealReading = _state.currentQuestion!.reading;
        });
      } else {
        setState(() => _answerResult = false);
      }
    }
  }

  void _onSkip() {
    if (!_state.isRunning || _answerResult != null || _revealWord != null) {
      return;
    }
    final word = _state.currentQuestion!.word;
    final reading = _state.currentQuestion!.reading;
    setState(() {
      _state.resetInput();
      _revealWord = word;
      _revealReading = reading;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _settings.fontSizeOption.removeListener(_onFontSizeChanged);
    PurchaseService.instance.adsDisabledNotifier.removeListener(
      _onAdsDisabledChanged,
    );
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: const KotonohaHeader(),
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset('assets/background.png', fit: BoxFit.cover),
            ),
            const Center(child: CircularProgressIndicator()),
          ],
        ),
      );
    }

    final q = _state.currentQuestion!;
    final font = _settings.fontSizeOption.value;
    final timeColor = _state.remainingTime <= 10
        ? Colors.red
        : const Color(0xFF4E342E);

    return Scaffold(
      appBar: const KotonohaHeader(),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/background.png', fit: BoxFit.cover),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ヘッダー�E�時間�Eスコア�E�E
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (widget.playMode == PlayMode.timeattack)
                        _InfoChip(
                          label: '残り時間',
                          value: '${_state.remainingTime}秒',
                          valueColor: timeColor,
                        )
                      else
                        _InfoChip(
                          label: 'モード',
                          value: 'リラックス',
                          valueColor: const Color(0xFF4E342E),
                        ),
                      _InfoChip(
                        label: 'スコア',
                        value: '${_state.score}',
                        valueColor: const Color(0xFF4E342E),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 意味�E�上部�E�E
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBCAAA4)),
                    ),
                    child: Text(
                      q.meaning.isNotEmpty ? q.meaning : 'ヒントなし！',
                      style: TextStyle(
                        fontSize: font.meaningTextSize,
                        color: const Color(0xFF5D4037),
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
                          .map(
                            (t) => _CharBubble(
                              char: t.char,
                              filled: true,
                              size: font.bubbleBoxSize,
                              charSize: font.bubbleCharSize,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // シャチE��ルボタン群
                  Expanded(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: _state.shuffledTiles.map((tile) {
                        return _TileButton(
                          tile: tile,
                          size: font.tileBoxSize,
                          charSize: font.tileCharSize,
                          onTap: () => _onTileTap(tile),
                        );
                      }).toList(),
                    ),
                  ),

                  // リセット・スキップ・終了ボタン
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _answerResult != null
                            ? null
                            : () => setState(() => _state.resetInput()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEFEBE9),
                          foregroundColor: const Color(0xFF795548),
                          disabledBackgroundColor: const Color(0xFFE0E0E0),
                          disabledForegroundColor: const Color(0xFFBDBDBD),
                          elevation: 0,
                          side: const BorderSide(color: Color(0xFFBCAAA4)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        icon: const Icon(Icons.refresh),
                        label: const Text('リセット'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _answerResult != null ? null : _onSkip,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEEEEEE),
                          foregroundColor: const Color(0xFF616161),
                          disabledBackgroundColor: const Color(0xFFE0E0E0),
                          disabledForegroundColor: const Color(0xFFBDBDBD),
                          elevation: 0,
                          side: const BorderSide(color: Color(0xFFBDBDBD)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        icon: const Icon(Icons.skip_next),
                        label: const Text('スキップ'),
                      ),
                      if (widget.playMode == PlayMode.relax)
                        OutlinedButton.icon(
                          onPressed: () {
                            _state.isRunning = false;
                            _goToResult();
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFD32F2F),
                            side: const BorderSide(color: Color(0xFFD32F2F)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: const Text('終了'),
                        ),
                    ],
                  ),
                  if (_isBannerAdLoaded && _bannerAd != null)
                    SizedBox(height: 60, child: AdWidget(ad: _bannerAd!)),
                ],
              ),
            ),
          ),
          // ◁EÁEオーバ�Eレイ�E�正解・不正解フィードバチE���E�E
          if (_answerResult != null)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (_answerResult!) {
                      _answerResult = null;
                      _revealWord = null;
                      _revealReading = null;
                      _moveToNextQuestion();
                    } else {
                      _state.resetInput();
                      _answerResult = null;
                    }
                  });
                },
                child: Container(
                  color: Colors.black26,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          _answerResult!
                              ? 'assets/character_correct.png'
                              : 'assets/character_wrong.png',
                          width: 160,
                          fit: BoxFit.contain,
                        ),
                        if (_answerResult! && _revealWord != null)
                          ..._wordRevealWidgets(),
                        if (_answerResult!)
                          const Padding(
                            padding: EdgeInsets.only(top: 20),
                            child: Text(
                              'タップして次へ',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        if (!_answerResult!)
                          const Padding(
                            padding: EdgeInsets.only(top: 20),
                            child: Text(
                              'タップして再挑戦',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // スキチE�E時�E答え表示オーバ�Eレイ
          if (_revealWord != null && _answerResult == null)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _revealWord = null;
                    _revealReading = null;
                    _moveToNextQuestion();
                  });
                },
                child: Container(
                  color: Colors.black26,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ..._wordRevealWidgets(),
                        const Padding(
                          padding: EdgeInsets.only(top: 20),
                          child: Text(
                            'タップして次へ',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _wordRevealWidgets() {
    return [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(230),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _revealWord ?? '',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            if (_revealReading != null && _revealReading!.isNotEmpty)
              Text(
                '（${_revealReading!}）',
                style: const TextStyle(fontSize: 18, color: Colors.black54),
              ),
          ],
        ),
      ),
    ];
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
  final double size;
  final double charSize;
  final VoidCallback onTap;

  const _TileButton({
    required this.tile,
    required this.size,
    required this.charSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dynamicWidth = (tile.char.length * charSize) + 24;
    final tileWidth = dynamicWidth > size ? dynamicWidth : size;
    return GestureDetector(
      onTap: tile.selected ? null : onTap,
      child: AnimatedOpacity(
        opacity: tile.selected ? 0.3 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: tileWidth,
          height: size,
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
                fontSize: charSize,
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
  final double size;
  final double charSize;

  const _CharBubble({
    required this.char,
    required this.filled,
    required this.size,
    required this.charSize,
  });

  @override
  Widget build(BuildContext context) {
    final dynamicWidth = (char.length * charSize) + 24;
    final bubbleWidth = dynamicWidth > size ? dynamicWidth : size;
    return Container(
      width: bubbleWidth,
      height: size,
      decoration: BoxDecoration(
        color: filled ? const Color(0xFF8D6E63) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: filled ? null : Border.all(color: const Color(0xFF6D4C41)),
      ),
      child: Center(
        child: Text(
          char,
          style: TextStyle(
            fontSize: charSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
