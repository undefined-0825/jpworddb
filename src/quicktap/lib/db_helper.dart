import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'game_state.dart';

class DbHelper {
  static Database? _db;

  static String _tableName(GameMode mode) {
    return mode == GameMode.yoji ? 'yojijukugo' : 'kotowaza';
  }

  static String _answeredColumn(PlayMode playMode) {
    return playMode == PlayMode.timeattack
        ? 'answered_timeattack'
        : 'answered_relax';
  }

  static Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbDir = await getDatabasesPath();
    final dbPath = join(dbDir, 'jpword.db');

    // Replace stale local DB if required columns are missing.
    if (await File(dbPath).exists()) {
      final existingDb = await openDatabase(dbPath, readOnly: true);
      bool needsReplace = false;
      final yojiCols = await existingDb.rawQuery(
        'PRAGMA table_info(yojijukugo)',
      );
      if (!yojiCols.any((c) => c['name'] == 'level')) {
        needsReplace = true;
      }
      final kotowazaCols = await existingDb.rawQuery(
        'PRAGMA table_info(kotowaza)',
      );
      if (!kotowazaCols.any((c) => c['name'] == 'level')) {
        needsReplace = true;
      }
      if (!kotowazaCols.any((c) => c['name'] == 'bunsetsu')) {
        needsReplace = true;
      }
      if (!needsReplace) {
        final result = await existingDb.rawQuery(
          'SELECT COUNT(*) as cnt FROM yojijukugo WHERE level IS NOT NULL',
        );
        needsReplace = (result.first['cnt'] as int) == 0;
      }
      await existingDb.close();
      if (needsReplace) {
        await deleteDatabase(dbPath);
      }
    }

    if (!await File(dbPath).exists()) {
      final data = await rootBundle.load('assets/jpword.db');
      final bytes = data.buffer.asUint8List();
      await File(dbPath).writeAsBytes(bytes, flush: true);
    }
    final db = await openDatabase(dbPath);
    await _ensureProgressColumns(db);
    return db;
  }

  static Future<void> _ensureProgressColumns(Database db) async {
    await _ensureProgressColumnsForTable(db, 'yojijukugo');
    await _ensureProgressColumnsForTable(db, 'kotowaza');
  }

  static Future<void> _ensureProgressColumnsForTable(
    Database db,
    String table,
  ) async {
    final cols = await db.rawQuery('PRAGMA table_info($table)');
    final colNames = cols
        .map((c) => c['name'])
        .whereType<String>()
        .toSet();

    final hasLegacyAnswered = colNames.contains('answered');
    final hasTimeattack = colNames.contains('answered_timeattack');
    final hasRelax = colNames.contains('answered_relax');

    if (!hasTimeattack) {
      await db.execute(
        'ALTER TABLE $table ADD COLUMN answered_timeattack INTEGER NOT NULL DEFAULT 0',
      );
      if (hasLegacyAnswered) {
        await db.execute(
          'UPDATE $table SET answered_timeattack = IFNULL(answered, 0)',
        );
      }
    }

    if (!hasRelax) {
      await db.execute(
        'ALTER TABLE $table ADD COLUMN answered_relax INTEGER NOT NULL DEFAULT 0',
      );
      if (hasLegacyAnswered) {
        await db.execute(
          'UPDATE $table SET answered_relax = IFNULL(answered, 0)',
        );
      }
    }
  }

  static Future<List<Map<String, dynamic>>> fetchAllYoji({
    required PlayMode playMode,
    List<int>? levelFilters,
    bool onlyUnanswered = false,
  }) async {
    final db = await database;
    final answeredColumn = _answeredColumn(playMode);
    final whereConditions = <String>[
      "y.word IS NOT NULL",
      "y.word != ''",
      'length(y.word) >= 2',
    ];
    if (onlyUnanswered) {
      whereConditions.add('IFNULL(y.$answeredColumn, 0) = 0');
    }
    final whereClause = whereConditions.join(' AND ');
    if (levelFilters == null || levelFilters.isEmpty) {
      return db.rawQuery(
        "SELECT id, word, reading, meaning, level FROM yojijukugo y "
        "WHERE $whereClause",
      );
    }

    final placeholders = List.filled(levelFilters.length, '?').join(', ');
    return db.rawQuery(
      "SELECT y.id, y.word, y.reading, y.meaning, y.level "
      "FROM yojijukugo y "
      "WHERE $whereClause AND y.level IN ($placeholders)",
      levelFilters,
    );
  }

  static Future<List<Map<String, dynamic>>> fetchAllKotowaza({
    required PlayMode playMode,
    List<int>? levelFilters,
    bool onlyUnanswered = false,
  }) async {
    final db = await database;
    final answeredColumn = _answeredColumn(playMode);
    final whereConditions = <String>[
      "k.word IS NOT NULL",
      "k.word != ''",
      'length(k.word) >= 2',
    ];
    if (onlyUnanswered) {
      whereConditions.add('IFNULL(k.$answeredColumn, 0) = 0');
    }
    final whereClause = whereConditions.join(' AND ');
    if (levelFilters == null || levelFilters.isEmpty) {
      return db.rawQuery(
        'SELECT id, word, reading, meaning, bunsetsu, level FROM kotowaza k '
        'WHERE $whereClause',
      );
    }
    final placeholders = List.filled(levelFilters.length, '?').join(', ');
    return db.rawQuery(
      'SELECT k.id, k.word, k.reading, k.meaning, k.bunsetsu, k.level '
      'FROM kotowaza k '
      'WHERE $whereClause AND k.level IN ($placeholders)',
      levelFilters,
    );
  }

  static Future<void> markAnswered({
    required GameMode mode,
    required PlayMode playMode,
    required int id,
  }) async {
    final db = await database;
    final answeredColumn = _answeredColumn(playMode);
    await db.update(
      _tableName(mode),
      {answeredColumn: 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> resetAnswered({
    required GameMode mode,
    required PlayMode playMode,
    List<int>? levelFilters,
  }) async {
    final db = await database;
    final answeredColumn = _answeredColumn(playMode);
    if (levelFilters == null || levelFilters.isEmpty) {
      await db.update(_tableName(mode), {answeredColumn: 0});
      return;
    }

    final placeholders = List.filled(levelFilters.length, '?').join(', ');
    await db.rawUpdate(
      'UPDATE ${_tableName(mode)} SET $answeredColumn = 0 '
      'WHERE level IN ($placeholders)',
      levelFilters,
    );
  }
}
