import 'package:flutter/material.dart';
import 'package:smartcook/helper/color.dart';

class onboarding3 extends StatefulWidget {
  const onboarding3({super.key});

  @override
  State<onboarding3> createState() => _onboarding3State();
}

class _onboarding3State extends State<onboarding3> {
  @override
  Widget build(BuildContext context) {
    final screenheight = MediaQuery.of(context).size.height;
    final screenwidth = MediaQuery.of(context).size.width;
    return Scaffold(
        body: Stack(
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Align(
              alignment: Alignment.center,
              child: Image.asset('image/ob3.png'),
            ),
            RichText(
              text: TextSpan(
                  style: TextStyle(fontSize: 30, color: Colors.black),
                  children: [
                    TextSpan(
                      text: 'Smartcook',
                      style: TextStyle(
                          color: AppColor().warnaIcon2,
                          fontSize: 30,
                          fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: ' Jaga Kulkasmu')
                  ]),
            ),
            SizedBox(
              height: 15,
            ),
            Text(
              'Dari stok pasar sampai ke meja makan,\n SmartyCook pastiin nggak ada bahan\n makanan yang terbuang sia-sia. Masak\n lebih terjadwal, hidup lebih maksimal.',
              style: TextStyle(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            SizedBox(
              height: screenheight * 0.166,
            )
          ],
        ),
        SafeArea(
          child: Align(
            alignment: Alignment(0.0, 0.92),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  padding: EdgeInsets.symmetric(
                      horizontal: screenwidth * 0.21,
                      vertical: screenheight * 0.01),
                  backgroundColor: AppColor().utama),
              onPressed: () {
                // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ))
              },
              child: Text(
                'Lets Cook',
                style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: AppColor().putih),
              ),
            ),
          ),
        )
      ],
    ));
  }
}
