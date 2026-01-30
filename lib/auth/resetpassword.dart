import 'package:flutter/material.dart';
import 'package:smartcook/helper/color.dart';
import 'package:smartcook/auth/animasisukses.dart';

class resetpassword extends StatefulWidget {
  const resetpassword({super.key});

  @override
  State<resetpassword> createState() => _resetpasswordState();
}

class _resetpasswordState extends State<resetpassword> {
  bool _obscuretext = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 50),
            Align(
              alignment: AlignmentDirectional.center,
              child: Image.asset('image/gembok.png'),
            ),
            SizedBox(height: 40),
            Text(
              'Create new password',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 35),
            Form(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: 35),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text('Password', style: TextStyle(fontSize: 15)),
                    ),
                  ),
                  SizedBox(height: 7),
                  password(),
                  SizedBox(height: 25),
                  Padding(
                    padding: EdgeInsets.only(left: 35),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        'Konfirmasi Password',
                        style: TextStyle(fontSize: 15),
                      ),
                    ),
                  ),
                  SizedBox(height: 7),
                  confirmPassword(),
                  SizedBox(height: 30),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      backgroundColor: AppColor().utama,
                      padding: EdgeInsets.symmetric(
                        horizontal: 60,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      'Reset Password',
                      style: TextStyle(
                        color: AppColor().putih,
                        fontWeight: FontWeight.bold,
                        fontSize: 25,
                      ),
                    ),
                    onPressed: () {
                      // Navigasi pake Fade Animation bray
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  animasisukses(),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                          transitionDuration: Duration(milliseconds: 500),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget password() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25),
      child: TextFormField(
        obscureText: _obscuretext,
        decoration: InputDecoration(
          contentPadding: EdgeInsets.symmetric(vertical: 23),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          fillColor: AppColor().abuabu,
          hintText: 'Enter your password',
          filled: true,
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
        ),
      ),
    );
  }

  Widget confirmPassword() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25),
      child: TextFormField(
        obscureText: _obscuretext,
        decoration: InputDecoration(
          contentPadding: EdgeInsets.symmetric(vertical: 23),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          fillColor: AppColor().abuabu,
          hintText: 'Enter your password',
          filled: true,
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
        ),
      ),
    );
  }
}
