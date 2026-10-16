import 'package:flutter/foundation.dart' show visibleForTesting;
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartcook/service/api_service.dart';
import 'package:smartcook/service/local_database.dart';

class OfflineCacheService {
  static const _kRecentQueries = 'recent_recipe_queries_v1';
  static const _kPendingOps = 'pending_operations_v1';
  static const _kFavoriteIds = 'local_favorites_ids_v1';
  static const _kGlobalIngredients = 'global_ingredients_v1';
  static const _kHiddenIngredients = 'hidden_ingredients_v1';

  static String _norm(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static Future<List<String>> getRecentQueries({int limit = 20}) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kRecentQueries) ?? <String>[];
    if (list.length <= limit) return list;
    return list.take(limit).toList();
  }

  static Future<void> addRecentQuery(String query, {int limit = 20}) async {
    final q = _norm(query);
    if (q.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kRecentQueries) ?? <String>[];
    list.removeWhere((e) => _norm(e) == q);
    list.insert(0, query.trim());
    if (list.length > limit) list.removeRange(limit, list.length);
    await prefs.setStringList(_kRecentQueries, list);
  }

  static Future<void> saveRecipe(Map<String, dynamic> recipe) async {
    try {
      await LocalDatabase.upsertRecipe(recipe);
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> getRecipeById(String id) async {
    try {
      return await LocalDatabase.recipeById(id);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveRecipeList(
      String key, List<Map<String, dynamic>> recipes) async {
    try {
      await LocalDatabase.replaceRecipeList(key, recipes);
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> getRecipeList(String key) async {
    try {
      return await LocalDatabase.recipeList(key);
    } catch (_) {
      return [];
    }
  }

  // ============ Fridge (SQLite) ============

  static Future<void> saveFridge(List<Map<String, dynamic>> items) async {
    try {
      await LocalDatabase.replaceFridge(items);
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> getFridge() async {
    try {
      return await LocalDatabase.fridge();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveGlobalIngredients(
      List<Map<String, dynamic>> ingredients) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kGlobalIngredients, jsonEncode(ingredients));
  }

  static Future<List<Map<String, dynamic>>> getGlobalIngredients() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_kGlobalIngredients);
    if (s == null || s.isEmpty) return [];
    try {
      final decoded = jsonDecode(s);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<List<String>> getHiddenIngredientKeys() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_kHiddenIngredients) ?? <String>[];
  }

  static Future<void> addHiddenIngredientKey(String key) async {
    if (key.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kHiddenIngredients) ?? <String>[];
    if (!list.contains(key)) {
      list.add(key);
      await prefs.setStringList(_kHiddenIngredients, list);
    }
  }

  /// Cari cepat dari cache: title mengandung query (case-insensitive)
  /// (Best-effort: scan berdasarkan recent queries list keys)
  static Future<List<Map<String, dynamic>>> searchCachedByTitle(
      String query) async {
    final q = _norm(query);
    if (q.isEmpty) return [];
    try {
      return await LocalDatabase.searchRecipes(q);
    } catch (_) {
      return [];
    }
  }

  // ============ Local Favorites ============

  static Future<List<String>> _getFavoriteIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_kFavoriteIds) ?? <String>[];
  }

  static Future<void> _saveFavoriteIds(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kFavoriteIds, ids);
  }

  /// Simpan / hapus status favorit lokal supaya SavePage bisa baca saat offline.
  static Future<void> setFavoriteLocally(String recipeId, bool isFav) async {
    if (recipeId.isEmpty) return;
    final ids = await _getFavoriteIds();
    if (isFav) {
      if (!ids.contains(recipeId)) {
        ids.add(recipeId);
      }
    } else {
      ids.removeWhere((e) => e == recipeId);
    }
    await _saveFavoriteIds(ids);
  }

  /// Ambil daftar resep favorit dari cache berdasarkan id yang tersimpan.
  static Future<List<Map<String, dynamic>>> getLocalFavoriteRecipes() async {
    final ids = await _getFavoriteIds();
    try {
      return await LocalDatabase.recipesByIds(ids);
    } catch (_) {
      return [];
    }
  }

  // ============ Pending Operations (untuk sync offline) ============

  static Future<List<Map<String, dynamic>>> _getPendingOps() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kPendingOps) ?? <String>[];
    final list = <Map<String, dynamic>>[];
    for (final s in raw) {
      try {
        final m = jsonDecode(s);
        if (m is Map) {
          list.add(Map<String, dynamic>.from(m));
        }
      } catch (_) {}
    }
    return list;
  }

  static Future<void> _savePendingOps(List<Map<String, dynamic>> ops) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = ops.map((m) => jsonEncode(m)).toList();
    await prefs.setStringList(_kPendingOps, raw);
  }

  static Future<void> addPendingOperation({
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) async {
    final ops = await _getPendingOps();
    ops.add({
      'method': method,
      'path': path,
      if (body != null) 'body': body,
      'timestamp': DateTime.now().toIso8601String(),
    });
    await _savePendingOps(ops);
  }

  /// Forget every queued operation. Called on sign-out and account deletion:
  /// the queue belongs to the account that made it and must never be replayed
  /// into the next account that signs in on this phone.
  static Future<void> clearPendingOperations() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPendingOps);
    try {
      await LocalDatabase.clearAll();
    } catch (_) {}
  }

  /// A failed replay is worth keeping only when trying again can help: no
  /// connection, an expired session, a timeout, throttling or a server error.
  /// A 404 (item already gone), 400 or 409 will never succeed, and keeping it
  /// made the same dead operation run on every start for ever.
  @visibleForTesting
  static bool worthRetrying(int? status) {
    if (status == null) return true;
    if (status >= 500) return true;
    return status == 401 || status == 408 || status == 429;
  }

  /// Coba jalankan semua operasi yang tertunda ketika sudah online.
  static Future<void> syncPendingOperations() async {
    var ops = await _getPendingOps();
    if (ops.isEmpty) return;
    final remaining = <Map<String, dynamic>>[];
    for (final op in ops) {
      final method = (op['method'] ?? '').toString().toUpperCase();
      final path = op['path']?.toString() ?? '';
      if (path.isEmpty) continue;
      final body = op['body'] is Map<String, dynamic>
          ? op['body'] as Map<String, dynamic>
          : op['body'] is Map
              ? Map<String, dynamic>.from(op['body'] as Map)
              : null;
      try {
        ApiResponse res;
        switch (method) {
          case 'POST':
            res = await ApiService.post(path, body: body, useAuth: true);
            break;
          case 'PUT':
            res = await ApiService.put(path, body: body, useAuth: true);
            break;
          case 'DELETE':
            res = await ApiService.delete(path, useAuth: true);
            break;
          default:
            continue;
        }
        if (!res.success && worthRetrying(res.statusCode)) {
          // Jika masih gagal (mungkin masih offline), simpan lagi
          remaining.add(op);
        }
      } catch (_) {
        remaining.add(op);
      }
    }
    await _savePendingOps(remaining);
  }
}
