import 'package:flutter/material.dart';

import '../core/theme/app_theme_colors.dart';
import 'ops_api.dart';
import 'ops_widgets.dart';

/// Bottom sheet that blocks an address, suspends an e-mail, or both at once.
/// Returns true when something was applied.
Future<bool> showRestrictSheet(BuildContext context, OpsApi api,
    {String? ip, String? email}) async {
  final done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _RestrictForm(api: api, ip: ip, email: email),
  );
  return done == true;
}

class _RestrictForm extends StatefulWidget {
  const _RestrictForm({required this.api, this.ip, this.email});
  final OpsApi api;
  final String? ip;
  final String? email;

  @override
  State<_RestrictForm> createState() => _RestrictFormState();
}

class _RestrictFormState extends State<_RestrictForm> {
  late final _ip = TextEditingController(text: widget.ip ?? '');
  late final _email = TextEditingController(text: widget.email ?? '');
  final _reason = TextEditingController();
  // null = no end date
  static const _durations = <String, Duration?>{
    'perm': null,
    '1h': Duration(hours: 1),
    '1d': Duration(days: 1),
    '7d': Duration(days: 7),
    '30d': Duration(days: 30)
  };
  String _duration = 'perm';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _ip.dispose();
    _email.dispose();
    _reason.dispose();
    super.dispose();
  }

  String _label(String k) => switch (k) {
        'perm' => t('Permanen', 'Permanent'),
        '1h' => t('1 jam', '1 hour'),
        '1d' => t('1 hari', '1 day'),
        '7d' => t('7 hari', '7 days'),
        _ => t('30 hari', '30 days'),
      };

  Future<void> _apply() async {
    if (_ip.text.trim().isEmpty && _email.text.trim().isEmpty) {
      setState(() => _error =
          t('Isi alamat IP atau email.', 'Enter an IP address or an email.'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final d = _durations[_duration];
    final err = await widget.api.restrict(
      ip: _ip.text,
      email: _email.text,
      reason: _reason.text,
      until: d == null ? null : DateTime.now().add(d),
    );
    if (!mounted) return;
    if (err == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error = err;
      });
    }
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('Batasi akses', 'Restrict access'),
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            t('Boleh mengisi salah satu atau keduanya.',
                'Fill in one or both.'),
            style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
              controller: _ip,
              decoration: _dec(
                  t('Alamat IP atau rentang (mis. 1.2.3.0/24)',
                      'IP address or range (e.g. 1.2.3.0/24)'),
                  Icons.public)),
          const SizedBox(height: 12),
          TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: _dec('Email', Icons.alternate_email)),
          const SizedBox(height: 12),
          TextField(
              controller: _reason,
              maxLength: 300,
              decoration: _dec(
                  t('Alasan (ditampilkan ke pengguna)',
                      'Reason (shown to the user)'),
                  Icons.notes)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              for (final k in _durations.keys)
                ChoiceChip(
                    label: Text(_label(k)),
                    selected: _duration == k,
                    onSelected: (_) => setState(() => _duration = k)),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _apply,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(t('Terapkan', 'Apply')),
            ),
          ),
        ],
      ),
    );
  }
}

/// Asks, then lifts one restriction. True when it was lifted.
Future<bool> confirmLift(BuildContext context, OpsApi api, String id,
    {required String what}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(t('Cabut pembatasan?', 'Lift this restriction?')),
      content: Text(what),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(t('Batal', 'Cancel'))),
        FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(t('Cabut', 'Lift'))),
      ],
    ),
  );
  if (ok != true) return false;
  return api.lift(id);
}

/// The same block / lift control wherever a person or a device is shown:
/// when a rule applies it shows the rule (reason, time left) with a button to
/// lift it; otherwise a button to apply one. [onChanged] runs after either.
class RestrictionControl extends StatelessWidget {
  const RestrictionControl({
    super.key,
    required this.api,
    required this.isIp,
    required this.value,
    required this.current,
    required this.onChanged,
  });

  final OpsApi api;
  final bool isIp;
  final String value;

  /// {id, reason, remainingSeconds} of the rule that applies, or null.
  final Json? current;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final c = current;
    if (c == null) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: Icon(isIp ? Icons.block : Icons.person_off_outlined),
          label: Text(isIp
              ? t('Blokir IP ini', 'Block this IP')
              : t('Suspend akun ini', 'Suspend this account')),
          onPressed: () async {
            if (await showRestrictSheet(context, api,
                ip: isIp ? value : null, email: isIp ? null : value)) {
              onChanged();
            }
          },
        ),
      );
    }
    final reason = '${c['reason'] ?? ''}'.trim();
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(isIp ? Icons.block : Icons.person_off_outlined,
              color: Colors.redAccent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
                isIp
                    ? t('IP ini sedang diblokir', 'This IP is blocked')
                    : t('Akun ini sedang ditangguhkan',
                        'This account is suspended'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 6),
        Pill(fmtLeft(numOf(c['remainingSeconds'])),
            color: c['remainingSeconds'] == null ? Colors.red : Colors.orange),
        if (reason.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('${t('Alasan', 'Reason')}: $reason',
              style: TextStyle(
                  fontSize: 12.5, color: context.colors.textSecondary)),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            icon: const Icon(Icons.lock_open_rounded),
            label: Text(isIp
                ? t('Cabut blokir IP', 'Unblock this IP')
                : t('Aktifkan kembali akun', 'Unsuspend this account')),
            onPressed: c['id'] == null
                ? null
                : () async {
                    if (await confirmLift(context, api, '${c['id']}',
                        what: value)) {
                      onChanged();
                    }
                  },
          ),
        ),
      ]),
    );
  }
}
