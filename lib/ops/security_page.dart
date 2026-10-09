import 'package:flutter/material.dart';

import '../core/theme/app_theme_colors.dart';
import 'ops_api.dart';
import 'ops_widgets.dart';
import 'restrict_sheet.dart';

/// Blocked addresses / suspended accounts, plus the log of who did what.
class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key, required this.api, required this.me});
  final OpsApi api;
  final OpsMe me;

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  List<Json> _rules = const [];
  List<Json> _trail = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rules =
        widget.me.can('restrict') ? await widget.api.restrictions() : <Json>[];
    final trail = widget.me.can('trail') ? await widget.api.trail() : <Json>[];
    if (!mounted) return;
    setState(() {
      _rules = rules;
      _trail = trail;
      _loading = false;
    });
  }

  Future<void> _lift(Json r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t('Cabut pembatasan?', 'Lift this restriction?')),
        content: Text('${r['value']}'),
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
    if (ok == true) {
      await widget.api.lift('${r['id']}');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: widget.me.can('restrict')
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: Text(t('Batasi', 'Restrict')),
              onPressed: () async {
                if (await showRestrictSheet(context, widget.api)) _load();
              },
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: [
            if (widget.me.can('restrict')) ...[
              Section(t('PEMBATASAN AKTIF', 'ACTIVE RESTRICTIONS')),
              if (_rules.isEmpty)
                Panel(
                    child: Text(
                        t('Tidak ada pembatasan.', 'Nothing is restricted.'),
                        style: TextStyle(color: context.colors.textSecondary))),
              for (final r in _rules)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Panel(
                    child: Row(children: [
                      Icon(
                          r['kind'] == 'ip'
                              ? Icons.public
                              : Icons.person_off_outlined,
                          color: Colors.redAccent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${r['value']}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                  overflow: TextOverflow.ellipsis),
                              if ('${r['reason'] ?? ''}'.isNotEmpty)
                                Text('${r['reason']}',
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        color: context.colors.textSecondary)),
                              Text(
                                '${r['by'] ?? '-'} · ${ago(r['createdAt'])}${r['until'] != null ? ' · ${t('sampai', 'until')} ${_date(r['until'])}' : ''}',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: context.colors.textSecondary),
                              ),
                            ]),
                      ),
                      IconButton(
                          tooltip: t('Cabut', 'Lift'),
                          icon: const Icon(Icons.lock_open_rounded),
                          onPressed: () => _lift(r)),
                    ]),
                  ),
                ),
            ],
            if (widget.me.can('trail')) ...[
              Section(t('LOG AKTIVITAS', 'ACTIVITY LOG')),
              if (_trail.isEmpty)
                Panel(
                    child: Text(t('Belum ada aktivitas.', 'No activity yet.'),
                        style: TextStyle(color: context.colors.textSecondary))),
              if (_trail.isNotEmpty)
                Panel(
                  child: Column(children: [
                    for (final e in _trail)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          '${e['action']}${e['target'] != null ? ' · ${e['target']}' : ''}',
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600)),
                                      Text('${e['who']}',
                                          style: TextStyle(
                                              fontSize: 11.5,
                                              color: context
                                                  .colors.textSecondary)),
                                    ]),
                              ),
                              Text(ago(e['at']),
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      color: context.colors.textSecondary)),
                            ]),
                      ),
                  ]),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _date(dynamic v) {
    final d = DateTime.tryParse('$v')?.toLocal();
    if (d == null) return '-';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
