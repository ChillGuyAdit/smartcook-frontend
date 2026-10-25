import '../models/recipe.dart';
import 'api_service.dart';

class RecipeLoadException implements Exception {
  final String message;
  const RecipeLoadException(this.message);

  @override
  String toString() => 'RecipeLoadException: $message';
}

class RecipeRepository {
  static Future<List<Recipe>> fetchByCategory(String category) async {
    final params = <String, String>{'page': '1', 'limit': '50'};
    if (category.isNotEmpty) params['category'] = category;
    final res = await ApiService.get('/api/recipes', queryParameters: params);
    if (!res.success) {
      throw RecipeLoadException(res.message ?? 'Gagal memuat resep');
    }
    return parseRecipes(res.data);
  }

  static List<Recipe> parseRecipes(Object? data) {
    final raw = data is Map ? data['recipes'] : data;
    if (raw is! List) {
      throw const RecipeLoadException('Format data resep tidak dikenali');
    }
    return raw
        .whereType<Map>()
        .map((e) => Recipe.fromJson(Map<String, dynamic>.from(e)))
        .where((r) => r.id.isNotEmpty)
        .toList();
  }
}
