import 'package:flutter/material.dart';
import 'package:smartcook/helper/color.dart';
import 'package:smartcook/view/onboarding/onboarding1.dart';
import 'package:smartcook/view/onboarding/onboarding2.dart';
import 'package:smartcook/view/onboarding/onboarding3.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class onboarding extends StatefulWidget {
  const onboarding({super.key});

  @override
  State<onboarding> createState() => _onboardingState();
}

class _onboardingState extends State<onboarding> {
  final PageController _pageController = PageController();
  bool halamanTerakhir = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Stack(
      children: [
        PageView(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              halamanTerakhir = (index == 2);
            });
          },
          physics: ClampingScrollPhysics(),
          children: const [
            onboarding1(),
            onboarding2(),
            onboarding3(),
          ],
        ),
        Container(
          alignment: const Alignment(0, 0.8),
          child: SmoothPageIndicator(
            controller: _pageController,
            count: 3,
            effect: ExpandingDotsEffect(
              activeDotColor: AppColor().utama,
              dotColor: AppColor().utama,
              dotHeight: 19,
              dotWidth: 30,
            ),
          ),
        ),
        !halamanTerakhir
            ? Positioned(
                top: 70,
                right: 35,
                child: GestureDetector(
                  onTap: () {
                    _pageController.jumpToPage(2);
                  },
                  child: Text(
                    'Skip >',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColor().abuabuAgaGelap,
                    ),
                  ),
                ),
              )
            : Text('')
      ],
    ));
  }
}
