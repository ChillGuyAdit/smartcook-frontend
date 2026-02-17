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
      try {
        await OfflineCacheService.syncPendingOperations();
      } catch (_) {
        // Biarkan silent: jika gagal, operasi akan tetap tersimpan
        // dan dicoba lagi pada transisi online berikutnya.
      }
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
      // Wrapper global untuk menampilkan banner offline di seluruh aplikasi.
      builder: (context, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: OfflineManager.isOffline,
          builder: (context, isOffline, _) {
            final mediaQuery = MediaQuery.of(context);
            return Stack(
              children: [
                child ?? const SizedBox.shrink(),
                if (isOffline)
                  Positioned(
                    top: mediaQuery.padding.top + 8,
                    left: 12,
                    right: 12,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.wifi_off_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Anda sedang offline. Beberapa fitur mungkin terbatas.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
