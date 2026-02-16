import 'package:flutter/material.dart';
import 'package:smartcook/helper/color.dart';
import 'package:smartcook/auth/signup.dart';

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
          _posisiLogo = Alignment(-0.65, 0);
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

    Future.delayed(Duration(milliseconds: 4600), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, anim1, anim2) => signup(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double baseWidth = 430;
    double scale = screenWidth / baseWidth;

    return Scaffold(
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
