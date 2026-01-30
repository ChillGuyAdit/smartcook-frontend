import 'package:flutter/material.dart';
import 'package:smartcook/helper/color.dart';
import 'dart:async';
import 'package:smartcook/auth/sukses.dart';

class animasisukses extends StatefulWidget {
  const animasisukses({super.key});

  @override
  State<animasisukses> createState() => _animasisuksesState();
}

class _animasisuksesState extends State<animasisukses> {
  @override
  void initState() {
    super.initState();
    Timer(Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => sukses(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: Duration(milliseconds: 600),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor().utama,
      body: Center(
        child: CircularProgressIndicator(
          color: AppColor().putih,
          strokeWidth: 5,
        ),
      ),
    );
  }
}
