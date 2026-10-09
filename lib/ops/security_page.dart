import 'dart:async';

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
  String? _kind; // null = all, 'ip', 'email'
  int _page = 1;
  int _pages = 1;
  int _total = 0;
  DateTime _fetchedAt = DateTime.now();
  Timer? _tick;
  List<Json> _trail = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    // Re-read every 30 s so time left stays right and finished ones drop off.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final res = widget.me.can('restrict')
        ? await widget.api.restrictionsPage(kind: _kind, page: _page)
        : null;
    final rows = res?['items'];
    final rules = rows is List
        ? [
            for (final e in rows)
              if (e is Map) Json.from(e)
          ]
        : <Json>[];
    final trail = widget.me.can('trail') ? await widget.api.trail() : <Json>[];
    if (!mounted) return;
    setState(() {
      _fetchedAt = DateTime.now();
      _page = (numOf(res?['page']) ?? 1).toInt();
      _pages = (numOf(res?['pages']) ?? 1).toInt();
      _total = (numOf(res?['total']) ?? 0).toInt();
      _rules = rules;
      _trail = trail;
      _loading = false;
    });
  }

  Future<void> _lift(Json r) async {
    if (await confirmLift(context, widget.api, '${r['id']}',
        what: '${r['value']}')) {
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
              Wrap(spacing: 8, children: [
                for (final (k, label) in <(String?, String)>[
                  (null, t('Semua', 'All')),
                  ('ip', 'IP'),
                  ('email', t('Akun / email', 'Account / e-mail')),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _kind == k,
                    onSelected: (_) {
                      setState(() {
                        _kind = k;
                        _page = 1;
                      });
                      _load();
                    },
                  ),
              ]),
              const SizedBox(height: 10),
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
                              const SizedBox(height: 4),
                              Pill(_left(r),
                                  color: r['until'] == null
                                      ? Colors.red
                                      : Colors.orange),
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
            if (widget.me.can('restrict') && _pages > 1)
              Row(children: [
                IconButton(
                    tooltip: t('Sebelumnya', 'Previous'),
                    onPressed: _page > 1
                        ? () {
                            setState(() => _page--);
                            _load();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_left)),
                Expanded(
                  child: Text(
                      t('Halaman $_page dari $_pages · $_total pembatasan',
                          'Page $_page of $_pages · $_total restrictions'),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                          fontSize: 12, color: context.colors.textSecondary)),
                ),
                IconButton(
                    tooltip: t('Berikutnya', 'Next'),
                    onPressed: _page < _pages
                        ? () {
                            setState(() => _page++);
                            _load();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_right)),
              ]),
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

  /// "sisa 1 hari 2 jam" / "permanen", counted from when the list was fetched.
  String _left(Json r) {
    final base = numOf(r['remainingSeconds']);
    return fmtLeft(base == null
        ? null
        : base.toInt() - DateTime.now().difference(_fetchedAt).inSeconds);
  }

  String _date(dynamic v) {
    final d = DateTime.tryParse('$v')?.toLocal();
    if (d == null) return '-';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
