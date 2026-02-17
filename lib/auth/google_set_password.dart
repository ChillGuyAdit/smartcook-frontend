import 'package:flutter/material.dart';
import 'package:smartcook/helper/color.dart';
import 'package:smartcook/page/homepage.dart';
import 'package:smartcook/service/api_service.dart';
import 'package:smartcook/service/token_service.dart';
import 'package:smartcook/view/onboarding/mainBoarding.dart';

class GoogleSetPasswordPage extends StatefulWidget {
  const GoogleSetPasswordPage({super.key});

  @override
  State<GoogleSetPasswordPage> createState() => _GoogleSetPasswordPageState();
}

class _GoogleSetPasswordPageState extends State<GoogleSetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _email;

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
  }

  Future<void> _loadUserEmail() async {
    final user = await TokenService.getUser();
    if (!mounted) return;
    setState(() {
      _email = user?['email']?.toString();
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final res = await ApiService.post(
      '/api/auth/google/set-password',
      body: {
        'new_password': _passwordController.text,
        'confirm_password': _confirmController.text,
      },
      useAuth: true,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message ?? 'Gagal menyimpan password')),
      );
      return;
    }

    final data = res.data;
    if (data is! Map<String, dynamic>) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Format respons tidak valid')),
      );
      return;
    }

    final token = data['token'] as String?;
    final user = data['user'] as Map<String, dynamic>?;

    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token tidak ditemukan')),
      );
      return;
    }

    await TokenService.saveToken(token);
    if (user != null) {
      await TokenService.saveUser(user);
    }

    final onboardingCompleted = user?['onboarding_completed'] == true;
    if (!mounted) return;
    if (onboardingCompleted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const homepage()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const onboarding()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final baseWidth = 430.0;
    final scale = screenWidth / baseWidth;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Password'),
        backgroundColor: AppColor().utama,
      ),
      body: Padding(
        padding: EdgeInsets.all(24 * scale),
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Buat Password Baru',
                    style: TextStyle(
                      fontSize: 24 * scale,
                      fontWeight: FontWeight.bold,
                      color: AppColor().hintTextColor,
                    ),
                  ),
                  SizedBox(height: 16 * scale),
                  Text(
                    'Email kamu akan menggunakan email dari akun Google.',
                    style: TextStyle(
                      fontSize: 14 * scale,
                      color: AppColor().hintTextColor,
                    ),
                  ),
                  SizedBox(height: 24 * scale),
                  TextFormField(
                    enabled: false,
                    initialValue: _email ?? 'Memuat email...',
                    decoration: InputDecoration(
                      labelText: 'Email',
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12 * scale),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 20 * scale),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password wajib diisi';
                      }
                      if (value.length < 6) {
                        return 'Minimal 6 karakter';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      labelText: 'Password baru',
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12 * scale),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 16 * scale),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: _obscureConfirm,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Konfirmasi password wajib diisi';
                      }
                      if (value != _passwordController.text) {
                        return 'Konfirmasi password tidak sama';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      labelText: 'Konfirmasi password',
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12 * scale),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirm = !_obscureConfirm;
                          });
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 32 * scale),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColor().utama,
                        padding: EdgeInsets.symmetric(
                          vertical: 14 * scale,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12 * scale),
                        ),
                      ),
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColor().putih,
                              ),
                            )
                          : Text(
                              'Simpan Password',
                              style: TextStyle(
                                color: AppColor().putih,
                                fontSize: 18 * scale,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

