class Recipe {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final int calories;
  final int prepTime;
  final int cookTime;
  final int popularity;

  const Recipe({
    required this.id,
    required this.title,
    this.description = '',
    this.imageUrl = '',
    this.calories = 0,
    this.prepTime = 0,
    this.cookTime = 0,
    this.popularity = 0,
  });

  int get totalMinutes => prepTime + cookTime;

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final nutrition = json['nutrition_info'];
    return Recipe(
      id: (json['_id'] ?? '').toString(),
      title: (json['title'] ?? 'Resep').toString(),
      description: (json['description'] ?? '').toString(),
      imageUrl: (json['image_url'] ?? '').toString(),
      calories: _asInt(nutrition is Map ? nutrition['calories'] : null),
      prepTime: _asInt(json['prep_time']),
      cookTime: _asInt(json['cook_time']),
      popularity: _asInt(json['popularity_count']),
    );
  }

  static int _asInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
