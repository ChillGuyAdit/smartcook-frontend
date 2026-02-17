import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartcook/service/api_service.dart';

class OfflineCacheService {
  static const _kRecentQueries = 'recent_recipe_queries_v1';
  static const _kRecipeById = 'recipe_by_id_v1:'; // + id
  static const _kListByKey = 'recipe_list_v1:'; // + key
  static const _kPendingOps = 'pending_operations_v1';
  static const _kFavoriteIds = 'local_favorites_ids_v1';
  static const _kGlobalIngredients = 'global_ingredients_v1';

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
    final id = recipe['_id']?.toString();
    if (id == null || id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_kRecipeById$id', jsonEncode(recipe));
  }

  static Future<Map<String, dynamic>?> getRecipeById(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('$_kRecipeById$id');
    if (s == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(s) as Map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveRecipeList(String key, List<Map<String, dynamic>> recipes) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = <String>[];
    for (final r in recipes) {
      final id = r['_id']?.toString();
      if (id == null || id.isEmpty) continue;
      ids.add(id);
      await saveRecipe(r);
    }
    await prefs.setStringList('$_kListByKey$key', ids);
  }

  static Future<List<Map<String, dynamic>>> getRecipeList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('$_kListByKey$key') ?? <String>[];
    final out = <Map<String, dynamic>>[];
    for (final id in ids) {
      final r = await getRecipeById(id);
      if (r != null) out.add(r);
    }
    return out;
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

  /// Cari cepat dari cache: title mengandung query (case-insensitive)
  /// (Best-effort: scan berdasarkan recent queries list keys)
  static Future<List<Map<String, dynamic>>> searchCachedByTitle(String query) async {
    final q = _norm(query);
    if (q.isEmpty) return [];
    final recents = await getRecentQueries(limit: 30);
    final seen = <String>{};
    final results = <Map<String, dynamic>>[];
    for (final r in recents) {
      final key = 'search_${_norm(r)}';
      final list = await getRecipeList(key);
      for (final item in list) {
        final id = item['_id']?.toString() ?? '';
        if (id.isEmpty || seen.contains(id)) continue;
        final title = (item['title'] ?? '').toString().toLowerCase();
        if (title.contains(q)) {
          seen.add(id);
          results.add(item);
        }
      }
    }
    return results;
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
    final out = <Map<String, dynamic>>[];
    for (final id in ids) {
      final r = await getRecipeById(id);
      if (r != null) out.add(r);
    }
    return out;
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
        if (!res.success) {
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

