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
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.center,
            child: Image.asset('image/ob3.png'),
          ),
          Text(
            'Masak Lebih Praktis',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
          ),
          SizedBox(
            height: 10,
          ),
          Text(
            'Dari stok pasar sampai ke meja makan,\n SmartyCook pastiin nggak ada bahan\n makanan yang terbuang sia-sia. Masak\n lebih terjadwal, hidup lebih maksimal.',
            style: TextStyle(fontSize: 20),
            textAlign: TextAlign.center,
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
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
      ),
    );
  }
}
