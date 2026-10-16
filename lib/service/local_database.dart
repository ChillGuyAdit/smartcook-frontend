import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// SQLite store for the offline copy of recipes and the fridge.
///
/// Small preferences, tokens and the offline operation queue stay in
/// SharedPreferences; the bulky, list-shaped data lives here.
class LocalDatabase {
  LocalDatabase._();

  static const _dbName = 'smartcook_cache.db';
  static const _dbVersion = 1;

  static const tRecipes = 'recipes';
  static const tRecipeLists = 'recipe_lists';
  static const tFridge = 'fridge_items';

  static Database? _db;
  static Future<Database>? _opening;

  @visibleForTesting
  static String? pathOverride;

  static Future<Database> get instance {
    final open = _db;
    if (open != null && open.isOpen) return Future.value(open);
    return _opening ??= _open().whenComplete(() => _opening = null);
  }

  static Future<Database> _open() async {
    final path = pathOverride ?? p.join(await getDatabasesPath(), _dbName);
    final db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE $tRecipes (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            json TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE $tRecipeLists (
            list_key TEXT NOT NULL,
            position INTEGER NOT NULL,
            recipe_id TEXT NOT NULL,
            PRIMARY KEY (list_key, position)
          )''');
        await db.execute('''
          CREATE TABLE $tFridge (
            id TEXT PRIMARY KEY,
            position INTEGER NOT NULL,
            json TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )''');
      },
    );
    _db = db;
    return db;
  }

  @visibleForTesting
  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  // ---------- recipes ----------

  static Future<void> upsertRecipe(Map<String, dynamic> recipe) async {
    final id = recipe['_id']?.toString();
    if (id == null || id.isEmpty) return;
    final db = await instance;
    await db.insert(
      tRecipes,
      _recipeRow(id, recipe),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Map<String, Object?> _recipeRow(String id, Map<String, dynamic> r) => {
        'id': id,
        'title': (r['title'] ?? '').toString(),
        'json': jsonEncode(r),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      };

  static Future<Map<String, dynamic>?> recipeById(String id) async {
    final db = await instance;
    final rows = await db.query(tRecipes,
        columns: ['json'], where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return _decode(rows.first['json'] as String);
  }

  /// Replaces list [key] with [recipes] in one transaction.
  static Future<void> replaceRecipeList(
      String key, List<Map<String, dynamic>> recipes) async {
    final db = await instance;
    await db.transaction((txn) async {
      await txn.delete(tRecipeLists, where: 'list_key = ?', whereArgs: [key]);
      final batch = txn.batch();
      var pos = 0;
      for (final r in recipes) {
        final id = r['_id']?.toString();
        if (id == null || id.isEmpty) continue;
        batch.insert(tRecipes, _recipeRow(id, r),
            conflictAlgorithm: ConflictAlgorithm.replace);
        batch.insert(tRecipeLists,
            {'list_key': key, 'position': pos++, 'recipe_id': id});
      }
      await batch.commit(noResult: true);
    });
  }

  static Future<List<Map<String, dynamic>>> recipeList(String key) async {
    final db = await instance;
    final rows = await db.rawQuery('''
      SELECT r.json AS json FROM $tRecipeLists l
      JOIN $tRecipes r ON r.id = l.recipe_id
      WHERE l.list_key = ? ORDER BY l.position''', [key]);
    return _decodeAll(rows);
  }

  static Future<List<Map<String, dynamic>>> recipesByIds(
      List<String> ids) async {
    if (ids.isEmpty) return [];
    final db = await instance;
    final marks = List.filled(ids.length, '?').join(',');
    final rows = await db.rawQuery(
        'SELECT id, json FROM $tRecipes WHERE id IN ($marks)', ids);
    final byId = {
      for (final r in rows) r['id'] as String: _decode(r['json'] as String)
    };
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!
    ];
  }

  /// Case-insensitive title search over every cached recipe.
  static Future<List<Map<String, dynamic>>> searchRecipes(String query) async {
    final db = await instance;
    final like = '%${query.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_')}%';
    final rows = await db.query(tRecipes,
        columns: ['json'],
        where: "title LIKE ? ESCAPE '\\'",
        whereArgs: [like],
        orderBy: 'updated_at DESC');
    return _decodeAll(rows);
  }

  // ---------- fridge ----------

  static Future<void> replaceFridge(List<Map<String, dynamic>> items) async {
    final db = await instance;
    await db.transaction((txn) async {
      await txn.delete(tFridge);
      final batch = txn.batch();
      final now = DateTime.now().millisecondsSinceEpoch;
      var pos = 0;
      for (final it in items) {
        final id = it['_id']?.toString();
        if (id == null || id.isEmpty) continue;
        batch.insert(
            tFridge,
            {
              'id': id,
              'position': pos++,
              'json': jsonEncode(it),
              'updated_at': now,
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  static Future<List<Map<String, dynamic>>> fridge() async {
    final db = await instance;
    final rows = await db.query(tFridge, columns: ['json'], orderBy: 'position');
    return _decodeAll(rows);
  }

  /// Wipes everything that belongs to the signed-in account.
  static Future<void> clearAll() async {
    final db = await instance;
    await db.transaction((txn) async {
      await txn.delete(tRecipeLists);
      await txn.delete(tRecipes);
      await txn.delete(tFridge);
    });
  }

  // ---------- helpers ----------

  static Map<String, dynamic>? _decode(String s) {
    try {
      final m = jsonDecode(s);
      return m is Map ? Map<String, dynamic>.from(m) : null;
    } catch (_) {
      return null;
    }
  }

  static List<Map<String, dynamic>> _decodeAll(List<Map<String, Object?>> rows) {
    final out = <Map<String, dynamic>>[];
    for (final r in rows) {
      final m = _decode(r['json'] as String);
      if (m != null) out.add(m);
    }
    return out;
  }
}
