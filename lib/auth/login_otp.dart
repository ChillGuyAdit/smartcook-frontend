import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smartcook/helper/color.dart';
import 'package:smartcook/page/homepage.dart';
import 'package:smartcook/service/api_service.dart';
import 'package:smartcook/service/otp_cooldown_service.dart';
import 'package:smartcook/service/token_service.dart';
import 'package:smartcook/view/onboarding/mainBoarding.dart';

class LoginOtpPage extends StatefulWidget {
  final String email;
  final int? initialExpirySeconds;

  const LoginOtpPage({
    super.key,
    required this.email,
    this.initialExpirySeconds,
  });

  @override
  State<LoginOtpPage> createState() => _LoginOtpPageState();
}

class _LoginOtpPageState extends State<LoginOtpPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final List<TextEditingController> _otpControllers =
      List.generate(4, (_) => TextEditingController());
  final TextEditingController _passwordController = TextEditingController();

  bool _loading = false;
  bool _showNewPassword = false;
  bool _obscureNewPassword = true;
  String? _errorMessage;
  int _expirySeconds = 0;
  int _resendCooldownSeconds = 0;
  Timer? _timer;

  @override
  void dispose() {
    for (final c in _otpControllers) {
      c.dispose();
    }
    _passwordController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initTimers();
  }

  Future<void> _initTimers() async {
    final key = 'login:${widget.email}';
    int expiry = widget.initialExpirySeconds ?? 0;
    if (expiry <= 0) {
      expiry = await OtpCooldownService.getRemainingExpiry(key);
    } else {
      await OtpCooldownService.setExpiry(key, expiry);
    }
    final cooldown = await OtpCooldownService.getRemainingCooldown(key);
    setState(() {
      _expirySeconds = expiry;
      _resendCooldownSeconds = cooldown;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_expirySeconds > 0) _expirySeconds--;
        if (_resendCooldownSeconds > 0) _resendCooldownSeconds--;
      });
    });
  }

  Future<void> _handleAfterLogin(Map<String, dynamic>? user) async {
    final onboardingCompleted = user?['onboarding_completed'] == true;
    if (!mounted) return;
    if (onboardingCompleted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => homepage()),
        (route) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => onboarding()),
        (route) => false,
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan 4 digit kode OTP')),
      );
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final body = <String, dynamic>{
      'email': widget.email.trim(),
      'otp': otp,
    };
    if (_showNewPassword && _passwordController.text.isNotEmpty) {
      body['new_password'] = _passwordController.text;
    }

    final res = await ApiService.post(
      '/api/auth/login-otp-verify',
      body: body,
      useAuth: false,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!res.success) {
      setState(() {
        _errorMessage = res.message ?? 'Verifikasi OTP gagal';
      });
      return;
    }

    final data = res.data as Map<String, dynamic>?;
    final token = data?['token'] as String?;
    final user = data?['user'] as Map<String, dynamic>?;
    final mustChangePassword = data?['must_change_password'] == true;

    if (token != null && token.isNotEmpty) {
      await TokenService.saveToken(token);
    }
    if (user != null) {
      await TokenService.saveUser(user);
    }

    if (mustChangePassword && !_showNewPassword) {
      setState(() {
        _showNewPassword = true;
        _errorMessage = 'OTP terverifikasi. Silakan buat password baru.';
      });
      return;
    }

    await _handleAfterLogin(user);
  }

  Future<void> _resendOtp() async {
    if (_loading || _resendCooldownSeconds > 0) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final res = await ApiService.post(
      '/api/auth/login-otp-resend',
      body: {'email': widget.email.trim()},
      useAuth: false,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!res.success) {
      int? retryAfter;
      if (res.code == 'OTP_SEND_RATE_LIMIT' && res.data is Map<String, dynamic>) {
        final data = res.data as Map<String, dynamic>;
        final ra = data['retry_after_seconds'];
        if (ra is num && ra > 0) {
          retryAfter = ra.toInt();
        }
      }
      if (retryAfter != null) {
        final key = 'login:${widget.email}';
        await OtpCooldownService.setCooldown(key, retryAfter);
        setState(() => _resendCooldownSeconds = retryAfter!);
      }
      setState(() {
        _errorMessage = res.message ?? 'Gagal mengirim ulang OTP';
      });
      return;
    }

    int expirySec = 600;
    if (res.data is Map<String, dynamic>) {
      final data = res.data as Map<String, dynamic>;
      final expires = data['expires_in_seconds'];
      if (expires is num && expires > 0) {
        expirySec = expires.toInt();
      }
    }

    final key = 'login:${widget.email}';
    await OtpCooldownService.setCooldown(key, 60);
    await OtpCooldownService.setExpiry(key, expirySec);

    setState(() {
      _resendCooldownSeconds = 60;
      _expirySeconds = expirySec;
      _errorMessage = 'Kode OTP baru telah dikirim.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenwidth = MediaQuery.of(context).size.width;

    double basewidth = 430;
    double scale = screenwidth / basewidth;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 50),
              Align(
                alignment: Alignment.center,
                child: Image.asset('image/mail.png'),
              ),
              const SizedBox(height: 46),
              const Text(
                'Check your email',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              Text.rich(
                TextSpan(
                  text: "Kami mengirim 4 digit kode ke\n",
                  style: const TextStyle(fontSize: 12),
                  children: [
                    TextSpan(
                      text: widget.email,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              if (_expirySeconds > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('⏰ '),
                    Text(
                      'Kode akan expired dalam ${OtpCooldownService.formatSeconds(_expirySeconds)}',
                      style: TextStyle(fontSize: 12 * scale),
                    ),
                  ],
                ),
              ] else ...[
                const Text(
                  'Kode OTP sudah expired. Kirim ulang OTP.',
                  style: TextStyle(fontSize: 12, color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 12 * scale,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _otpBox(context, 0, true, false),
                    _otpBox(context, 1, false, false),
                    _otpBox(context, 2, false, false),
                    _otpBox(context, 3, false, true),
                  ],
                ),
              ),
              if (_showNewPassword) ...[
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: TextFormField(
                    controller: _passwordController,
                    obscureText: _obscureNewPassword,
                    decoration: InputDecoration(
                      labelText: 'Password baru',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNewPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureNewPassword = !_obscureNewPassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (!_showNewPassword) return null;
                      if (value == null || value.isEmpty) {
                        return 'Password baru wajib diisi';
                      }
                      if (value.length < 6) {
                        return 'Password minimal 6 karakter';
                      }
                      return null;
                    },
                  ),
                ),
              ],
              const SizedBox(height: 25),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColor().utama,
                  padding:
                      EdgeInsets.symmetric(horizontal: 110 * scale, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 30,
                        width: 30,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : const Text(
                        "Verify",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 25,
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed:
                    _loading || _resendCooldownSeconds > 0 ? null : _resendOtp,
                child: Text(
                  _resendCooldownSeconds > 0
                      ? 'Resend OTP (${_resendCooldownSeconds}s)'
                      : 'Resend OTP',
                ),
              ),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _otpBox(BuildContext context, int index, bool first, bool last) {
    return SizedBox(
      width: 70,
      height: 70,
      child: TextFormField(
        controller: _otpControllers[index],
        enabled: !_loading,
        onChanged: (value) {
          if (value.length == 1 && !last) {
            FocusScope.of(context).nextFocus();
          }
          if (value.isEmpty && !first) {
            FocusScope.of(context).previousFocus();
          }
        },
        validator: (value) {
          if (value == null || value.isEmpty) return "";
          return null;
        },
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.normal),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        maxLength: 1,
        decoration: InputDecoration(
          counterText: "",
          errorStyle: const TextStyle(height: 0),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          fillColor: const Color(0xFFD9D9D9),
          filled: true,
        ),
      ),
    );
  }
}

