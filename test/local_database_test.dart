import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartcook/service/local_database.dart';
import 'package:smartcook/service/offline_cache_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Map<String, dynamic> recipe(String id, String title) =>
    {'_id': id, 'title': title, 'ingredients': ['a', 'b']};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalDatabase.close();
    LocalDatabase.pathOverride = inMemoryDatabasePath;
  });

  tearDown(LocalDatabase.close);

  test('recipe round-trips through SQLite', () async {
    await OfflineCacheService.saveRecipe(recipe('1', 'Nasi Goreng'));
    final back = await OfflineCacheService.getRecipeById('1');
    expect(back?['title'], 'Nasi Goreng');
    expect(back?['ingredients'], ['a', 'b']);
    expect(await OfflineCacheService.getRecipeById('nope'), isNull);
  });

  test('a recipe list keeps its order and is replaced, not appended', () async {
    await OfflineCacheService.saveRecipeList(
        'home', [recipe('2', 'B'), recipe('1', 'A'), recipe('3', 'C')]);
    var ids = (await OfflineCacheService.getRecipeList('home'))
        .map((r) => r['_id'])
        .toList();
    expect(ids, ['2', '1', '3']);

    await OfflineCacheService.saveRecipeList('home', [recipe('3', 'C')]);
    ids = (await OfflineCacheService.getRecipeList('home'))
        .map((r) => r['_id'])
        .toList();
    expect(ids, ['3']);
  });

  test('title search is case-insensitive and treats % literally', () async {
    await OfflineCacheService.saveRecipeList(
        'x', [recipe('1', 'Soto Ayam'), recipe('2', '100% Sehat')]);
    expect(await OfflineCacheService.searchCachedByTitle('SOTO'), hasLength(1));
    expect(await OfflineCacheService.searchCachedByTitle('%'), hasLength(1));
    expect(await OfflineCacheService.searchCachedByTitle('zzz'), isEmpty);
  });

  test('fridge snapshot is stored in order and replaced on every save',
      () async {
    await OfflineCacheService.saveFridge([
      {'_id': 'b', 'ingredient_name': 'Telur', 'quantity': 6},
      {'_id': 'a', 'ingredient_name': 'Ayam', 'quantity': 2},
    ]);
    var items = await OfflineCacheService.getFridge();
    expect(items.map((e) => e['_id']), ['b', 'a']);

    await OfflineCacheService.saveFridge([
      {'_id': 'a', 'ingredient_name': 'Ayam', 'quantity': 1},
    ]);
    items = await OfflineCacheService.getFridge();
    expect(items, hasLength(1));
    expect(items.single['quantity'], 1);
  });

  test('sign-out wipes the SQLite cache', () async {
    await OfflineCacheService.saveRecipe(recipe('1', 'A'));
    await OfflineCacheService.saveFridge([
      {'_id': 'a', 'ingredient_name': 'Ayam'},
    ]);

    await OfflineCacheService.clearPendingOperations();

    expect(await OfflineCacheService.getRecipeById('1'), isNull);
    expect(await OfflineCacheService.getFridge(), isEmpty);
  });
}
