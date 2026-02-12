import 'package:flutter/material.dart';
import 'package:smartcook/helper/color.dart';

class onboarding1 extends StatefulWidget {
  const onboarding1({super.key});

  @override
  State<onboarding1> createState() => _onboarding1State();
}

class _onboarding1State extends State<onboarding1> {
  @override
  Widget build(BuildContext context) {
    final screenheight = MediaQuery.of(context).size.height;
    final screenwidth = MediaQuery.of(context).size.width;

    double basewidth = 430;
    double scale = screenwidth / basewidth;
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.center,
            child: Image.asset('image/ob1.png'),
          ),
          Text(
            'Masak Lebih Praktis',
            style: TextStyle(fontSize: 32 * scale, fontWeight: FontWeight.bold),
          ),
          SizedBox(
            height: 13 * scale,
          ),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(fontSize: 20 * scale, color: Colors.black),
              children: [
                TextSpan(
                    text: "Si asisten pintar yang tahu semua isi kulkasmu."),
                TextSpan(
                  text: "SmartCook",
                  style: TextStyle(
                    color: AppColor().warnaIcon2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                    text:
                        " bakal kasih tahu\n apa yang harus kamu masak hari ini\n secara otomatis."),
              ],
            ),
          ),
          SizedBox(
            height: screenheight * 0.15,
          )
        ],
      ),
    );
  }
}
