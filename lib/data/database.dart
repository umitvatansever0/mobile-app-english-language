import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/word.dart';
import '../models/word_progress.dart';

/// Kelime ilerlemesi ve kullanıcının kendi kelimeleri için yerel SQLite deposu.
class AppDatabase {
  AppDatabase._(this._db);
  final Database _db;

  static Future<AppDatabase> open() async {
    final dir = await getDatabasesPath();
    final db = await openDatabase(
      p.join(dir, 'kartlar.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE progress(
            word_id TEXT PRIMARY KEY,
            ease REAL NOT NULL,
            interval_days INTEGER NOT NULL,
            reps INTEGER NOT NULL,
            due INTEGER,
            last_reviewed INTEGER,
            seen INTEGER NOT NULL,
            correct INTEGER NOT NULL,
            in_mistakes INTEGER NOT NULL
          )''');
        await db.execute('CREATE TABLE custom_words(id TEXT PRIMARY KEY, json TEXT NOT NULL, created INTEGER NOT NULL)');
      },
    );
    return AppDatabase._(db);
  }

  Future<Map<String, WordProgress>> loadProgress() async {
    final rows = await _db.query('progress');
    return {for (final r in rows) r['word_id'] as String: WordProgress.fromMap(r)};
  }

  Future<void> saveProgress(WordProgress p) =>
      _db.insert('progress', p.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  Future<List<Word>> loadCustomWords() async {
    final rows = await _db.query('custom_words', orderBy: 'created DESC');
    return [for (final r in rows) Word.fromJson(jsonDecode(r['json'] as String) as Map<String, dynamic>)];
  }

  Future<void> saveCustomWord(Word w) => _db.insert(
        'custom_words',
        {'id': w.id, 'json': jsonEncode(w.toJson()), 'created': DateTime.now().millisecondsSinceEpoch},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<void> deleteCustomWord(String id) async {
    await _db.delete('custom_words', where: 'id = ?', whereArgs: [id]);
    await _db.delete('progress', where: 'word_id = ?', whereArgs: [id]);
  }

  Future<void> resetAll() async {
    await _db.delete('progress');
  }
}
