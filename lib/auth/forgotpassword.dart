import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smartcook/auth/mailpassoword.dart';
import 'package:smartcook/helper/color.dart';
import 'package:smartcook/service/api_service.dart';

class forgotpassowrd extends StatefulWidget {
  const forgotpassowrd({super.key});

  @override
  State<forgotpassowrd> createState() => _forgotpassowrdState();
}

class _forgotpassowrdState extends State<forgotpassowrd> {
  bool _isLoading = false;
  int _otpCooldownSeconds = 0;
  Timer? _otpTimer;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _otpTimer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  void _startOtpCooldown(int seconds) {
    _otpTimer?.cancel();
    setState(() {
      _otpCooldownSeconds = seconds;
    });
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_otpCooldownSeconds > 1) {
          _otpCooldownSeconds--;
        } else {
          _otpCooldownSeconds = 0;
          timer.cancel();
        }
      });
    });
  }

  void _handleSend() async {
    if (!_formKey.currentState!.validate()) return;
    if (_otpCooldownSeconds > 0) return;

    setState(() => _isLoading = true);
    final email = _emailController.text.trim();
    final res = await ApiService.post(
      '/api/auth/forgot-password',
      body: {'email': email},
      useAuth: false,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!res.success) {
      // Jika kena rate limit kirim OTP, gunakan retry_after_seconds untuk cooldown
      int? retryAfter;
      if (res.code == 'OTP_SEND_RATE_LIMIT' && res.data is Map<String, dynamic>) {
        final data = res.data as Map<String, dynamic>;
        final v = data['retry_after_seconds'];
        if (v is num && v > 0) {
          retryAfter = v.toInt();
        }
      }
      if (retryAfter != null) {
        _startOtpCooldown(retryAfter);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message ?? 'Gagal mengirim kode')),
      );
      return;
    }

    // Sukses kirim OTP: mulai cooldown 60 detik
    _startOtpCooldown(60);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => mailpassword(email: email),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                onPressed:
                    _isLoading || _otpCooldownSeconds > 0 ? null : _handleSend,
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
                        _otpCooldownSeconds > 0
                            ? 'Send (${_otpCooldownSeconds}s)'
                            : 'Send',
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
