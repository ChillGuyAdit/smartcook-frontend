import 'package:flutter/material.dart';
import 'package:smartcook/auth/signIn.dart';
import 'package:smartcook/auth/signUp.dart';
import 'package:smartcook/core/theme/app_theme_colors.dart';
import 'package:smartcook/helper/color.dart';
import 'package:smartcook/page/homepage.dart';
import 'package:smartcook/service/api_service.dart';
import 'package:smartcook/service/offline_manager.dart';
import 'package:smartcook/service/token_service.dart';
import 'package:smartcook/view/onboarding/mainBoarding.dart';

class splashscreen extends StatefulWidget {
  const splashscreen({super.key});

  @override
  State<splashscreen> createState() => _splashscreenState();
}

class _splashscreenState extends State<splashscreen> {
  Alignment _posisi = Alignment(0, -2);
  double _lebar = 50;
  double _tinggi = 50;

  Alignment _posisiLogo = Alignment(0, -5);

  double _opacityTeks = 0;
  double _posisiTiraiKiri = 0;
  Alignment _posisiTeks = Alignment(0, 0);

  @override
  void initState() {
    super.initState();

    Future.delayed(Duration(milliseconds: 1), () {
      if (mounted) setState(() => _posisi = Alignment.center);
    });

    Future.delayed(Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _lebar = 5000;
          _tinggi = 5000;
        });
      }
    });

    Future.delayed(Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _posisiLogo = Alignment.center);
    });

    Future.delayed(Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() {
          _posisiLogo = Alignment(-0.50, 0);
          _posisiTeks = Alignment(0.48, 0);
        });
      }
    });

    Future.delayed(Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _opacityTeks = 1);
    });

    Future.delayed(Duration(milliseconds: 2800), () {
      if (mounted) setState(() => _posisiTiraiKiri = 250);
    });

    Future.delayed(Duration(milliseconds: 3800), () {
      if (mounted) {
        setState(() {
          _opacityTeks = 0;
          _posisiTiraiKiri = 0;
          _posisiLogo = Alignment.center;
        });
      }
    });

    Future.delayed(Duration(milliseconds: 4600), () async {
      if (!mounted) return;
      try {
        await _decideWhereToGo();
      } catch (e, st) {
        debugPrint('[splash] decide failed: $e\n$st');
        // Never strand the user on the splash screen. If anything goes wrong
        // here the app used to stay blank forever with no way forward, which
        // is what "white screen after launch" turned out to be.
        if (!mounted) return;
        _go(signin());
      }
    });
  }

  /// Never let two navigations race: both ApiService's global 401 handler and
  /// this screen want to redirect, and the loser used to fire against an
  /// unmounted context.
  bool _navigated = false;

  void _go(Widget page) {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, _, __) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  Future<void> _decideWhereToGo() async {
    final token = await TokenService.getToken();
    if (token == null || token.isEmpty) {
      _go(signup());
      return;
    }
    final res = await ApiService.get('/api/user/profile', useAuth: true);
    if (!mounted) return;
    if (!res.success) {
      // Offline is not a reason to log the user out; keep them in the app
      // with the offline banner and cached data.
      final isMaybeOffline =
          res.statusCode == null || (res.message ?? '').contains('koneksi');
      if (isMaybeOffline) {
        OfflineManager.setOffline(true);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => homepage()),
        );
        return;
      }
      if (res.statusCode == 401) await TokenService.clearAll();
      _go(signin());
      return;
    }
    OfflineManager.setOffline(false);
    final data = res.data as Map<String, dynamic>?;
    final onboardingCompleted = data?['onboarding_completed'] == true;
    if (!mounted) return;
    if (onboardingCompleted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => homepage()),
      );
    } else {
      _go(onboarding());
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double baseWidth = 430;
    double scale = screenWidth / baseWidth;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Stack(
        children: [
          AnimatedAlign(
            alignment: _posisi,
            duration: Duration(seconds: 1),
            curve: Curves.bounceOut,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 800),
              height: _tinggi,
              width: _lebar,
              decoration: BoxDecoration(
                color: AppColor().utama,
                borderRadius:
                    BorderRadius.circular(_lebar > 100 ? 0 : 30 * scale),
              ),
            ),
          ),
          AnimatedOpacity(
            duration: Duration(milliseconds: 400),
            opacity: _opacityTeks,
            child: AnimatedAlign(
              alignment: _posisiTeks,
              duration: Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              child: SizedBox(
                width: 200 * scale,
                height: 50 * scale,
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Smart Cook",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32 * scale,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    AnimatedPositioned(
                      duration: Duration(milliseconds: 600),
                      curve: Curves.easeInOut,
                      left: _posisiTiraiKiri * scale,
                      top: 0,
                      bottom: 0,
                      child: Container(
                          width: 200 * scale, color: AppColor().utama),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedAlign(
            key: ValueKey('logo_utama'),
            alignment: _posisiLogo,
            duration: Duration(milliseconds: 700),
            curve: Curves.easeInOutBack,
            child: Container(
              height: 70 * scale,
              width: 70 * scale,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('image/mainLogo.jpg'),
                  fit: BoxFit.contain,
                ),
                borderRadius: BorderRadius.circular(50 * scale),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
