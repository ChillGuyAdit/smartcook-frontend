import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_theme_colors.dart';
import 'devices_page.dart';
import 'ops_api.dart';
import 'ops_widgets.dart';
import 'restrict_sheet.dart';

/// Numbers for the front page: how many people, how many are online, which
/// build is failing for how many phones.
class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key, required this.api});
  final OpsApi api;

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  Json? _d;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await widget.api.overview();
    if (!mounted) return;
    setState(() {
      _d = d;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('Ringkasan', 'Overview'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _d == null
              ? EmptyNote(t('Data belum tersedia.', 'No data yet.'))
              : RefreshIndicator(
                  onRefresh: _load, child: _content(context, _d!)),
    );
  }

  Widget _content(BuildContext context, Json d) {
    final errs =
        (d['errorsByBuild'] as List?)?.whereType<Map>().toList() ?? const [];
    final mix = (d['buildMix'] as List?)?.whereType<Map>().toList() ?? const [];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        LayoutBuilder(builder: (context, c) {
          final w = (c.maxWidth - 10) / 2;
          Widget tile(String k, Object? v) =>
              SizedBox(width: w, child: Metric(label: k, value: '${v ?? '-'}'));
          return Wrap(spacing: 10, runSpacing: 10, children: [
            tile(t('Pengguna', 'Users'), d['users']),
            tile(t('Baru hari ini', 'New today'), d['newToday']),
            tile(t('Perangkat', 'Devices'), d['devices']),
            tile(t('Terhubung', 'Online'), d['online']),
            tile(t('Pembatasan aktif', 'Active restrictions'),
                d['restrictions']),
          ]);
        }),
        Section(t('GALAT 24 JAM TERAKHIR PER VERSI',
            'ERRORS IN THE LAST 24 H BY BUILD')),
        if (errs.isEmpty)
          Panel(
              child: Text(t('Tidak ada galat. 🎉', 'No errors. 🎉'),
                  style: TextStyle(color: context.colors.textSecondary))),
        if (errs.isNotEmpty)
          Panel(
            child: Column(children: [
              for (final e in errs)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    SizedBox(
                        width: 70,
                        child: Text('build ${e['build'] ?? '?'}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700))),
                    Expanded(
                        child: Text('${e['errors']} ${t('galat', 'errors')}',
                            style: TextStyle(
                                color: context.colors.textSecondary))),
                    Pill('${e['devices']} ${t('perangkat', 'devices')}',
                        color: Colors.red),
                  ]),
                ),
            ]),
          ),
        Section(t('SEBARAN VERSI', 'BUILD MIX')),
        if (mix.isNotEmpty)
          Panel(
            child: Column(children: [
              for (final b in mix)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    SizedBox(
                        width: 70,
                        child: Text('build ${b['build'] ?? '?'}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600))),
                    Expanded(
                        child: BarMeter(
                            fraction: _share(mix, b),
                            color: const Color(0xFF1E88E5))),
                    SizedBox(
                        width: 44,
                        child: Text('${b['devices']}',
                            textAlign: TextAlign.right)),
                  ]),
                ),
            ]),
          ),
      ],
    );
  }

  double _share(List<Map> mix, Map b) {
    final total = mix.fold<num>(0, (a, e) => a + (numOf(e['devices']) ?? 0));
    return total == 0 ? 0 : (numOf(b['devices']) ?? 0) / total;
  }
}

/// Search accounts; open one to see its phones and sign-ins, or suspend it.
class PeoplePage extends StatefulWidget {
  const PeoplePage({super.key, required this.api, required this.me});
  final OpsApi api;
  final OpsMe me;

  @override
  State<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends State<PeoplePage> {
  final _search = TextEditingController();
  List<Json> _items = const [];
  bool _loading = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final rows = await widget.api.users(q: _search.text);
    if (!mounted) return;
    setState(() {
      _items = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('Pengguna', 'People'))),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _search,
            onChanged: (_) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 400), _load);
            },
            decoration: InputDecoration(
              hintText: t('Cari email atau nama...', 'Search email or name...'),
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? EmptyNote(t('Tidak ada pengguna.', 'No one found.'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final u = _items[i];
                        return Panel(
                          onTap: () => Navigator.of(context)
                              .push(MaterialPageRoute<void>(
                            builder: (_) => PersonPage(
                                api: widget.api,
                                me: widget.me,
                                id: '${u['id']}'),
                          )),
                          child: Row(children: [
                            const Icon(Icons.person_outline),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${u['email']}',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    Text(
                                      '${(u['name'] ?? '').toString().isEmpty ? '-' : u['name']} · ${u['provider']} · ${u['devices']} ${t('perangkat', 'devices')}',
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          color: context.colors.textSecondary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ]),
                            ),
                            if (u['suspended'] == true)
                              Pill(t('ditangguhkan', 'suspended'),
                                  color: Colors.red),
                          ]),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}

class PersonPage extends StatefulWidget {
  const PersonPage(
      {super.key, required this.api, required this.me, required this.id});
  final OpsApi api;
  final OpsMe me;
  final String id;

  @override
  State<PersonPage> createState() => _PersonPageState();
}

class _PersonPageState extends State<PersonPage> {
  Json? _d;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await widget.api.userDetail(widget.id);
    if (!mounted) return;
    setState(() {
      _d = d;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final u =
        d != null && d['user'] is Map ? Json.from(d['user'] as Map) : null;
    final devices =
        (d?['devices'] as List?)?.whereType<Map>().toList() ?? const [];
    final logins =
        (d?['logins'] as List?)?.whereType<Map>().toList() ?? const [];
    return Scaffold(
      appBar: AppBar(
          title: Text(u == null ? t('Pengguna', 'Person') : '${u['email']}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : u == null
              ? EmptyNote(t('Pengguna tidak ditemukan.', 'Not found.'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                      Panel(
                        child: Column(children: [
                          _kv(context, t('Nama', 'Name'),
                              '${u['name'] ?? '-'}'),
                          _kv(context, t('Masuk lewat', 'Sign-in'),
                              '${u['provider']}${u['verifiedWithGoogle'] == true ? ' · Google ✓' : ''}'),
                          _kv(context, t('Terdaftar', 'Joined'),
                              ago(u['createdAt'])),
                          _kv(
                              context,
                              'Onboarding',
                              u['onboarded'] == true
                                  ? t('selesai', 'done')
                                  : t('belum', 'not yet')),
                          _kv(
                              context,
                              t('Status', 'Status'),
                              u['suspended'] == true
                                  ? t('ditangguhkan', 'suspended')
                                  : t('aktif', 'active')),
                        ]),
                      ),
                      if (widget.me.can('restrict') &&
                          u['suspended'] != true) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.person_off_outlined),
                          label: Text(
                              t('Suspend akun ini', 'Suspend this account')),
                          onPressed: () async {
                            if (await showRestrictSheet(context, widget.api,
                                email: '${u['email']}')) _load();
                          },
                        ),
                      ],
                      Section(t('PERANGKAT', 'DEVICES')),
                      if (devices.isEmpty)
                        Panel(
                            child: Text(t('Belum ada.', 'None yet.'),
                                style: TextStyle(
                                    color: context.colors.textSecondary))),
                      for (final dev in devices)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Panel(
                            onTap: widget.me.can('devices')
                                ? () => Navigator.of(context)
                                        .push(MaterialPageRoute<void>(
                                      builder: (_) => DeviceDetailPage(
                                          api: widget.api,
                                          me: widget.me,
                                          installId: '${dev['installId']}'),
                                    ))
                                : null,
                            child: Row(children: [
                              Expanded(
                                child: Text(
                                    [dev['manufacturer'], dev['deviceModel']]
                                        .where(
                                            (e) => e != null && '$e'.isNotEmpty)
                                        .join(' '),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                              ),
                              Text(
                                  '${dev['ip'] ?? ''} · ${ago(dev['lastSeen'])}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: context.colors.textSecondary)),
                            ]),
                          ),
                        ),
                      Section(t('RIWAYAT MASUK', 'SIGN-IN HISTORY')),
                      Panel(
                        child: logins.isEmpty
                            ? Text(t('Belum ada.', 'None yet.'),
                                style: TextStyle(
                                    color: context.colors.textSecondary))
                            : Column(children: [
                                for (final l in logins.take(30))
                                  Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(children: [
                                      Expanded(
                                          child: Text('${l['ip'] ?? '-'}')),
                                      Pill('${l['via'] ?? ''}'),
                                      const SizedBox(width: 8),
                                      Text(ago(l['at']),
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: context
                                                  .colors.textSecondary)),
                                    ]),
                                  ),
                              ]),
                      ),
                    ]),
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(
              flex: 4,
              child: Text(k,
                  style: TextStyle(
                      fontSize: 13, color: context.colors.textSecondary))),
          Expanded(
              flex: 6,
              child: Text(v,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600))),
        ]),
      );
}

/// The debug-log feed, newest first.
class LogsPage extends StatefulWidget {
  const LogsPage({super.key, required this.api});
  final OpsApi api;

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  List<Json> _items = const [];
  String? _level = 'error';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await widget.api.logs(level: _level);
    if (!mounted) return;
    setState(() {
      _items = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('Log', 'Logs'))),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Wrap(spacing: 8, children: [
            for (final l in <String?>['error', 'warn', null])
              ChoiceChip(
                label: Text(l ?? t('Semua', 'All')),
                selected: _level == l,
                onSelected: (_) {
                  _level = l;
                  _load();
                },
              ),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? EmptyNote(t('Tidak ada log.', 'No log lines.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final r = _items[i];
                          return Panel(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Pill('${r['level'] ?? 'info'}',
                                        color: r['level'] == 'error'
                                            ? Colors.red
                                            : (r['level'] == 'warn'
                                                ? Colors.orange
                                                : null)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: Text(
                                            '${r['event']}${r['action'] != null ? ' · ${r['action']}' : ''}',
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13))),
                                    Text(ago(r['createdAt']),
                                        style: TextStyle(
                                            fontSize: 11,
                                            color:
                                                context.colors.textSecondary)),
                                  ]),
                                  if ('${r['error'] ?? ''}'.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text('${r['error']}',
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                context.colors.textSecondary)),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    [
                                      r['deviceManufacturer'],
                                      r['deviceModel'],
                                      r['osVersion'] != null
                                          ? 'Android ${r['osVersion']}'
                                          : null,
                                      r['appBuild'] != null
                                          ? 'build ${r['appBuild']}'
                                          : null
                                    ]
                                        .where(
                                            (e) => e != null && '$e'.isNotEmpty)
                                        .join(' · '),
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        color: context.colors.textSecondary),
                                  ),
                                ]),
                          );
                        },
                      ),
                    ),
        ),
      ]),
    );
  }
}

/// People who can use this area, and what each may do.
class TeamPage extends StatefulWidget {
  const TeamPage({super.key, required this.api, required this.me});
  final OpsApi api;
  final OpsMe me;

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  Json? _d;
  bool _loading = true;

  static const _permNames = {
    'monitor': ('Server', 'Server'),
    'devices': ('Perangkat', 'Devices'),
    'live': ('Pantau langsung HP', 'Live phone view'),
    'people': ('Pengguna', 'People'),
    'restrict': ('Batasi akses', 'Restrict access'),
    'logs': ('Log', 'Logs'),
    'trail': ('Log aktivitas', 'Activity log'),
    'members': ('Kelola tim', 'Manage team'),
    'notice': ('Pengumuman', 'Announcements'),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await widget.api.members();
    if (!mounted) return;
    setState(() {
      _d = d;
      _loading = false;
    });
  }

  /// What the signed-in member may hand out: everything for an owner, only
  /// what it holds (never "manage team") otherwise.
  List<String> get _grantable {
    final all = ((_d?['allPerms'] as List?) ?? _permNames.keys.toList())
        .map((e) => '$e')
        .toList();
    if (widget.me.isOwner) return all;
    return all.where((p) => p != 'members' && widget.me.can(p)).toList();
  }

  Future<void> _edit({Json? member}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _MemberDialog(
        api: widget.api,
        member: member,
        grantable: _grantable,
        permNames: _permNames,
      ),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final members =
        (_d?['members'] as List?)?.whereType<Map>().toList() ?? const [];
    final owners =
        (_d?['owners'] as List?)?.map((e) => '$e').toList() ?? const <String>[];
    return Scaffold(
      appBar: AppBar(title: Text(t('Tim', 'Team'))),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(t('Tambah', 'Add')),
        onPressed: () => _edit(),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  children: [
                    Section(t('PEMILIK', 'OWNERS')),
                    for (final o in owners)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Panel(
                              child: Row(children: [
                            const Icon(Icons.verified_user_outlined),
                            const SizedBox(width: 12),
                            Expanded(child: Text(o))
                          ]))),
                    Section(t('ANGGOTA', 'MEMBERS')),
                    if (members.isEmpty)
                      Panel(
                          child: Text(
                              t('Belum ada anggota.', 'No members yet.'),
                              style: TextStyle(
                                  color: context.colors.textSecondary))),
                    for (final m in members)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Panel(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Expanded(
                                      child: Text('${m['email']}',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700))),
                                  Switch(
                                    value: m['active'] == true,
                                    onChanged: (v) async {
                                      await widget.api.updateMember(
                                          '${m['email']}',
                                          active: v);
                                      _load();
                                    },
                                  ),
                                ]),
                                Wrap(spacing: 6, runSpacing: 4, children: [
                                  for (final p
                                      in (m['perms'] as List? ?? const [])
                                          .map((e) => '$e'))
                                    Pill(t(_permNames[p]?.$1 ?? p,
                                        _permNames[p]?.$2 ?? p)),
                                ]),
                                Wrap(alignment: WrapAlignment.end, children: [
                                  TextButton(
                                      onPressed: () =>
                                          _edit(member: Json.from(m)),
                                      child: Text(
                                          t('Ubah izin', 'Change rights'))),
                                  TextButton(
                                    onPressed: () async {
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (c) => AlertDialog(
                                          title: Text(t('Hapus anggota?',
                                              'Remove member?')),
                                          content: Text('${m['email']}'),
                                          actions: [
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(c, false),
                                                child:
                                                    Text(t('Batal', 'Cancel'))),
                                            FilledButton(
                                                onPressed: () =>
                                                    Navigator.pop(c, true),
                                                child:
                                                    Text(t('Hapus', 'Remove'))),
                                          ],
                                        ),
                                      );
                                      if (ok == true) {
                                        await widget.api
                                            .removeMember('${m['email']}');
                                        _load();
                                      }
                                    },
                                    child: Text(t('Hapus', 'Remove'),
                                        style: const TextStyle(
                                            color: Colors.redAccent)),
                                  ),
                                ]),
                              ]),
                        ),
                      ),
                  ]),
            ),
    );
  }
}

/// The short announcement shown on every home screen.
class NoticeEditorPage extends StatefulWidget {
  const NoticeEditorPage({super.key, required this.api});
  final OpsApi api;

  @override
  State<NoticeEditorPage> createState() => _NoticeEditorPageState();
}

class _NoticeEditorPageState extends State<NoticeEditorPage> {
  final _id = TextEditingController();
  final _en = TextEditingController();
  bool _active = false;
  bool _loading = true;
  bool _saving = false;
  String? _msg;
  String _mode = 'always'; // once | always
  int _minutes = 0; // 0 = until switched off
  DateTime? _until;

  static const _durations = <int, (String, String)>{
    0: ('Sampai dimatikan', 'Until switched off'),
    30: ('30 menit', '30 minutes'),
    60: ('1 jam', '1 hour'),
    360: ('6 jam', '6 hours'),
    1440: ('24 jam', '24 hours'),
    10080: ('7 hari', '7 days'),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _id.dispose();
    _en.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final n = await widget.api.notice();
    if (!mounted) return;
    setState(() {
      _id.text = n?['id_text']?.toString() ?? '';
      _en.text = n?['en_text']?.toString() ?? '';
      _active = n?['active'] == true;
      _mode = n?['mode']?.toString() == 'once' ? 'once' : 'always';
      _until = DateTime.tryParse('${n?['until'] ?? ''}')?.toLocal();
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _msg = null;
    });
    final err = await widget.api.setNotice(
        idText: _id.text,
        enText: _en.text,
        active: _active,
        mode: _mode,
        until: _minutes > 0
            ? DateTime.now().add(Duration(minutes: _minutes))
            : null);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _msg = err == null ? t('Tersimpan.', 'Saved.') : err;
      if (err == null) {
        _until = _minutes > 0
            ? DateTime.now().add(Duration(minutes: _minutes))
            : null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('Pengumuman', 'Announcement'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              TextField(
                  controller: _id,
                  maxLength: 280,
                  maxLines: 3,
                  decoration: InputDecoration(
                      labelText: t('Teks (Indonesia)', 'Text (Indonesian)'),
                      border: const OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(
                  controller: _en,
                  maxLength: 280,
                  maxLines: 3,
                  decoration: InputDecoration(
                      labelText: t('Teks (Inggris)', 'Text (English)'),
                      border: const OutlineInputBorder())),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                      t('Tampilkan di beranda', 'Show on the home screen')),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v)),
              const SizedBox(height: 8),
              Text(t('Berapa kali tampil', 'How often it shows'),
                  style: TextStyle(
                      fontSize: 12, color: context.colors.textSecondary)),
              const SizedBox(height: 6),
              RadioGroup<String>(
                groupValue: _mode,
                onChanged: (v) => setState(() => _mode = v ?? 'always'),
                child: Column(children: [
                  RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: 'once',
                      title: Text(t('Sekali saja', 'Only once'))),
                  RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: 'always',
                      title: Text(t('Tiap buka aplikasi', 'Every launch'))),
                ]),
              ),
              const SizedBox(height: 4),
              Text(
                  _mode == 'once'
                      ? t('Tiap perangkat hanya melihatnya satu kali, lalu hilang.',
                          'Each device sees it a single time, then it is gone.')
                      : t('Muncul setiap aplikasi dibuka sampai waktunya habis; tombol X hanya menutupnya sampai aplikasi dibuka lagi.',
                          'Shown on every launch until it expires; the X only hides it until the app is opened again.'),
                  style: TextStyle(
                      fontSize: 12, color: context.colors.textSecondary)),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: _minutes,
                decoration: InputDecoration(
                    labelText: t('Berlaku selama', 'Valid for'),
                    helperText: _until != null &&
                            _until!.isAfter(DateTime.now())
                        ? '${t('Sekarang berakhir', 'Currently ends')}: ${_until!.toLocal().toString().substring(0, 16)}'
                        : t('Lewat batas ini pengumuman hilang sendiri.',
                            'After this the announcement disappears by itself.'),
                    border: const OutlineInputBorder()),
                items: [
                  for (final e in _durations.entries)
                    DropdownMenuItem(
                        value: e.key, child: Text(t(e.value.$1, e.value.$2))),
                ],
                onChanged: (v) => setState(() => _minutes = v ?? 0),
              ),
              const SizedBox(height: 12),
              if (_msg != null)
                Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_msg!,
                        style: TextStyle(color: context.colors.textSecondary))),
              FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(t('Simpan', 'Save'))),
            ]),
    );
  }
}

/// Add or change a member. Owns its text controller, so it is released only
/// after the dialog has finished closing.
class _MemberDialog extends StatefulWidget {
  const _MemberDialog(
      {required this.api,
      required this.member,
      required this.grantable,
      required this.permNames});
  final OpsApi api;
  final Json? member;
  final List<String> grantable;
  final Map<String, (String, String)> permNames;

  @override
  State<_MemberDialog> createState() => _MemberDialogState();
}

class _MemberDialogState extends State<_MemberDialog> {
  late final _email =
      TextEditingController(text: widget.member?['email']?.toString() ?? '');
  late final Set<String> _selected = {
    ...((widget.member?['perms'] as List?) ?? const []).map((e) => '$e')
  };
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final m = widget.member;
    final err = m == null
        ? await widget.api.addMember(_email.text, _selected.toList())
        : await widget.api
            .updateMember('${m['email']}', perms: _selected.toList());
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    return AlertDialog(
      title: Text(m == null
          ? t('Tambah anggota', 'Add member')
          : t('Ubah izin', 'Change rights')),
      content: SingleChildScrollView(
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _email,
                enabled: m == null,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 8),
              for (final p in widget.grantable)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _selected.contains(p),
                  title: Text(t(widget.permNames[p]?.$1 ?? p,
                      widget.permNames[p]?.$2 ?? p)),
                  onChanged: (v) => setState(
                      () => v == true ? _selected.add(p) : _selected.remove(p)),
                ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('Batal', 'Cancel'))),
        FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(t('Simpan', 'Save'))),
      ],
    );
  }
}
