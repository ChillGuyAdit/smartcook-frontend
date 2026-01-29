import 'package:flutter/material.dart';
import 'package:smartcook/auth/signIn.dart';
import 'package:smartcook/helper/color.dart';
import 'package:smartcook/page/homepage.dart';

class signup extends StatefulWidget {
  const signup({super.key});

  @override
  State<signup> createState() => _signupState();
}

class _signupState extends State<signup> {
  bool _obscuretext = true;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        child: Center(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 75),
                Container(
                  height: 420,
                  width: 362,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(74),
                      bottomLeft: Radius.circular(56),
                    ),
                    color: AppColor().hijauPucat,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(left: 30),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            "Sign Up",
                            style: TextStyle(
                              color: AppColor().hintTextColor,
                              fontSize: 35,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 39),
                      Form(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            username(),
                            SizedBox(height: 11),
                            email(),
                            SizedBox(height: 11),
                            password(),
                          ],
                        ),
                      ),
                      SizedBox(height: 33),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 90,
                            vertical: 12,
                          ),
                          backgroundColor: AppColor().utama,
                        ),
                        child: Text(
                          'Sign Up',
                          style: TextStyle(
                            color: AppColor().putih,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (context, anim1, anim2) =>
                                  homepage(),
                              transitionDuration: Duration.zero,
                              reverseTransitionDuration: Duration.zero,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 83),
                bagianOr(),
                SizedBox(height: 76),
                auth(),
                SizedBox(height: 113),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Sudah punya akun ?', style: TextStyle(fontSize: 15)),
                    SizedBox(width: 6),
                    TextButton(
                      style: TextButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                      ),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (context, anim1, anim2) => signin(),
                            transitionDuration: Duration.zero,
                            reverseTransitionDuration: Duration.zero,
                          ),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Signin',
                            style: TextStyle(
                              color: AppColor().utama,
                              fontSize: 15,
                            ),
                          ),
                          Image.asset(
                            'image/starLogo.png',
                            height: 27.51,
                            width: 27,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget username() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 31),
      child: TextFormField(
        decoration: InputDecoration(
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          fillColor: Color(0xFFFFFFFF),
          prefixIcon: Icon(Icons.person, color: AppColor().hintTextColor),
          hintText: 'Masukkan Namamu',
          hintStyle: TextStyle(color: AppColor().hintTextColor),
        ),
      ),
    );
  }

  Widget email() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 31),
      child: TextFormField(
        decoration: InputDecoration(
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          fillColor: Color(0xFFFFFFFF),
          prefixIcon: Icon(Icons.mail, color: AppColor().hintTextColor),
          hintText: 'Masukkan Emailmu',
          hintStyle: TextStyle(color: AppColor().hintTextColor),
        ),
      ),
    );
  }

  Widget password() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 31),
      child: TextFormField(
        obscureText: _obscuretext,
        decoration: InputDecoration(
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          fillColor: Color(0xFFFFFFFF),
          prefixIcon: Icon(Icons.lock, color: AppColor().hintTextColor),
          suffixIcon: IconButton(
            icon: Icon(
              _obscuretext ? Icons.visibility_off : Icons.visibility,
              color: AppColor().hintTextColor,
            ),
            onPressed: () {
              setState(() {
                _obscuretext = !_obscuretext;
              });
            },
          ),
          hintText: 'Masukkan Password',
          hintStyle: TextStyle(color: AppColor().hintTextColor),
        ),
      ),
    );
  }

  Widget bagianOr() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(height: 1, width: 120, color: AppColor().hintTextColor),
        SizedBox(width: 10),
        Text(
          'Or',
          style: TextStyle(color: AppColor().hintTextColor, fontSize: 20),
        ),
        SizedBox(width: 10),
        Container(height: 1, width: 120, color: AppColor().hintTextColor),
      ],
    );
  }

  Widget auth() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image(image: AssetImage('image/google.png')),
        SizedBox(width: 43),
        Image(image: AssetImage('image/apple.png')),
      ],
    );
  }
}
