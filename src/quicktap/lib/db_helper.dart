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
    final dbPath = join(dbDir, 'jpword_mini.db');

    if (!await File(dbPath).exists()) {
      final data = await rootBundle.load('assets/jpword_mini.db');
      final bytes = data.buffer.asUint8List();
      await File(dbPath).writeAsBytes(bytes, flush: true);
    }
    return openDatabase(dbPath, readOnly: true);
  }

  static Future<List<Map<String, dynamic>>> fetchAllYoji() async {
    final db = await database;
    return db.rawQuery(
      "SELECT id, word, meaning FROM yojijukugo_mini "
      "WHERE word IS NOT NULL AND word != '' AND length(word) >= 2",
    );
  }

  static Future<List<Map<String, dynamic>>> fetchAllKotowaza() async {
    final db = await database;
    return db.rawQuery(
      "SELECT id, word, meaning FROM kotowaza_mini "
      "WHERE word IS NOT NULL AND word != '' AND length(word) >= 2",
    );
  }
}
