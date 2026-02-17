import 'package:flutter/material.dart';
import 'package:smartcook/helper/color.dart';
import 'package:smartcook/service/api_service.dart';
import 'package:smartcook/service/token_service.dart';

class ChangeEmailPage extends StatefulWidget {
  const ChangeEmailPage({super.key});

  @override
  State<ChangeEmailPage> createState() => _ChangeEmailPageState();
}

class _ChangeEmailPageState extends State<ChangeEmailPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();

  bool _loadingSend = false;
  bool _loadingConfirm = false;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_loadingSend) return;
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email baru wajib diisi')),
      );
      return;
    }
    setState(() => _loadingSend = true);
    final res = await ApiService.post(
      '/api/user/email/send-otp',
      body: {'new_email': _emailController.text.trim()},
      useAuth: true,
    );
    if (!mounted) return;
    setState(() => _loadingSend = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          res.message ??
              (res.success
                  ? 'Kode OTP telah dikirim ke email kamu.'
                  : 'Gagal mengirim OTP'),
        ),
      ),
    );
  }

  Future<void> _confirm() async {
    if (_loadingConfirm) return;
    if (_otpController.text.trim().length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan 4 digit OTP')),
      );
      return;
    }
    setState(() => _loadingConfirm = true);
    final res = await ApiService.post(
      '/api/user/email/confirm',
      body: {'otp': _otpController.text.trim()},
      useAuth: true,
    );
    if (!mounted) return;
    setState(() => _loadingConfirm = false);
    if (!res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message ?? 'Gagal mengganti email')),
      );
      return;
    }

    // update user di local token service kalau backend kirim user baru
    if (res.data is Map<String, dynamic>) {
      await TokenService.saveUser(res.data as Map<String, dynamic>);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Email berhasil diubah')),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final baseWidth = 430.0;
    final scale = MediaQuery.of(context).size.width / baseWidth;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ganti Email'),
        backgroundColor: AppColor().utama,
      ),
      body: Padding(
        padding: EdgeInsets.all(20 * scale),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email baru'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Email baru wajib diisi';
                  }
                  if (!v.contains('@') || !v.contains('.')) {
                    return 'Format email tidak valid';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16 * scale),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Kode OTP (4 digit)'),
                    ),
                  ),
                  SizedBox(width: 12 * scale),
                  ElevatedButton(
                    onPressed: _loadingSend ? null : _sendOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColor().utama,
                    ),
                    child: _loadingSend
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Kirim OTP'),
                  ),
                ],
              ),
              SizedBox(height: 24 * scale),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loadingConfirm ? null : _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColor().utama,
                    padding: EdgeInsets.symmetric(vertical: 14 * scale),
                  ),
                  child: _loadingConfirm
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Konfirmasi Email'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

