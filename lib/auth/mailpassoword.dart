import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smartcook/auth/resetpassword.dart';
import 'package:smartcook/helper/color.dart';
import 'package:smartcook/service/api_service.dart';
import 'package:smartcook/service/otp_cooldown_service.dart';

class mailpassword extends StatefulWidget {
  final String email;
  const mailpassword({super.key, required this.email});

  @override
  State<mailpassword> createState() => _mailpasswordState();
}

class _mailpasswordState extends State<mailpassword> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final List<TextEditingController> _otpControllers =
      List.generate(4, (_) => TextEditingController());

  int _expirySeconds = 0;
  int _resendCooldownSeconds = 0;
  Timer? _timer;

  @override
  void dispose() {
    for (final c in _otpControllers) c.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initTimers();
  }

  Future<void> _initTimers() async {
    final key = 'forgot:${widget.email}';
    final expiry = await OtpCooldownService.getRemainingExpiry(key);
    final cooldown = await OtpCooldownService.getRemainingCooldown(key);
    if (mounted) setState(() {
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

  void _validateAndSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan 4 digit kode OTP')),
      );
      return;
    }
    setState(() => _isLoading = true);
    final res = await ApiService.post(
      '/api/auth/verify-otp',
      body: {'email': widget.email, 'otp': otp},
      useAuth: false,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (!res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message ?? 'Kode OTP tidak valid')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => resetpassword(email: widget.email, otp: otp),
      ),
    );
  }

  Future<void> _resendOtp() async {
    if (_isLoading || _resendCooldownSeconds > 0) return;
    setState(() => _isLoading = true);
    final res = await ApiService.post(
      '/api/auth/forgot-password',
      body: {'email': widget.email},
      useAuth: false,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!res.success) {
      // Jika kena rate limit, gunakan retry_after_seconds
      int? retryAfter;
      if (res.code == 'OTP_SEND_RATE_LIMIT' && res.data is Map<String, dynamic>) {
        final data = res.data as Map<String, dynamic>;
        final ra = data['retry_after_seconds'];
        if (ra is num && ra > 0) {
          retryAfter = ra.toInt();
        }
      }
      if (retryAfter != null) {
        final key = 'forgot:${widget.email}';
        await OtpCooldownService.setCooldown(key, retryAfter);
        if (mounted) setState(() => _resendCooldownSeconds = retryAfter!);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message ?? 'Gagal mengirim ulang OTP')),
      );
      return;
    }

    // Sukses kirim OTP baru
    int expirySec = 600;
    if (res.data is Map<String, dynamic>) {
      final data = res.data as Map<String, dynamic>;
      final expires = data['expires_in_seconds'];
      if (expires is num && expires > 0) {
        expirySec = expires.toInt();
      }
    }
    final key = 'forgot:${widget.email}';
    await OtpCooldownService.setCooldown(key, 60);
    await OtpCooldownService.setExpiry(key, expirySec);
    if (mounted) setState(() {
      _resendCooldownSeconds = 60;
      _expirySeconds = expirySec;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kode OTP baru telah dikirim')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back_ios_new),
        ),
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 50),
              Align(
                alignment: Alignment.center,
                child: Image.asset('image/mail.png'),
              ),
              SizedBox(height: 46),
              Text(
                'Check your email',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 14),
              Text.rich(
                TextSpan(
                  text: "Kami mengirim 4 digit kode ke\n",
                  style: TextStyle(fontSize: 12),
                  children: [
                    TextSpan(
                      text: widget.email,
                      style: TextStyle(
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
                      style: const TextStyle(fontSize: 12),
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
              SizedBox(height: 40),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
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
              SizedBox(height: 25),
              ElevatedButton(
                onPressed: _isLoading ? null : _validateAndSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColor().utama,
                  padding: EdgeInsets.symmetric(horizontal: 110, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
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
                    _isLoading || _resendCooldownSeconds > 0 ? null : _resendOtp,
                child: Text(
                  _resendCooldownSeconds > 0
                      ? 'Resend OTP (${_resendCooldownSeconds}s)'
                      : 'Resend OTP',
                ),
              ),
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
        enabled: !_isLoading,
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
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.normal),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        maxLength: 1,
        decoration: InputDecoration(
          counterText: "",
          errorStyle: TextStyle(height: 0),
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
          fillColor: Color(0xFFD9D9D9),
          filled: true,
        ),
      ),
    );
  }
}
