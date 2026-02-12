import 'package:flutter/material.dart';
import 'package:smartcook/auth/mailpassoword.dart';
import 'package:smartcook/helper/color.dart';

class forgotpassowrd extends StatefulWidget {
  const forgotpassowrd({super.key});

  @override
  State<forgotpassowrd> createState() => _forgotpassowrdState();
}

class _forgotpassowrdState extends State<forgotpassowrd> {
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  void _handleSend() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      await Future.delayed(Duration(milliseconds: 500));

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => mailpassword()),
        ).then((_) {
          if (mounted) setState(() => _isLoading = false);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenheight = MediaQuery.of(context).size.height;
    final screenwidth = MediaQuery.of(context).size.width;

    double basewidth = 430;
    double scale = screenwidth / basewidth;
    return Scaffold(
      backgroundColor: AppColor().putih,
      appBar: AppBar(
        backgroundColor: AppColor().putih,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 50),
              Align(
                alignment: Alignment.center,
                child: Image.asset('image/password.png'),
              ),
              SizedBox(height: 24),
              Text(
                "Lupa Password?",
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 14),
              Text(
                "Jangan khawatir! Masukkan alamat email Anda. Dan kami akan\nmemberikan instruksi untuk mengatur ulang password",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12 * scale),
              ),
              SizedBox(height: 32),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 50),
                child: TextFormField(
                  controller: _emailController,
                  enabled: !_isLoading,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Email wajib diisi";
                    }
                    if (!value.contains("@")) {
                      return "Email harus ada simbol '@'";
                    }
                    if (!value.contains(".com")) {
                      return "Email harus diakhiri dengan '.com'";
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: 'Email',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    hintText: 'smartcook@gmail.com',
                    suffixIcon: Icon(
                      Icons.mail,
                      color: AppColor().hintTextColor,
                    ),
                    errorStyle: TextStyle(color: Colors.red, fontSize: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    fillColor: AppColor().putih,
                    filled: true,
                  ),
                ),
              ),
              SizedBox(height: 25),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleSend,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  backgroundColor: AppColor().utama,
                  padding: EdgeInsets.symmetric(
                      horizontal: 135 * scale, vertical: 12 * scale),
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 30,
                        width: 30,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : Text(
                        'Send',
                        style: TextStyle(
                          color: AppColor().putih,
                          fontWeight: FontWeight.bold,
                          fontSize: 30 * scale,
                        ),
                      ),
              ),
              SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
