import 'package:flutter/material.dart';
import 'package:smartcook/auth/signIn.dart';
import 'package:smartcook/helper/color.dart';
import 'package:smartcook/page/homepage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smartcook/service/auth_service.dart';
import 'package:smartcook/view/onboarding/mainBoarding.dart';

class signup extends StatefulWidget {
  signup({super.key});

  @override
  State<signup> createState() => _signupState();
}

class _signupState extends State<signup> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  TextEditingController _kontrolUsername = TextEditingController();
  TextEditingController _kontrolEmail = TextEditingController();
  TextEditingController _kontrolPassword = TextEditingController();

  FocusNode _focusNode1 = FocusNode();
  FocusNode _focusNode2 = FocusNode();
  FocusNode _focusNode3 = FocusNode();

  bool _obscuretext = true;

  @override
  void dispose() {
    _kontrolUsername.dispose();
    _kontrolEmail.dispose();
    _kontrolPassword.dispose();
    _focusNode1.dispose();
    _focusNode2.dispose();
    _focusNode3.dispose();
    super.dispose();
  }

  void _submitData() {
    if (_formKey.currentState!.validate()) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, anim1, anim2) => onboarding(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    double baseWidth = 430;
    double scale = screenWidth / baseWidth;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        width: screenWidth,
        height: screenHeight,
        child: Center(
          child: SingleChildScrollView(
            physics: NeverScrollableScrollPhysics(),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 60 * scale),
                Container(
                  height: 460 * scale,
                  width: 380 * scale,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(80 * scale),
                      bottomLeft: Radius.circular(60 * scale),
                    ),
                    color: AppColor().hijauPucat,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(left: 35 * scale),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            "Sign Up",
                            style: TextStyle(
                              color: AppColor().hintTextColor,
                              fontSize: 38 * scale,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 30 * scale),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            inputField(
                                _kontrolUsername,
                                _focusNode1,
                                _focusNode2,
                                Icons.person,
                                'Masukkan Namamu',
                                scale,
                                false),
                            SizedBox(height: 15 * scale),
                            inputField(_kontrolEmail, _focusNode2, _focusNode3,
                                Icons.mail, 'Masukkan Emailmu', scale, false),
                            SizedBox(height: 15 * scale),
                            inputField(_kontrolPassword, _focusNode3, null,
                                Icons.lock, 'Masukkan Password', scale, true),
                          ],
                        ),
                      ),
                      SizedBox(height: 35 * scale),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12 * scale),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 100 * scale,
                            vertical: 15 * scale,
                          ),
                          backgroundColor: AppColor().utama,
                        ),
                        child: Text(
                          'Sign Up',
                          style: TextStyle(
                            color: AppColor().putih,
                            fontSize: 22 * scale,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: _submitData,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 60 * scale),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                        height: 1.5,
                        width: 130 * scale,
                        color: AppColor().hintTextColor),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10 * scale),
                      child: Text('Or',
                          style: TextStyle(
                              color: AppColor().hintTextColor,
                              fontSize: 22 * scale)),
                    ),
                    Container(
                        height: 1.5,
                        width: 130 * scale,
                        color: AppColor().hintTextColor),
                  ],
                ),
                SizedBox(height: 50 * scale),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    /* DOKUMENTASI GOOGLE SIGN IN:
                       1. Image Google dibungkus InkWell (onTap aja nanti).
                       2. pas diklik nanti, manggilin fungsi signinWithGoogle dari AuthService.
                       3.'await' buat proses login yang bersifat asinkron (butuh waktu).
                       4. Jika variabel 'userCredential' tidak null (login sukses), user otomatis diarahkan ke onBoardingnya.
                       5. pushReplacement digunakan agar user tidak bisa kembali ke halaman signup menggunakan tombol back.
                    */
                    InkWell(
                      onTap: () async {
                        UserCredential? userCredential =
                            await _authService.signinWithGoogle();
                        if (userCredential != null) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => onboarding()),
                          );
                        }
                      },
                      child: Image(
                        image: AssetImage('image/google.png'),
                        width: 65 * scale,
                        height: 65 * scale,
                      ),
                    ),
                    SizedBox(width: 50 * scale),
                    Image(
                      image: AssetImage('image/apple.png'),
                      width: 65 * scale,
                      height: 65 * scale,
                    ),
                  ],
                ),
                SizedBox(height: 80 * scale),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Sudah punya akun ?',
                        style: TextStyle(fontSize: 17 * scale)),
                    SizedBox(width: 8 * scale),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                        children: [
                          Text(
                            'Signin',
                            style: TextStyle(
                              color: AppColor().utama,
                              fontSize: 17 * scale,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Image.asset(
                            'image/starLogo.png',
                            height: 30 * scale,
                            width: 30 * scale,
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

  Widget inputField(
      TextEditingController controller,
      FocusNode node,
      FocusNode? nextNode,
      IconData icon,
      String hint,
      double scale,
      bool isPassword) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 35 * scale),
      child: TextFormField(
        controller: controller,
        focusNode: node,
        obscureText: isPassword ? _obscuretext : false,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        onFieldSubmitted: (v) {
          if (nextNode != null) {
            FocusScope.of(context).requestFocus(nextNode);
          } else {
            _submitData();
          }
        },
        validator: (value) {
          if (value == null || value.isEmpty) return "Wajib isi bray";
          return null;
        },
        decoration: InputDecoration(
          errorStyle: TextStyle(height: 0, fontSize: 12 * scale),
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18 * scale),
            borderSide: BorderSide.none,
          ),
          fillColor: Color(0xFFFFFFFF),
          prefixIcon:
              Icon(icon, color: AppColor().hintTextColor, size: 26 * scale),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                      _obscuretext ? Icons.visibility_off : Icons.visibility,
                      color: AppColor().hintTextColor,
                      size: 26 * scale),
                  onPressed: () => setState(() => _obscuretext = !_obscuretext),
                )
              : null,
          hintText: hint,
          hintStyle:
              TextStyle(color: AppColor().hintTextColor, fontSize: 16 * scale),
        ),
      ),
    );
  }
}
