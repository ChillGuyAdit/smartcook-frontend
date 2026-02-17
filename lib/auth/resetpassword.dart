import 'package:flutter/material.dart';
import 'package:smartcook/auth/animasisukses.dart';
import 'package:smartcook/helper/color.dart';
import 'package:smartcook/service/api_service.dart';

class resetpassword extends StatefulWidget {
  final String email;
  final String otp;
  const resetpassword({super.key, required this.email, required this.otp});

  @override
  State<resetpassword> createState() => _resetpasswordState();
}

class _resetpasswordState extends State<resetpassword> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();
  bool _obscuretext = true;
  bool _obscuretextConfirm = true;
  bool _loading = false;

  @override
  void dispose() {
    _passController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  void _submitReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final res = await ApiService.post(
      '/api/auth/reset-password',
      body: {
        'email': widget.email,
        'otp': widget.otp,
        'new_password': _passController.text,
      },
      useAuth: false,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (!res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message ?? 'Gagal reset password')),
      );
      return;
    }
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => animasisukses(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

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
              key: _formKey, // Pasang key di sini bray
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
                  passwordField(),
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
                  confirmPasswordField(),
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
                    onPressed: _loading ? null : _submitReset,
                    child: _loading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                      'Reset Password',
                      style: TextStyle(
                        color: AppColor().putih,
                        fontWeight: FontWeight.bold,
                        fontSize: 25,
                      ),
                    ),
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

  Widget passwordField() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25),
      child: TextFormField(
        controller: _passController,
        obscureText: _obscuretext,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return "Password wajib isi bray";
          }
          if (value.length < 8) {
            return "Password minimal 8 karakter";
          }
          return null;
        },
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

  Widget confirmPasswordField() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25),
      child: TextFormField(
        controller: _confirmPassController,
        obscureText: _obscuretextConfirm,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return "Konfirmasi password dulu bray";
          }
          if (value != _passController.text) {
            return "Password ngga sama, cek lagi bray";
          }
          return null;
        },
        decoration: InputDecoration(
          contentPadding: EdgeInsets.symmetric(vertical: 23),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          fillColor: AppColor().abuabu,
          hintText: 'Re-enter your password',
          filled: true,
          prefixIcon: Icon(Icons.lock, color: AppColor().hintTextColor),
          suffixIcon: IconButton(
            icon: Icon(
              _obscuretextConfirm ? Icons.visibility_off : Icons.visibility,
              color: AppColor().hintTextColor,
            ),
            onPressed: () {
              setState(() {
                _obscuretextConfirm = !_obscuretextConfirm;
              });
            },
          ),
        ),
      ),
    );
  }
}
