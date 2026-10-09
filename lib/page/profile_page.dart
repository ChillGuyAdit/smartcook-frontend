import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/l10n/strings.dart';
import '../ops/ops_access.dart';
import '../ops/ops_widgets.dart' show t;
import '../service/offline_cache_service.dart';
import '../core/services/app_session.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme_colors.dart';
import '../core/theme/language_controller.dart';
import '../core/theme/theme_provider.dart';
import '../service/api_service.dart';
import '../service/token_service.dart';
import '../view/onboarding/form.dart';
import 'change_email_page.dart';
import 'change_password_page.dart';
import 'delete_account_page.dart';
import 'faq_sheet.dart';
import 'version_sheet.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _saving = false;
  PackageInfo? _pkg;
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final pkg = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _pkg = pkg);
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
    final s = stringsFor(Localizations.localeOf(context));
    if (res.success) {
      _profile = res.data as Map<String, dynamic>?;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.profileUpdated)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message ?? s.saveFailed)),
      );
    }
  }

  Future<void> _logout() async {
    // End the app session server-side first so the token stops working
    // everywhere, not just on this phone. Never blocks the sign-out.
    try {
      await AppSession.instance.revoke();
    } catch (e) {
      debugPrint('[logout] revoke failed (ignored): $e');
    }
    await TokenService.clearAll();
    await OfflineCacheService.clearPendingOperations();
    OpsAccess.reset();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/signin', (route) => false);
  }

  void _showThemePicker(BuildContext context) {
    final s = stringsFor(Localizations.localeOf(context));
    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(s.theme),
        children: [
          for (final mode in ThemeMode.values)
            RadioListTile<ThemeMode>(
              value: mode,
              groupValue: ThemeProvider.instance.mode,
              onChanged: (value) {
                if (value == null) return;
                ThemeProvider.instance.set(value);
                Navigator.pop(ctx);
              },
              title: Text(switch (mode) {
                ThemeMode.system => s.themeSystem,
                ThemeMode.light => s.themeLight,
                ThemeMode.dark => s.themeDark,
              }),
            ),
        ],
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    final s = stringsFor(Localizations.localeOf(context));
    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(s.language),
        children: [
          for (final locale in LanguageController.supportedLocales)
            RadioListTile<Locale>(
              value: locale,
              groupValue: LanguageController.instance.locale,
              onChanged: (value) {
                if (value == null) return;
                // Close the dialog first, then switch. Doing both in the same
                // frame raced MaterialApp's locale rebuild: the dialog was
                // torn down by the locale change while Navigator.pop was still
                // running against it, which left the screen blank.
                Navigator.pop(ctx);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  LanguageController.instance.set(value);
                });
              },
              title: Text(locale.languageCode == 'en'
                  ? s.languageEnglish
                  : s.languageIndonesian),
            ),
        ],
      ),
    );
  }

  String _themeLabel(dynamic s) {
    switch (ThemeProvider.instance.mode) {
      case ThemeMode.light:
        return s.themeLight;
      case ThemeMode.dark:
        return s.themeDark;
      case ThemeMode.system:
        return s.themeSystem;
    }
  }

  String _languageLabel(dynamic s) =>
      LanguageController.instance.isIndonesian ? 'Indonesia' : 'English';

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppThemeColors>()!;
    final s = stringsFor(Localizations.localeOf(context));

    return AnimatedBuilder(
      // Settings rows read live values, so a change from the dialog is
      // reflected without rebuilding the page from the server.
      animation: Listenable.merge([
        ThemeProvider.instance,
        LanguageController.instance,
      ]),
      builder: (context, _) {
        if (_loading) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final name = _profile?['name']?.toString() ?? '';
        final email = _profile?['email']?.toString() ?? '';

        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Column(
                      children: [
                        const CircleAvatar(
                          radius: 50,
                          backgroundImage: AssetImage('image/mainLogo.jpg'),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          name.isEmpty ? s.profile : name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (email.isNotEmpty)
                          Text(
                            email,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(labelText: s.name),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
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
                        : Text(
                            s.saveProfile,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  const SizedBox(height: 28),
                  _SectionHeader(title: s.appearance),
                  _SettingTile(
                    icon: Icons.dark_mode_outlined,
                    label: s.theme,
                    trailing: _themeLabel(s),
                    onTap: () => _showThemePicker(context),
                  ),
                  _SettingTile(
                    icon: Icons.language,
                    label: s.language,
                    trailing: _languageLabel(s),
                    onTap: () => _showLanguagePicker(context),
                  ),
                  const SizedBox(height: 8),
                  _SectionHeader(title: s.editProfile),
                  _SettingTile(
                    icon: Icons.tune_rounded,
                    label: s.editPreferences,
                    onTap: () {
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
                  ),
                  _SettingTile(
                    icon: Icons.lock_reset,
                    label: s.changePassword,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ChangePasswordPage(),
                        ),
                      );
                    },
                  ),
                  _SettingTile(
                    icon: Icons.alternate_email_rounded,
                    label: s.changeEmail,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ChangeEmailPage(),
                        ),
                      ).then((changed) {
                        if (changed == true) _load();
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  _SectionHeader(title: s.other),
                  _SettingTile(
                    icon: Icons.help_outline,
                    label: s.faq,
                    onTap: () => showFaqSheet(context),
                  ),
                  if (_pkg != null)
                    _SettingTile(
                      icon: Icons.info_outline_rounded,
                      label: s.version,
                      trailing: '${_pkg!.version} (${_pkg!.buildNumber})',
                      onTap: () => showVersionSheet(context, _pkg!),
                    ),
                  const SizedBox(height: 8),
                  _SectionHeader(title: s.danger),
                  _SettingTile(
                    icon: Icons.delete_forever_outlined,
                    label: s.deleteAccount,
                    subtitle: s.deleteAccountSubtitle,
                    destructive: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DeleteAccountPage(),
                        ),
                      ).then((deleted) {
                        if (deleted == true) _logout();
                      });
                    },
                  ),
                  if (OpsAccess.current != null) ...[
                    const SizedBox(height: 8),
                    _SettingTile(
                      icon: Icons.space_dashboard_outlined,
                      label: t('Konsol', 'Console'),
                      onTap: () => OpsAccess.open(context, OpsAccess.current!),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _SettingTile(
                    icon: Icons.logout_rounded,
                    label: s.logout,
                    destructive: true,
                    onTap: _logout,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'SmartCook · v${_pkg?.version ?? '-'} (${_pkg?.buildNumber ?? '-'})',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.textDisabled,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8, left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: palette.textSecondary,
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.trailing,
    this.destructive = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final String? trailing;
  final bool destructive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final tint = destructive ? AppColors.error : AppColors.primary;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: tint, size: 20),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: destructive ? AppColors.error : palette.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: TextStyle(color: palette.textSecondary, fontSize: 12),
            ),
      trailing: trailing == null
          ? Icon(Icons.chevron_right_rounded, color: palette.textDisabled)
          : Text(
              trailing!,
              style: TextStyle(color: palette.textSecondary, fontSize: 13),
            ),
      onTap: onTap,
    );
  }
}
