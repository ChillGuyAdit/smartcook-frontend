import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smartcook/auth/signIn.dart';
import 'package:smartcook/service/api_service.dart';
import 'package:smartcook/service/offline_cache_service.dart';
import 'package:smartcook/service/offline_manager.dart';
import 'package:smartcook/view/splashscreen.dart';
import 'package:smartcook/core/services/app_session.dart';
import 'package:smartcook/core/services/app_update_checker.dart';
import 'package:smartcook/core/services/dev_log.dart';
import 'package:smartcook/core/services/screen_observer.dart';
import 'package:smartcook/core/l10n/strings.dart';
import 'package:smartcook/core/theme/app_colors.dart';
import 'package:smartcook/core/theme/app_theme.dart';
import 'package:smartcook/core/theme/language_controller.dart';
import 'package:smartcook/core/theme/shadows.dart';
import 'package:smartcook/core/theme/theme_provider.dart';

import 'firebase_options.dart';

// One observer for the whole app: MaterialApp rebuilds on theme/language
// changes and the observer keeps the last screen it saw.
final ScreenObserver _screenObserver = ScreenObserver();

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

  // Developer debug log. Init early so a crash during boot still produces a
// record, and any events queued by a previous run are flushed.
  await DevLog.init();
  DevLog.log('app_launch', action: 'cold_start', level: 'info');
  // Anything that escapes a zone handler is the most valuable signal we get.
  FlutterError.onError = (details) {
    DevLog.error(
      'unhandled_error',
      details.exception,
      stack: details.stack,
      action: 'flutter_error',
      meta: {
        'library': details.library ?? 'flutter',
        'context': details.context?.toString()
      },
    );
    FlutterError.presentError(details);
  };

  runApp(const MyApp());

  // Without this, any render error leaves a bare white screen with no way for
  // the user to understand or recover. Turning language, for example, rebuilds
  // the whole MaterialApp tree; if anything in there throws, this is what the
  // user sees instead of nothing.
  ErrorWidget.builder = (details) {
    DevLog.error(
      'render_error',
      details.exception,
      stack: details.stack,
      action: 'build',
      meta: {'context': details.context?.toString()},
    );
    return _RenderErrorScreen(error: details.exceptionAsString());
  };

  // NOTE: the auto-update check is NOT started here. During the splash
  // transition `navigatorKey.currentContext` is still null, so the check
  // would fetch the manifest and then silently give up waiting for a usable
  // context - the user would never see the dialog. `homepage` starts it from a
  // mounted page instead, and again on every resume.

  // App session (access + refresh token). Started after the first frame so a
  // slow handshake never delays the splash screen. ApiService also lazily
  // calls ensureSession() on the first request, so a failure here is not
  // fatal: the user simply stays offline until the next attempt succeeds.
  unawaited(_bootstrapSession());
}

Future<void> _bootstrapSession() async {
  try {
    await AppSession.instance.ensureSession();
    DevLog.log('session_state', action: 'handshake', meta: {'ok': true});
  } on SessionException catch (e) {
    // Worth recording precisely: a failed handshake is why the app shows the
    // login screen (or, before the fix, a blank page) instead of the home.
    DevLog.log(
      'session_state',
      action: 'handshake',
      level: e.failure == SessionFailure.notOfficial ? 'warn' : 'error',
      error: e.failure.name,
      meta: {'ok': false},
    );
    debugPrint('[session] bootstrap failed: ${e.failure.name}');
  } catch (e) {
    DevLog.error('session_state', e, action: 'handshake');
    debugPrint('[session] bootstrap error: $e');
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Last-resort screen for a render failure. Keeps the app usable instead of
/// showing a white void, and puts the error in the log for diagnosis.
class _RenderErrorScreen extends StatelessWidget {
  const _RenderErrorScreen({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFF12161A),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    color: Color(0xFF4CAF50), size: 46),
                const SizedBox(height: 14),
                const Text(
                  'SmartCook',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Something went wrong while drawing the screen.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => SystemNavigator.pop(),
                  child: const Text('Close app'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    OfflineManager.isOffline.addListener(_handleOfflineChange);
    // Auto-update check now runs from the root widget, exactly like Kelilink.
    // It used to live on `homepage`, which only mounts after login - so a
    // logged-out user never got the dialog at all, even with a mandatory
    // update pending. The 4s delay lets the splash route finish so the dialog
    // is not orphaned by a route-stack replacement.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(seconds: 4), _checkForUpdate);
    });
  }

  /// The update pop-up lives above all routes, so the system back key is
  /// offered to it first: closes an optional update, is swallowed for a
  /// mandatory one. This observer is registered before the app's navigator,
  /// so it is asked first.
  @override
  Future<bool> didPopRoute() async => UpdateOverlay.handleBack();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    OfflineManager.isOffline.removeListener(_handleOfflineChange);
    super.dispose();
  }

  void _checkForUpdate() {
    if (!mounted) return;
    unawaited(AppUpdateChecker.check(_stableNavigatorContext));
  }

  /// The update dialog must not open on splash/sign-in: those routes own the
  /// stack only until they finish, and they replace it wholesale when they do,
  /// which silently closes the dialog and lets a mandatory update slip past.
  /// Mirrors Kelilink's `_stableNavigatorContext`.
  BuildContext? _stableNavigatorContext() {
    if (!mounted) return null;
    final ctx = navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return null;
    final route = ModalRoute.of(ctx);
    if (route is PageRoute &&
        route.settings.name != null &&
        _transientRoutes.contains(route.settings.name)) {
      return null;
    }
    return ctx;
  }

  static const _transientRoutes = {'/', '/splash', '/signin', '/onboarding'};

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only on resume: re-checking on pause/inactive would fire a request
    // every time the notification shade was pulled down.
    if (state == AppLifecycleState.resumed) {
      DevLog.log('app_resume', action: 'resume');
      _checkForUpdate();
    } else if (state == AppLifecycleState.paused) {
      DevLog.log('app_pause', action: 'pause');
    }
  }

  Future<void> _handleOfflineChange() async {
    final isOffline = OfflineManager.isOffline.value;
    // Transisi dari offline -> online
    if (_wasOffline && !isOffline) {
      final ctx = navigatorKey.currentContext;
      if (ctx != null) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(currentStrings.backOnline),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
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
          navigatorObservers: [_screenObserver],
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeProvider.instance.mode,
          locale: LanguageController.instance.locale,
          supportedLocales: LanguageController.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          initialRoute: '/',
          routes: {
            '/': (context) => const splashscreen(),
            '/signin': (context) => const signin(),
          },
          // Wrapper global untuk menampilkan banner offline di seluruh aplikasi.
          builder: (context, child) {
            // While the update pop-up is open the back key belongs to it, even
            // when a route change reports that there is nothing to pop.
            final host = context;
            child = NotificationListener<NavigationNotification>(
              onNotification: (n) {
                if (UpdateOverlay.isOpen && !n.canHandlePop) {
                  const NavigationNotification(canHandlePop: true)
                      .dispatch(host);
                  return true;
                }
                return false;
              },
              child: child ?? const SizedBox.shrink(),
            );
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
                              children: [
                                const Icon(
                                  Icons.wifi_off_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    currentStrings.offlineBanner,
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
