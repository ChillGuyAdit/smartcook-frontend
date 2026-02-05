import 'package:flutter/material.dart';
import 'package:smartcook/helper/color.dart';
import 'package:smartcook/auth/signup.dart';

class splashscreen extends StatefulWidget {
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
          _posisiLogo = Alignment(-0.9, 0);
          _posisiTeks = Alignment(1.1, 0);
        });
      }
    });

    Future.delayed(Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _opacityTeks = 1);
    });

    Future.delayed(Duration(milliseconds: 2800), () {
      if (mounted) setState(() => _posisiTiraiKiri = 1.2);
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

    double logoSize = 95 * scale;
    double boxTeksWidth = 280 * scale;

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
          Center(
            child: Container(
              width: screenWidth * 0.95,
              height: 120 * scale,
              child: Stack(
                children: [
                  AnimatedAlign(
                    alignment: _posisiTeks,
                    duration: Duration(milliseconds: 600),
                    curve: Curves.easeInOut,
                    child: AnimatedOpacity(
                      duration: Duration(milliseconds: 400),
                      opacity: _opacityTeks,
                      child: SizedBox(
                        width: boxTeksWidth,
                        height: 70 * scale,
                        child: Stack(
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Smart Cook",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 38 * scale,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.8,
                                ),
                              ),
                            ),
                            AnimatedPositioned(
                              duration: Duration(milliseconds: 800),
                              curve: Curves.easeInOut,
                              left: _posisiTiraiKiri * boxTeksWidth,
                              top: 0,
                              bottom: 0,
                              child: Container(
                                width: boxTeksWidth + 50,
                                color: AppColor().utama,
                              ),
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
                      height: logoSize,
                      width: logoSize,
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage('image/mainLogo.jpg'),
                          fit: BoxFit.cover,
                        ),
                        borderRadius: BorderRadius.circular(100 * scale),
                        border:
                            Border.all(color: Colors.white, width: 2.5 * scale),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
