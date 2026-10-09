import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartcook/service/offline_cache_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('only failures that a retry can fix stay in the offline queue', () {
    for (final keep in [null, 401, 408, 429, 500, 502, 503]) {
      expect(OfflineCacheService.worthRetrying(keep), isTrue, reason: '$keep');
    }
    for (final drop in [400, 403, 404, 409, 422]) {
      expect(OfflineCacheService.worthRetrying(drop), isFalse, reason: '$drop');
    }
  });

  test('sign-out empties the queue so it cannot run on the next account',
      () async {
    await OfflineCacheService.addPendingOperation(
        method: 'DELETE', path: '/api/fridge/abc');
    await OfflineCacheService.addPendingOperation(
        method: 'POST',
        path: '/api/fridge',
        body: {'ingredient_name': 'Ayam', 'category': 'protein'});
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('pending_operations_v1'), hasLength(2));

    await OfflineCacheService.clearPendingOperations();
    expect(prefs.getStringList('pending_operations_v1'), isNull);
    // and replaying an empty queue is a no-op
    await OfflineCacheService.syncPendingOperations();
  });
}
