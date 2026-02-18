import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smartcook/helper/color.dart';
import 'package:smartcook/service/api_service.dart';
import 'package:smartcook/service/otp_cooldown_service.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  bool _useOtp = false;
  bool _loading = false;
  bool _sendingOtp = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _otpController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  int _otpCooldownSeconds = 0;
  Timer? _otpTimer;
  int _expirySeconds = 0;

  @override
  void dispose() {
    _currentController.dispose();
    _otpController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    _otpTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initTimers();
  }

  Future<void> _initTimers() async {
    // Di profile, email aktif bisa diambil dari TokenService user (kalau mau),
    // untuk sekarang pakai key global tanpa email agar tetap satu sumber.
    const key = 'profile_pw';
    final cooldown = await OtpCooldownService.getRemainingCooldown(key);
    final expiry = await OtpCooldownService.getRemainingExpiry(key);
    setState(() {
      _otpCooldownSeconds = cooldown;
      _expirySeconds = expiry;
    });
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_otpCooldownSeconds > 0) _otpCooldownSeconds--;
        if (_expirySeconds > 0) _expirySeconds--;
      });
    });
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

  Future<void> _sendOtp() async {
    if (_sendingOtp || _otpCooldownSeconds > 0) return;
    setState(() => _sendingOtp = true);
    final res =
        await ApiService.post('/api/user/password/send-otp', useAuth: true);
    if (!mounted) return;
    setState(() => _sendingOtp = false);
    String baseMessage = res.message ??
        (res.success
            ? 'Kode OTP telah dikirim ke email kamu.'
            : 'Gagal mengirim OTP');

    const key = 'profile_pw';

    if (res.data is Map<String, dynamic>) {
      final data = res.data as Map<String, dynamic>;
      final expiresSec = data['expires_in_seconds'];
      if (expiresSec is num && expiresSec > 0) {
        final minutes = (expiresSec / 60).ceil();
        baseMessage =
            '$baseMessage Kode berlaku sekitar $minutes menit.';
        await OtpCooldownService.setExpiry(key, expiresSec.toInt());
        setState(() => _expirySeconds = expiresSec.toInt());
      }

      int? retryAfter;
      final ra = data['retry_after_seconds'];
      if (ra is num && ra > 0) {
        retryAfter = ra.toInt();
      }
      final cooldown = retryAfter ?? 60;
      await OtpCooldownService.setCooldown(key, cooldown);
      _startOtpCooldown(cooldown);
    } else if (res.success) {
      await OtpCooldownService.setCooldown(key, 60);
      _startOtpCooldown(60);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(baseMessage),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final body = <String, dynamic>{
      'new_password': _newController.text,
    };

    if (_useOtp) {
      body['otp'] = _otpController.text.trim();
    } else {
      body['current_password'] = _currentController.text;
    }

    final res = await ApiService.post(
      '/api/user/password/change',
      body: body,
      useAuth: true,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message ?? 'Gagal mengganti password')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password berhasil diubah')),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final baseWidth = 430.0;
    final scale = MediaQuery.of(context).size.width / baseWidth;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ubah Password'),
        backgroundColor: AppColor().utama,
      ),
      body: Padding(
        padding: EdgeInsets.all(20 * scale),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ToggleButtons(
                isSelected: [_useOtp == false, _useOtp == true],
                onPressed: (index) {
                  setState(() {
                    _useOtp = index == 1;
                  });
                },
                borderRadius: BorderRadius.circular(12 * scale),
                selectedColor: AppColor().putih,
                fillColor: AppColor().utama,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 12 * scale, vertical: 8 * scale),
                    child: const Text('Pakai password lama'),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 12 * scale, vertical: 8 * scale),
                    child: const Text('Pakai OTP email'),
                  ),
                ],
              ),
              SizedBox(height: 20 * scale),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (!_useOtp) ...[
                      TextFormField(
                        controller: _currentController,
                        obscureText: _obscureCurrent,
                        decoration: InputDecoration(
                          labelText: 'Password lama',
                          suffixIcon: IconButton(
                            icon: Icon(_obscureCurrent
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () {
                              setState(() {
                                _obscureCurrent = !_obscureCurrent;
                              });
                            },
                          ),
                        ),
                        validator: (v) {
                          if (!_useOtp && (v == null || v.isEmpty)) {
                            return 'Password lama wajib diisi';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16 * scale),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _otpController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'Kode OTP (4 digit)'),
                              validator: (v) {
                                if (_useOtp &&
                                    (v == null || v.trim().length != 4)) {
                                  return 'Masukkan 4 digit OTP';
                                }
                                return null;
                              },
                            ),
                          ),
                          SizedBox(width: 12 * scale),
                          ElevatedButton(
                            onPressed: _sendingOtp || _otpCooldownSeconds > 0
                                ? null
                                : _sendOtp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColor().utama,
                            ),
                            child: _sendingOtp
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _otpCooldownSeconds > 0
                                        ? 'Kirim OTP (${_otpCooldownSeconds}s)'
                                        : 'Kirim OTP',
                                  ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8 * scale),
                      if (_expirySeconds > 0)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '⏰ OTP akan expired dalam ${OtpCooldownService.formatSeconds(_expirySeconds)}',
                            style: TextStyle(
                              fontSize: 12 * scale,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      SizedBox(height: 16 * scale),
                    ],
                    TextFormField(
                      controller: _newController,
                      obscureText: _obscureNew,
                      decoration: InputDecoration(
                        labelText: 'Password baru',
                        suffixIcon: IconButton(
                          icon: Icon(_obscureNew
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () {
                            setState(() {
                              _obscureNew = !_obscureNew;
                            });
                          },
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Password baru wajib diisi';
                        }
                        if (v.length < 6) {
                          return 'Minimal 6 karakter';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16 * scale),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: _obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Konfirmasi password baru',
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirm
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () {
                            setState(() {
                              _obscureConfirm = !_obscureConfirm;
                            });
                          },
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Konfirmasi password wajib diisi';
                        }
                        if (v != _newController.text) {
                          return 'Konfirmasi password tidak sama';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 24 * scale),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColor().utama,
                          padding:
                              EdgeInsets.symmetric(vertical: 14 * scale),
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Simpan Password'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

