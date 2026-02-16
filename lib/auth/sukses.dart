import 'package:flutter/material.dart';
import 'package:smartcook/auth/signIn.dart';
import 'package:smartcook/helper/color.dart';

class sukses extends StatefulWidget {
  const sukses({super.key});

  @override
  State<sukses> createState() => _suksesState();
}

class _suksesState extends State<sukses> {
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
            child: Image.asset('image/suksesImage.png'),
          ),
          SizedBox(height: 22),
          Text(
            'Sukses!',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 35 * scale),
          ),
          SizedBox(height: 20 * scale),
          Text(
            'Selamat Anda berhasil mengganti password baru Anda\nKlik lanjutkan untuk masuk',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14 * scale),
          ),
          SizedBox(height: 25 * scale),
          ElevatedButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => signin()),
              );
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: EdgeInsets.symmetric(horizontal: 85, vertical: 10),
              backgroundColor: AppColor().utama,
            ),
            child: Text(
              'Lanjutkan',
              style: TextStyle(
                fontSize: 27.5 * scale,
                fontWeight: FontWeight.bold,
                color: AppColor().putih,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
