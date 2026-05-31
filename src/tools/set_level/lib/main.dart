import 'package:flutter/material.dart';

import 'level_db.dart';

void main() {
  runApp(const SetLevelApp());
}

class SetLevelApp extends StatelessWidget {
  const SetLevelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'レベル設定',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6D4C41)),
        useMaterial3: true,
      ),
      home: const TopScreen(),
    );
  }
}

// ─── トップ画面 ──────────────────────────────────────────────

class TopScreen extends StatelessWidget {
  const TopScreen({super.key});

  void _navigate(BuildContext context, WordMode mode) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LevelAssignScreen(mode: mode)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF6D4C41),
        foregroundColor: Colors.white,
        title: const Text(
          'レベル設定',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '対象を選択してください',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4E342E),
                ),
              ),
              const SizedBox(height: 40),
              _TopButton(
                label: '四字熟語',
                onTap: () => _navigate(context, WordMode.yoji),
              ),
              const SizedBox(height: 20),
              _TopButton(
                label: 'ことわざ',
                onTap: () => _navigate(context, WordMode.kotowaza),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TopButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF6D4C41),
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

// ─── レベル設定画面 ───────────────────────────────────────────

class LevelAssignScreen extends StatefulWidget {
  final WordMode mode;

  const LevelAssignScreen({super.key, required this.mode});

  @override
  State<LevelAssignScreen> createState() => _LevelAssignScreenState();
}

class _LevelAssignScreenState extends State<LevelAssignScreen> {
  final LevelDb _db = LevelDb();

  WordRecord? _current;
  int _remaining = 0;
  int _assigned = 0;
  int _total = 0;
  bool _loading = true;
  bool _saving = false;
  bool _exporting = false;
  String? _error;
  String? _lastExportPath;

  String get _modeLabel => widget.mode == WordMode.yoji ? '四字熟語' : 'ことわざ';

  @override
  void initState() {
    super.initState();
    _loadNext();
  }

  Future<void> _loadNext() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final current = await _db.fetchNextUnassigned(widget.mode);
      final summary = await _db.fetchSummary(widget.mode);
      if (!mounted) return;
      setState(() {
        _current = current;
        _remaining = summary.remainingCount;
        _assigned = summary.assignedCount;
        _total = summary.totalCount;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _selectLevel(int level) async {
    final current = _current;
    if (current == null || _saving) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _db.updateLevel(widget.mode, current.id, level);
      await _loadNext();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _saving = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _saving = false;
    });
  }

  Future<void> _exportDb() async {
    if (_exporting) return;
    setState(() {
      _exporting = true;
      _error = null;
    });

    try {
      final exportPath = await _db.exportDatabase();
      if (!mounted) return;
      setState(() {
        _lastExportPath = exportPath;
        _exporting = false;
      });
      _showExportResult(exportPath);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _exporting = false;
      });
    }
  }

  void _showExportResult(String exportPath) {
    showDialog<void>(
      context: context,
      builder: (context) {
        final adbPath = exportPath.replaceAll('\\', '/');
        return AlertDialog(
          title: const Text('エクスポート完了'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('端末内DBを書き出しました。'),
              const SizedBox(height: 12),
              SelectableText(exportPath, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              SelectableText(
                'adb pull "$adbPath" data/jpword.db',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$_modeLabel レベル設定'),
        backgroundColor: const Color(0xFF6D4C41),
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: _loading || _saving || _exporting ? null : _exportDb,
            icon: _exporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file, color: Colors.white),
            label: const Text('書き出し', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(padding: const EdgeInsets.all(24), child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFD32F2F)),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _loadNext, child: const Text('再読み込み')),
        ],
      );
    }

    if (_current == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '未設定のレコードはありません。',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text('設定済み件数: $_assigned / $_total'),
            const SizedBox(height: 8),
            Text('残り件数: $_remaining'),
          ],
        ),
      );
    }

    final current = _current!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '残り件数: $_remaining',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5D4037),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '設定済み件数: $_assigned / $_total',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF795548),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'ID: ${current.id}',
          style: const TextStyle(fontSize: 13, color: Color(0xFF795548)),
        ),
        if (_lastExportPath != null) ...[
          const SizedBox(height: 8),
          Text(
            '直近の書き出し先: $_lastExportPath',
            style: const TextStyle(fontSize: 12, color: Color(0xFF795548)),
          ),
        ],
        const SizedBox(height: 24),
        Expanded(
          child: Card(
            color: const Color(0xFFEFEBE9),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      current.word,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3E2723),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      current.reading,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        color: Color(0xFF6D4C41),
                      ),
                    ),
                    if (current.meaning.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 180),
                          child: Scrollbar(
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              child: Text(
                                current.meaning,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF4E342E),
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'レベルを選択',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _LevelButton(
                level: 1,
                onTap: _saving ? null : () => _selectLevel(1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _LevelButton(
                level: 2,
                onTap: _saving ? null : () => _selectLevel(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _LevelButton(
                level: 3,
                onTap: _saving ? null : () => _selectLevel(3),
              ),
            ),
          ],
        ),
        if (_saving) ...[
          const SizedBox(height: 12),
          const Center(child: CircularProgressIndicator()),
        ],
        if (_exporting) ...[
          const SizedBox(height: 12),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }
}

class _LevelButton extends StatelessWidget {
  final int level;
  final VoidCallback? onTap;

  const _LevelButton({required this.level, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF6D4C41),
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        child: Text('$level'),
      ),
    );
  }
}
