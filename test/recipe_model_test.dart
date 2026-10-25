import 'package:flutter_test/flutter_test.dart';
import 'package:smartcook/models/recipe.dart';
import 'package:smartcook/service/recipe_repository.dart';

void main() {
  group('Recipe.fromJson', () {
    test('membaca field API dan menghitung total waktu', () {
      final r = Recipe.fromJson({
        '_id': 'abc',
        'title': 'Sop Ayam Bening',
        'description': 'Sup ayam segar',
        'image_url': 'https://example.com/a.jpg',
        'nutrition_info': {'calories': 200},
        'prep_time': 15,
        'cook_time': 40,
        'popularity_count': 7,
      });
      expect(r.id, 'abc');
      expect(r.title, 'Sop Ayam Bening');
      expect(r.calories, 200);
      expect(r.totalMinutes, 55);
      expect(r.popularity, 7);
    });

    test('nilai yang hilang atau berupa teks tidak membuat galat', () {
      final r = Recipe.fromJson({
        '_id': 'x',
        'nutrition_info': {'calories': '350'},
        'prep_time': null,
        'cook_time': '20',
      });
      expect(r.title, 'Resep');
      expect(r.calories, 350);
      expect(r.totalMinutes, 20);
      expect(r.imageUrl, '');
    });
  });

  group('RecipeRepository.parseRecipes', () {
    test('menerima daftar langsung', () {
      final list = RecipeRepository.parseRecipes([
        {'_id': '1', 'title': 'A'},
        {'_id': '2', 'title': 'B'},
      ]);
      expect(list.map((e) => e.title), ['A', 'B']);
    });

    test('menerima objek berkunci recipes dan membuang elemen tanpa _id', () {
      final list = RecipeRepository.parseRecipes({
        'recipes': [
          {'_id': '1', 'title': 'A'},
          {'title': 'tanpa id'},
          'bukan map',
        ],
      });
      expect(list.length, 1);
      expect(list.first.id, '1');
    });

    test('bentuk data yang tidak dikenali melempar RecipeLoadException', () {
      expect(() => RecipeRepository.parseRecipes('rusak'),
          throwsA(isA<RecipeLoadException>()));
    });
  });
}
