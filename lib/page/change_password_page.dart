import 'package:flutter/material.dart';
import 'package:smartcook/helper/color.dart';
import 'package:smartcook/service/api_service.dart';

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

  @override
  void dispose() {
    _currentController.dispose();
    _otpController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_sendingOtp) return;
    setState(() => _sendingOtp = true);
    final res =
        await ApiService.post('/api/user/password/send-otp', useAuth: true);
    if (!mounted) return;
    setState(() => _sendingOtp = false);
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
                            onPressed: _sendingOtp ? null : _sendOtp,
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
                                : const Text('Kirim OTP'),
                          ),
                        ],
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

