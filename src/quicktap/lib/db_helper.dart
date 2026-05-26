import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DbHelper {
  static Database? _db;

  static Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbDir = await getDatabasesPath();
    final dbPath = join(dbDir, 'jpword.db');

    // Replace stale local DB if level data is missing.
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
    return openDatabase(dbPath, readOnly: true);
  }

  static Future<List<Map<String, dynamic>>> fetchAllYoji({
    List<int>? levelFilters,
  }) async {
    final db = await database;
    const baseWhere =
        "y.word IS NOT NULL AND y.word != '' AND length(y.word) >= 2";
    if (levelFilters == null || levelFilters.isEmpty) {
      return db.rawQuery(
        "SELECT id, word, reading, meaning FROM yojijukugo y "
        "WHERE $baseWhere",
      );
    }

    final placeholders = List.filled(levelFilters.length, '?').join(', ');
    return db.rawQuery(
      "SELECT y.id, y.word, y.reading, y.meaning "
      "FROM yojijukugo y "
      "WHERE $baseWhere AND y.level IN ($placeholders)",
      levelFilters,
    );
  }

  static Future<List<Map<String, dynamic>>> fetchAllKotowaza({
    List<int>? levelFilters,
  }) async {
    final db = await database;
    const baseWhere =
        "k.word IS NOT NULL AND k.word != '' AND length(k.word) >= 2";
    if (levelFilters == null || levelFilters.isEmpty) {
      return db.rawQuery(
        'SELECT id, word, reading, meaning, bunsetsu FROM kotowaza k '
        'WHERE $baseWhere',
      );
    }
    final placeholders = List.filled(levelFilters.length, '?').join(', ');
    return db.rawQuery(
      'SELECT k.id, k.word, k.reading, k.meaning, k.bunsetsu '
      'FROM kotowaza k '
      'WHERE $baseWhere AND k.level IN ($placeholders)',
      levelFilters,
    );
  }
}
