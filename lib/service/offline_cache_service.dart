import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineCacheService {
  static const _kRecentQueries = 'recent_recipe_queries_v1';
  static const _kRecipeById = 'recipe_by_id_v1:'; // + id
  static const _kListByKey = 'recipe_list_v1:'; // + key

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
}

