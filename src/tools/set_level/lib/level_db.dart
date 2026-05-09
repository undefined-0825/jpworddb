import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

enum WordMode { yoji, kotowaza }

class WordRecord {
  final int id;
  final String word;
  final String reading;
  final String meaning;

  const WordRecord({
    required this.id,
    required this.word,
    required this.reading,
    required this.meaning,
  });
}

class LevelSummary {
  final int assignedCount;
  final int totalCount;

  const LevelSummary({required this.assignedCount, required this.totalCount});

  int get remainingCount => totalCount - assignedCount;
}

class LevelDb {
  static Database? _db;
  static const _dbFileName = 'set_level_jpword.db';

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<String> get databasePath async {
    final dbDir = await getDatabasesPath();
    return join(dbDir, _dbFileName);
  }

  Future<Database> _initDb() async {
    final dbPath = await databasePath;

    // Replace stale DB if kotowaza.level column is missing
    if (await File(dbPath).exists()) {
      final existing = await openDatabase(dbPath, readOnly: true);
      final cols = await existing.rawQuery('PRAGMA table_info(kotowaza)');
      await existing.close();
      if (!cols.any((c) => c['name'] == 'level')) {
        await deleteDatabase(dbPath);
      }
    }

    if (!await File(dbPath).exists()) {
      final data = await rootBundle.load('assets/jpword.db');
      final bytes = data.buffer.asUint8List();
      await File(dbPath).writeAsBytes(bytes, flush: true);
    }
    return openDatabase(dbPath);
  }

  String _tableName(WordMode mode) =>
      mode == WordMode.yoji ? 'yojijukugo' : 'kotowaza';

  Future<String> exportDatabase() async {
    final sourcePath = await databasePath;
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw Exception('エクスポート元のDBが見つかりません。');
    }

    final externalDir = await getExternalStorageDirectory();
    final baseDir = externalDir ?? await getApplicationDocumentsDirectory();
    final exportDir = Directory(join(baseDir.path, 'exports'));
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final exportedPath = join(exportDir.path, 'jpword_export.db');
    await sourceFile.copy(exportedPath);
    return exportedPath;
  }

  Future<WordRecord?> fetchNextUnassigned(WordMode mode) async {
    final db = await database;
    final table = _tableName(mode);
    final rows = await db.rawQuery(
      'SELECT id, word, reading, meaning FROM $table '
      'WHERE level IS NULL ORDER BY id LIMIT 1',
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return WordRecord(
      id: row['id'] as int,
      word: row['word'] as String,
      reading: row['reading'] as String? ?? '',
      meaning: row['meaning'] as String? ?? '',
    );
  }

  Future<LevelSummary> fetchSummary(WordMode mode) async {
    final db = await database;
    final table = _tableName(mode);
    final row = await db.rawQuery(
      'SELECT '
      'SUM(CASE WHEN level IS NOT NULL THEN 1 ELSE 0 END) AS assigned_count, '
      'COUNT(*) AS total_count '
      'FROM $table',
    );
    final summary = row.first;
    return LevelSummary(
      assignedCount: summary['assigned_count'] as int? ?? 0,
      totalCount: summary['total_count'] as int? ?? 0,
    );
  }

  Future<void> updateLevel(WordMode mode, int id, int level) async {
    final db = await database;
    await db.update(
      _tableName(mode),
      {'level': level},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
