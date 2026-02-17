import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:smartcook/auth/signIn.dart';
import 'package:smartcook/service/api_service.dart';
import 'package:smartcook/service/offline_cache_service.dart';
import 'package:smartcook/service/offline_manager.dart';
import 'package:smartcook/view/splashscreen.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  ApiService.onUnauthorized = () {
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/signin',
      (route) => false,
    );
  };

  runApp(const MyApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    OfflineManager.isOffline.addListener(_handleOfflineChange);
  }

  @override
  void dispose() {
    OfflineManager.isOffline.removeListener(_handleOfflineChange);
    super.dispose();
  }

  Future<void> _handleOfflineChange() async {
    final isOffline = OfflineManager.isOffline.value;
    // Transisi dari offline -> online
    if (_wasOffline && !isOffline) {
      final ctx = navigatorKey.currentContext;
      if (ctx != null) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Koneksi kembali online'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Sync antrian operasi offline (favorit, kulkas, dll)
      await OfflineCacheService.syncPendingOperations();
    }
    _wasOffline = isOffline;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const splashscreen(),
        '/signin': (context) => const signin(),
      },
    );
  }
}
