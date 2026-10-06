import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:smartcook/auth/signIn.dart';
import 'package:smartcook/service/api_service.dart';
import 'package:smartcook/service/offline_cache_service.dart';
import 'package:smartcook/service/offline_manager.dart';
import 'package:smartcook/view/splashscreen.dart';
import 'package:smartcook/core/services/app_session.dart';
import 'package:smartcook/core/services/app_update_checker.dart';
import 'package:smartcook/core/theme/app_colors.dart';
import 'package:smartcook/core/theme/app_theme.dart';
import 'package:smartcook/core/theme/language_controller.dart';
import 'package:smartcook/core/theme/shadows.dart';
import 'package:smartcook/core/theme/theme_provider.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Restore the saved theme before the first frame so the app never flashes
  // light mode then snaps to dark.
  await ThemeProvider.instance.load();
  await LanguageController.instance.load();

  ApiService.onUnauthorized = () {
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/signin',
      (route) => false,
    );
  };

  runApp(const MyApp());

  // Auto-update dialog. Same pattern as Kelilink: check at boot, retry every
  // 30s if offline, then stop. The dialog itself waits for a mounted context.
  unawaited(AppUpdateChecker.check(() => navigatorKey.currentContext));

  // App session (access + refresh token). Started after the first frame so a
  // slow handshake never delays the splash screen. ApiService also lazily
  // calls ensureSession() on the first request, so a failure here is not
  // fatal: the user simply stays offline until the next attempt succeeds.
  unawaited(_bootstrapSession());
}

Future<void> _bootstrapSession() async {
  try {
    await AppSession.instance.ensureSession();
  } on SessionException catch (e) {
    debugPrint('[session] bootstrap failed: ${e.failure.name}');
  } catch (e) {
    debugPrint('[session] bootstrap error: $e');
  }
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
    return AnimatedBuilder(
      // Theme and language both feed MaterialApp, so both are listed here.
      animation: Listenable.merge([
        ThemeProvider.instance,
        LanguageController.instance,
      ]),
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeProvider.instance.mode,
          locale: LanguageController.instance.locale,
          supportedLocales: LanguageController.supportedLocales,
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
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: context.floatShadow,
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
      },
    );
  }
}
