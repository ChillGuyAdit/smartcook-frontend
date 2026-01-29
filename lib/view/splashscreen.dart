import 'package:flutter/material.dart';
import 'package:smartcook/helper/color.dart';
// Ganti path ini sesuai dengan lokasi file signup lu bray
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
      setState(() => _posisi = Alignment.center);
    });

    Future.delayed(Duration(milliseconds: 1000), () {
      setState(() {
        _lebar = 3000;
        _tinggi = 3000;
      });
    });

    Future.delayed(Duration(milliseconds: 1000), () {
      setState(() => _posisiLogo = Alignment.center);
    });

    Future.delayed(Duration(milliseconds: 2000), () {
      setState(() {
        _posisiLogo = Alignment(-0.57, 0);
        _posisiTeks = Alignment(0.38, 0);
      });
    });

    Future.delayed(Duration(milliseconds: 2500), () {
      setState(() => _opacityTeks = 1);
    });

    Future.delayed(Duration(milliseconds: 2800), () {
      setState(() => _posisiTiraiKiri = 250);
    });

    Future.delayed(Duration(milliseconds: 3800), () {
      setState(() {
        _opacityTeks = 0;
        _posisiTiraiKiri = 0;
        _posisiLogo = Alignment.center;
      });
    });

    Future.delayed(Duration(milliseconds: 4600), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, anim1, anim2) => const signup(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. BACKGROUND UTAMA
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
                borderRadius: BorderRadius.circular(_lebar > 100 ? 0 : 30),
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
                width: 200,
                height: 50,
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Smart Cook",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    AnimatedPositioned(
                      duration: Duration(milliseconds: 600),
                      curve: Curves.easeInOut,
                      left: _posisiTiraiKiri,
                      top: 0,
                      bottom: 0,
                      child: Container(width: 200, color: AppColor().utama),
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
              height: 70,
              width: 70,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('image/mainLogo.jpg'),
                  fit: BoxFit.contain,
                ),
                borderRadius: BorderRadius.circular(50),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
