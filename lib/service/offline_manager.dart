import 'package:flutter/foundation.dart';

/// Menyimpan status offline/online secara global.
class OfflineManager {
  static final ValueNotifier<bool> isOffline = ValueNotifier<bool>(false);

  static void setOffline(bool value) {
    if (isOffline.value == value) return;
    isOffline.value = value;
  }
}
