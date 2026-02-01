import 'package:flutter/material.dart';
import 'package:smartcook/auth/forgotpassword.dart';
import 'package:smartcook/auth/signUp.dart';
import 'package:smartcook/helper/color.dart';
import 'package:smartcook/service/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smartcook/view/onboarding/mainBoarding.dart';

class signin extends StatefulWidget {
  const signin({super.key});

  @override
  State<signin> createState() => _signinState();
}

class _signinState extends State<signin> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  TextEditingController _kontrolEmail = TextEditingController();
  TextEditingController _kontrolPassword = TextEditingController();
  FocusNode _focusNode1 = FocusNode();
  FocusNode _focusNode2 = FocusNode();

  @override
  void dispose() {
    _kontrolEmail.dispose();
    _kontrolPassword.dispose();
    _focusNode1.dispose();
    _focusNode2.dispose();
    super.dispose();
  }

  bool _obscuretext = true;

  void _submitData() {
    if (_formKey.currentState!.validate()) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => onboarding()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenheight = MediaQuery.of(context).size.height;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 100),
                  Container(
                    height: 400,
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
                          key: _formKey,
                          child: Column(
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
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => forgotpassowrd(),
                                  ),
                                );
                              },
                              child: Text(
                                'Lupa Password?',
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
                          onPressed: _submitData,
                          child: Text(
                            'SignIn',
                            style: TextStyle(
                              color: AppColor().putih,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 50),
                  bagianOr(),
                  SizedBox(height: 40),
                  auth(),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: screenheight * 0.01),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Belum punya akun ?', style: TextStyle(fontSize: 15)),
                SizedBox(width: 6),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, anim1, anim2) => signup(),
                        transitionDuration: Duration.zero,
                      ),
                    );
                  },
                  child: Row(
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
          ),
        ],
      ),
    );
  }

  Widget email() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 31),
      child: TextFormField(
        controller: _kontrolEmail,
        focusNode: _focusNode1,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        onFieldSubmitted: (v) =>
            FocusScope.of(context).requestFocus(_focusNode2),
        validator: (value) {
          if (value == null || value.isEmpty) return "Wajib isi bray";
          if (!value.contains("@") ||
              !value.contains("gmail") ||
              !value.contains(".com")) {
            return "Email ngga valid bray";
          }
          return null;
        },
        decoration: InputDecoration(
          errorStyle: TextStyle(height: 0, fontSize: 10),
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
        controller: _kontrolPassword,
        focusNode: _focusNode2,
        obscureText: _obscuretext,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        onFieldSubmitted: (v) => _submitData(),
        validator: (value) {
          if (value == null || value.isEmpty) return "Wajib isi bray";
          if (value.length < 8) return "Minimal 8 karakter";
          return null;
        },
        decoration: InputDecoration(
          errorStyle: TextStyle(height: 0, fontSize: 10),
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
            onPressed: () => setState(() => _obscuretext = !_obscuretext),
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
        Container(height: 1, width: 100, color: AppColor().hintTextColor),
        SizedBox(width: 10),
        Text('Or',
            style: TextStyle(color: AppColor().hintTextColor, fontSize: 18)),
        SizedBox(width: 10),
        Container(height: 1, width: 100, color: AppColor().hintTextColor),
      ],
    );
  }

  Widget auth() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        InkWell(
          onTap: () async {
            UserCredential? userCredential =
                await _authService.signinWithGoogle();
            if (userCredential != null) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => onboarding()),
              );
            }
          },
          child: Image.asset('image/google.png'),
        ),
        SizedBox(width: 40),
        Image.asset('image/apple.png'),
      ],
    );
  }
}
