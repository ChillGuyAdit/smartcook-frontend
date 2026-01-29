import 'package:flutter/material.dart';
import 'package:smartcook/auth/forgotpassword.dart';
import 'package:smartcook/auth/signUp.dart';
import 'package:smartcook/helper/color.dart';
import 'package:smartcook/page/homepage.dart';

class signin extends StatefulWidget {
  const signin({super.key});

  @override
  State<signin> createState() => _signinState();
}

class _signinState extends State<signin> {
  bool _obscuretext = true;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        height: double.infinity,
        width: double.infinity,
        child: Center(
          child: SingleChildScrollView(
            physics: NeverScrollableScrollPhysics(),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 80),
                Container(
                  height: 360,
                  width: 362,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(56),
                      topRight: Radius.circular(74),
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
                            'SignIn',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 35,
                              color: AppColor().hintTextColor,
                            ),
                          ),
                        ),
                      ),
                      Form(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(height: 46),
                            email(),
                            SizedBox(height: 10),
                            password(),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(right: 35),
                        child: Align(
                          alignment: Alignment.bottomRight,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => forgotpassowrd(),
                                ),
                              );
                            },
                            child: Text(
                              'Forgot Passowrd?',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColor().hintTextColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 17),
                      ElevatedButton(
                        child: Text(
                          'SignIn',
                          style: TextStyle(
                            color: AppColor().putih,
                            fontWeight: .bold,
                            fontSize: 20,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          backgroundColor: AppColor().utama,
                          padding: EdgeInsets.symmetric(
                            horizontal: 95,
                            vertical: 10,
                          ),
                        ),
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => homepage()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 93),
                bagianOr(),
                SizedBox(height: 85),
                auth(),
                SizedBox(height: 154),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Belum punya akun ?', style: TextStyle(fontSize: 15)),
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
                            pageBuilder: (context, anim1, anim2) => signup(),
                            transitionDuration: Duration.zero,
                            reverseTransitionDuration: Duration.zero,
                          ),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'SignUp',
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
