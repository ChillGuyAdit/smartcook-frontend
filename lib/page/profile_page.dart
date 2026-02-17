import 'package:flutter/material.dart';
import 'package:smartcook/service/api_service.dart';
import 'package:smartcook/service/token_service.dart';
import 'package:smartcook/view/onboarding/form.dart';
import 'package:smartcook/page/change_password_page.dart';
import 'package:smartcook/page/change_email_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _saving = false;
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/api/user/profile');
    if (!mounted) return;
    if (res.success && res.data is Map<String, dynamic>) {
      final p = res.data as Map<String, dynamic>;
      _profile = p;
      _nameController.text = p['name']?.toString() ?? '';
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final res = await ApiService.put(
      '/api/user/profile',
      body: {
        'name': _nameController.text.trim(),
        if (_profile?['age_range'] != null) 'age_range': _profile!['age_range'],
        if (_profile?['gender'] != null) 'gender': _profile!['gender'],
      },
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (res.success) {
      _profile = res.data as Map<String, dynamic>?;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil diperbarui')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message ?? 'Gagal menyimpan')),
      );
    }
  }

  Future<void> _logout() async {
    await TokenService.clearAll();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/signin', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFAFAFA),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final name = _profile?['name']?.toString() ?? '';
    final email = _profile?['email']?.toString() ?? '';
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 50,
                backgroundImage: AssetImage('image/mainLogo.jpg'),
              ),
              const SizedBox(height: 16),
              Text(
                name.isEmpty ? 'Pengguna' : name,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
              if (email.isNotEmpty)
                Text(
                  email,
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
              const SizedBox(height: 32),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nama',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Simpan Profil'),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => form(
                          initialData: _profile,
                          editFromProfile: true,
                        ),
                      ),
                    ).then((_) => _load());
                  },
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Edit preferensi & data diri'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4CAF50),
                    side: const BorderSide(color: Color(0xFF4CAF50)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Ubah password
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChangePasswordPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.lock_reset),
                  label: const Text('Ubah password'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4CAF50),
                    side: const BorderSide(color: Color(0xFF4CAF50)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Ganti email
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChangeEmailPage(),
                      ),
                    ).then((changed) {
                      if (changed == true) {
                        _load();
                      }
                    });
                  },
                  icon: const Icon(Icons.alternate_email_rounded),
                  label: const Text('Ganti email (OTP)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4CAF50),
                    side: const BorderSide(color: Color(0xFF4CAF50)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Keluar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
