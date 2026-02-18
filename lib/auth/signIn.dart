import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smartcook/auth/forgotpassword.dart';
import 'package:smartcook/auth/signUp.dart';
import 'package:smartcook/auth/login_otp.dart';
import 'package:smartcook/auth/google_set_password.dart';
import 'package:smartcook/helper/color.dart';
import 'package:smartcook/page/homepage.dart';
import 'package:smartcook/service/api_service.dart';
import 'package:smartcook/service/auth_service.dart';
import 'package:smartcook/service/token_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smartcook/view/onboarding/mainBoarding.dart';

class signin extends StatefulWidget {
  const signin({super.key});

  @override
  State<signin> createState() => _signinState();
}

class _signinState extends State<signin> with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  final TextEditingController _kontrolEmail = TextEditingController();
  final TextEditingController _kontrolPassword = TextEditingController();
  final FocusNode _focusNode1 = FocusNode();
  final FocusNode _focusNode2 = FocusNode();

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  bool _hasError = false;
  String? _errorMessage;
  int _pwCooldownSeconds = 0;
  Timer? _pwTimer;

  @override
  void dispose() {
    _shakeController.dispose();
    _kontrolEmail.dispose();
    _kontrolPassword.dispose();
    _focusNode1.dispose();
    _focusNode2.dispose();
    _pwTimer?.cancel();
    super.dispose();
  }

  bool _obscuretext = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation =
        Tween<double>(begin: 0, end: 12).chain(CurveTween(curve: Curves.elasticIn)).animate(_shakeController);
  }

  Future<void> _handleAfterLogin(Map<String, dynamic>? user) async {
    final onboardingCompleted = user?['onboarding_completed'] == true;
    if (!mounted) return;
    if (onboardingCompleted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => homepage()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => onboarding()),
      );
    }
  }

  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pwCooldownSeconds > 0) return;
    setState(() {
      _loading = true;
      _hasError = false;
      _errorMessage = null;
    });
    final res = await ApiService.post(
      '/api/auth/login',
      body: {
        'email': _kontrolEmail.text.trim(),
        'password': _kontrolPassword.text,
      },
      useAuth: false,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (!res.success) {
      // Tangani kasus khusus dari backend berdasarkan kode error
      final effectiveCode = res.code ?? '';

      if (effectiveCode == 'LOGIN_OTP_REQUIRED') {
        _kontrolPassword.clear();
        if (!mounted) return;
        int? expirySec;
        if (res.data is Map<String, dynamic>) {
          final data = res.data as Map<String, dynamic>;
          final expires = data['expires_in_seconds'];
          if (expires is num && expires > 0) {
            expirySec = expires.toInt();
          }
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LoginOtpPage(
              email: _kontrolEmail.text.trim(),
              initialExpirySeconds: expirySec,
            ),
          ),
        );
        return;
      }

      // Jika kena rate limit login (5x salah / window 5 menit), baca retry_after_seconds
      if (effectiveCode == 'LOGIN_RATE_LIMIT' && res.data is Map<String, dynamic>) {
        final data = res.data as Map<String, dynamic>;
        final ra = data['retry_after_seconds'];
        if (ra is num && ra > 0) {
          _pwTimer?.cancel();
          _pwCooldownSeconds = ra.toInt();
          _pwTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
            if (!mounted) {
              timer.cancel();
              return;
            }
            setState(() {
              if (_pwCooldownSeconds > 1) {
                _pwCooldownSeconds--;
              } else {
                _pwCooldownSeconds = 0;
                timer.cancel();
              }
            });
          });
        }
      }

      final msg = res.message ?? 'Login gagal';
      setState(() {
        _hasError = true;
        _errorMessage = msg;
        _kontrolPassword.clear();
      });
      _shakeController.forward(from: 0);
      return;
    }

    final data = res.data as Map<String, dynamic>?;
    final token = data?['token'] as String?;
    final user = data?['user'] as Map<String, dynamic>?;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Respons tidak valid')),
      );
      return;
    }
    await TokenService.saveToken(token);
    if (user != null) await TokenService.saveUser(user);
    await _handleAfterLogin(user);
  }

  @override
  Widget build(BuildContext context) {
    final screenheight = MediaQuery.of(context).size.height;
    final screenwidth = MediaQuery.of(context).size.width;

    double basewidth = 430;
    double scale = screenwidth / basewidth;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: NeverScrollableScrollPhysics(),
              child: Column(
                children: [
                  SizedBox(height: 100),
                  AnimatedBuilder(
                    animation: _shakeController,
                    builder: (context, child) {
                      final dx = _hasError ? (_shakeAnimation.value - 6) : 0.0;
                      return Transform.translate(
                        offset: Offset(dx, 0),
                        child: child,
                      );
                    },
                    child: Container(
                      height: 460 * scale,
                      width: 380 * scale,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(56),
                          topRight: Radius.circular(74),
                        ),
                        color: AppColor().hijauPucat,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(left: 30),
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: Text(
                                'SignIn',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 38 * scale,
                                  color: AppColor().hintTextColor,
                                ),
                              ),
                            ),
                          ),
                          if (_errorMessage != null) ...[
                            SizedBox(height: 12 * scale),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 31),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 12 * scale,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                SizedBox(height: 30 * scale),
                                email(),
                                SizedBox(height: 15 * scale),
                                password(),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(right: 35),
                            child: Align(
                              alignment: Alignment.bottomRight,
                              child: TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => forgotpassowrd(),
                                    ),
                                  );
                                },
                                child: Text(
                                  'Lupa Password?',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColor().hintTextColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12 * scale),
                              ),
                              backgroundColor: AppColor().utama,
                              padding: EdgeInsets.symmetric(
                                horizontal: 100 * scale,
                                vertical: 15 * scale,
                              ),
                            ),
                            onPressed: _loading || _pwCooldownSeconds > 0
                                ? null
                                : _submitData,
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
                                    _pwCooldownSeconds > 0
                                        ? 'SignIn (${_pwCooldownSeconds}s)'
                                        : 'SignIn',
                                    style: TextStyle(
                                      color: AppColor().putih,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 22 * scale,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 100 * scale),
                  bagianOr(),
                  SizedBox(height: 40 * scale),
                  auth(),
                  SizedBox(
                    height: 40 * scale,
                  )
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: screenheight * 0.04),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Belum punya akun ?',
                    style: TextStyle(fontSize: 17 * scale)),
                SizedBox(width: 6),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, anim1, anim2) => signup(),
                        transitionDuration: Duration.zero,
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Text(
                        'SignUp',
                        style: TextStyle(
                          color: AppColor().utama,
                          fontSize: 17 * scale,
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
          ),
        ],
      ),
    );
  }

  Widget email() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 31),
      child: TextFormField(
        controller: _kontrolEmail,
        focusNode: _focusNode1,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        onFieldSubmitted: (v) =>
            FocusScope.of(context).requestFocus(_focusNode2),
        validator: (value) {
          if (value == null || value.isEmpty) return "Wajib isi bray";
          if (!value.contains("@") ||
              !value.contains("gmail") ||
              !value.contains(".com")) {
            return "Email ngga valid bray";
          }
          return null;
        },
        decoration: InputDecoration(
          errorStyle: TextStyle(height: 0, fontSize: 10),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(
              color: _hasError ? Colors.red.shade400 : Colors.transparent,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(
              color: _hasError ? Colors.red.shade400 : Colors.transparent,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.red.shade400),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.red.shade400),
          ),
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          fillColor: Color(0xFFFFFFFF),
          prefixIcon: Icon(Icons.mail, color: AppColor().hintTextColor),
          hintText: 'Masukkan Emailmu',
          hintStyle: TextStyle(color: AppColor().hintTextColor),
        ),
      ),
    );
  }

  Widget password() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 31),
      child: TextFormField(
        controller: _kontrolPassword,
        focusNode: _focusNode2,
        obscureText: _obscuretext,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        onFieldSubmitted: (v) => _submitData(),
        validator: (value) {
          if (value == null || value.isEmpty) return "Wajib isi bray";
          if (value.length < 6) return "Minimal 6 karakter";
          return null;
        },
        decoration: InputDecoration(
          errorStyle: TextStyle(height: 0, fontSize: 10),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(
              color: _hasError ? Colors.red.shade400 : Colors.transparent,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(
              color: _hasError ? Colors.red.shade400 : Colors.transparent,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.red.shade400),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.red.shade400),
          ),
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          fillColor: Color(0xFFFFFFFF),
          prefixIcon: Icon(Icons.lock, color: AppColor().hintTextColor),
          suffixIcon: IconButton(
            icon: Icon(
              _obscuretext ? Icons.visibility_off : Icons.visibility,
              color: AppColor().hintTextColor,
            ),
            onPressed: () => setState(() => _obscuretext = !_obscuretext),
          ),
          hintText: 'Masukkan Password',
          hintStyle: TextStyle(color: AppColor().hintTextColor),
        ),
      ),
    );
  }

  Widget bagianOr() {
    final screenwidth = MediaQuery.of(context).size.width;
    double basewidth = 430;
    double scale = screenwidth / basewidth;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
            height: 1, width: 130 * scale, color: AppColor().hintTextColor),
        SizedBox(width: 10),
        Text('Or',
            style: TextStyle(
                color: AppColor().hintTextColor, fontSize: 20 * scale)),
        SizedBox(width: 10),
        Container(
            height: 1, width: 130 * scale, color: AppColor().hintTextColor),
      ],
    );
  }

  Widget auth() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        InkWell(
          onTap: () async {
            if (_loading) return;
            UserCredential? userCredential =
                await _authService.signinWithGoogle();
            if (userCredential == null) return;
            final firebaseUser = userCredential.user;
            final email = firebaseUser?.email;
            final name = firebaseUser?.displayName;
            final uid = firebaseUser?.uid;
            final photoUrl = firebaseUser?.photoURL;
            if (email == null || email.isEmpty || uid == null || uid.isEmpty) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Gagal mendapatkan data akun Google')),
                );
              }
              return;
            }
            setState(() => _loading = true);
            final res = await ApiService.post(
              '/api/auth/google',
              body: {
                'uid': uid,
                'email': email,
                'name': name,
                'photo_url': photoUrl,
              },
              useAuth: false,
            );
            if (!mounted) return;
            setState(() => _loading = false);
            if (!res.success) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(res.message ?? 'Login Google gagal')),
              );
              return;
            }
            final data = res.data as Map<String, dynamic>?;
            final token = data?['token'] as String?;
            final backendUser = data?['user'] as Map<String, dynamic>?;
            final needsPassword = data?['needs_password'] == true;
            if (token == null || token.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Respons tidak valid')),
              );
              return;
            }
            await TokenService.saveToken(token);
            if (backendUser != null) await TokenService.saveUser(backendUser);

            if (!mounted) return;
            if (needsPassword) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => GoogleSetPasswordPage(
                          email: backendUser?['email'] as String?,
                        )),
              );
            } else {
              await _handleAfterLogin(backendUser);
            }
          },
          child: Image(
            image: const AssetImage('image/google.png'),
            height: 100,
            width: 100,
          ),
        ),
        const SizedBox(width: 40),
        const Image(
          image: AssetImage('image/apple.png'),
          height: 100,
          width: 100,
        )
      ],
    );
  }
}
