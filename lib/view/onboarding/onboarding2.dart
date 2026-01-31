import 'package:flutter/material.dart';
import 'package:smartcook/helper/color.dart';

class onboarding2 extends StatefulWidget {
  const onboarding2({super.key});

  @override
  State<onboarding2> createState() => _onboarding2State();
}

class _onboarding2State extends State<onboarding2> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.center,
            child: Image.asset('image/ob2.png'),
          ),
          SizedBox(
            height: 40,
          ),
          Text(
            'Masak Pintar',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
          ),
          SizedBox(
            height: 10,
          ),
          Text(
            'Cukup 1 kali klik, mampu mengubah\n semua bahan makanan menjadi hidangan yang istimewa. let him cook!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
            ),
          )
        ],
      ),
    );
  }
}
