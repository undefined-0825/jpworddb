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
      if (!yojiCols.any((c) => c['name'] == 'answered')) {
        needsReplace = true;
      }
      final kotowazaCols = await existingDb.rawQuery(
        'PRAGMA table_info(kotowaza)',
      );
      if (!kotowazaCols.any((c) => c['name'] == 'level')) {
        needsReplace = true;
      }
      if (!kotowazaCols.any((c) => c['name'] == 'answered')) {
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
    return openDatabase(dbPath);
  }

  static Future<List<Map<String, dynamic>>> fetchAllYoji({
    List<int>? levelFilters,
    bool onlyUnanswered = false,
  }) async {
    final db = await database;
    final whereConditions = <String>[
      "y.word IS NOT NULL",
      "y.word != ''",
      'length(y.word) >= 2',
    ];
    if (onlyUnanswered) {
      whereConditions.add('IFNULL(y.answered, 0) = 0');
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
    List<int>? levelFilters,
    bool onlyUnanswered = false,
  }) async {
    final db = await database;
    final whereConditions = <String>[
      "k.word IS NOT NULL",
      "k.word != ''",
      'length(k.word) >= 2',
    ];
    if (onlyUnanswered) {
      whereConditions.add('IFNULL(k.answered, 0) = 0');
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
    required int id,
  }) async {
    final db = await database;
    await db.update(
      _tableName(mode),
      {'answered': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> resetAnswered({
    required GameMode mode,
    List<int>? levelFilters,
  }) async {
    final db = await database;
    if (levelFilters == null || levelFilters.isEmpty) {
      await db.update(_tableName(mode), {'answered': 0});
      return;
    }

    final placeholders = List.filled(levelFilters.length, '?').join(', ');
    await db.rawUpdate(
      'UPDATE ${_tableName(mode)} SET answered = 0 '
      'WHERE level IN ($placeholders)',
      levelFilters,
    );
  }
}
