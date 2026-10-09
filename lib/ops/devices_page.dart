import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_theme_colors.dart';
import 'ops_api.dart';
import 'ops_widgets.dart';
import 'restrict_sheet.dart';

/// Phones that connect to the service: who is on now, and everyone seen lately.
class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key, required this.api, required this.me});
  final OpsApi api;
  final OpsMe me;

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  final _search = TextEditingController();
  List<Json> _items = const [];
  bool _onlineOnly = true;
  bool _loading = true;
  Timer? _debounce;
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    _load();
    _refresh =
        Timer.periodic(const Duration(seconds: 10), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _refresh?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    final rows = await widget.api.devices(q: _search.text, online: _onlineOnly);
    if (!mounted) return;
    setState(() {
      _items = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            children: [
              TextField(
                controller: _search,
                onChanged: (_) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 400), _load);
                },
                decoration: InputDecoration(
                  hintText: t(
                      'Cari model, IP, email...', 'Search model, IP, email...'),
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                        value: true, label: Text(t('Terhubung', 'Connected'))),
                    ButtonSegment(value: false, label: Text(t('Semua', 'All'))),
                  ],
                  selected: {_onlineOnly},
                  onSelectionChanged: (v) {
                    setState(() => _onlineOnly = v.first);
                    _load();
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _loading && _items.isEmpty
                ? ListView(children: const [
                    SizedBox(height: 120),
                    Center(child: CircularProgressIndicator())
                  ])
                : _items.isEmpty
                    ? ListView(children: [
                        EmptyNote(_onlineOnly
                            ? t('Tidak ada perangkat yang terhubung sekarang.',
                                'No device is connected right now.')
                            : t('Belum ada perangkat.', 'No devices yet.'))
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _tile(context, _items[i]),
                      ),
          ),
        ),
      ],
    );
  }

  Widget _tile(BuildContext context, Json d) {
    final online = d['online'] == true;
    final user =
        d['user'] is Map ? (d['user'] as Map)['email']?.toString() : null;
    final live = d['live'] is Map ? Json.from(d['live'] as Map) : null;
    final model = [d['manufacturer'], d['deviceModel']]
        .where((e) => e != null && '$e'.isNotEmpty)
        .join(' ');
    return Panel(
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => DeviceDetailPage(
            api: widget.api, me: widget.me, installId: '${d['installId']}'),
      )),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: online
                          ? const Color(0xFF43A047)
                          : context.colors.textDisabled)),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(model.isEmpty ? '${d['installId']}' : model,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700))),
              if (d['restricted'] == true)
                Pill(t('diblokir', 'blocked'), color: Colors.red),
              const SizedBox(width: 6),
              Text(ago(d['lastSeen']),
                  style: TextStyle(
                      fontSize: 12, color: context.colors.textSecondary)),
            ],
          ),
          const SizedBox(height: 6),
          Text(user ?? t('Belum masuk akun', 'Not signed in'),
              style:
                  TextStyle(fontSize: 13, color: context.colors.textSecondary)),
          const SizedBox(height: 2),
          Text(
            [
              d['ip'],
              d['country'],
              if (d['appBuild'] != null) 'build ${d['appBuild']}',
              d['osVersion'] != null ? 'Android ${d['osVersion']}' : null
            ].where((e) => e != null && '$e'.isNotEmpty).join(' · '),
            style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
          ),
          if (live != null && live['stale'] != true) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 4, children: [
              if (numOf(live['cpu']) != null)
                Pill('CPU ${fmtPct(numOf(live['cpu']))}',
                    color: loadColor(numOf(live['cpu']))),
              if (numOf(live['battery']) != null)
                Pill(
                    '${t('Baterai', 'Battery')} ${numOf(live['battery'])!.toInt()}%${live['charging'] == true ? ' ⚡' : ''}'),
              if (numOf(live['tempC']) != null)
                Pill('${numOf(live['tempC'])}°C'),
            ]),
          ],
        ],
      ),
    );
  }
}

/// One phone: facts, sign-in history, recent events, and a live reading.
class DeviceDetailPage extends StatefulWidget {
  const DeviceDetailPage(
      {super.key,
      required this.api,
      required this.me,
      required this.installId});
  final OpsApi api;
  final OpsMe me;
  final String installId;

  @override
  State<DeviceDetailPage> createState() => _DeviceDetailPageState();
}

class _DeviceDetailPageState extends State<DeviceDetailPage> {
  Json? _data;
  bool _loading = true;
  StreamSubscription<Json>? _sub;
  Json? _reading;
  String _feed = 'idle'; // idle | waiting | live | stale
  final _cpu = Rolling(60);
  final _bat = Rolling(60);
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.me.can('live')) _connect();
  }

  Future<void> _load() async {
    final d = await widget.api.deviceDetail(widget.installId);
    if (!mounted) return;
    setState(() {
      _data = d;
      _loading = false;
    });
  }

  void _connect() {
    if (_disposed || _sub != null) return;
    setState(() => _feed = 'waiting');
    _sub = widget.api.deviceFeed(widget.installId).listen((f) {
      if (!mounted) return;
      switch (f['type']) {
        case 'reading':
          final r = f['reading'];
          if (r is Map) {
            _cpu.add(numOf(r['cpu']));
            _bat.add(numOf(r['battery']));
            setState(() {
              _reading = Json.from(r);
              _feed = 'live';
            });
          }
          break;
        case 'stale':
          setState(() => _feed = 'stale');
          break;
        default:
          if (_reading == null) setState(() => _feed = 'waiting');
      }
    }, onDone: () {
      _sub = null;
      if (!_disposed && mounted)
        Future<void>.delayed(const Duration(seconds: 3), _connect);
    }, onError: (_) {
      _sub = null;
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }

  static const _thermal = [
    'none',
    'light',
    'moderate',
    'severe',
    'critical',
    'emergency',
    'shutdown'
  ];

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final dev =
        d != null && d['device'] is Map ? Json.from(d['device'] as Map) : null;
    return Scaffold(
      appBar: AppBar(
          title: Text(dev == null
              ? t('Perangkat', 'Device')
              : [dev['manufacturer'], dev['deviceModel']]
                  .where((e) => e != null && '$e'.isNotEmpty)
                  .join(' '))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : dev == null
              ? EmptyNote(t('Perangkat tidak ditemukan.', 'Device not found.'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    if (widget.me.can('live')) ..._liveSection(context),
                    Section(t('INFORMASI', 'DETAILS')),
                    Panel(
                      child: Column(children: [
                        _kv(
                            context,
                            t('Akun', 'Account'),
                            (dev['user'] is Map
                                        ? (dev['user'] as Map)['email']
                                        : null)
                                    ?.toString() ??
                                '-'),
                        _kv(context, 'IP', '${dev['ip'] ?? '-'}'),
                        _kv(
                            context,
                            t('Negara / zona waktu', 'Country / time zone'),
                            '${dev['country'] ?? '-'} · ${dev['timezone'] ?? '-'}'),
                        _kv(context, t('Operator', 'Carrier'),
                            '${dev['carrier'] ?? '-'}'),
                        _kv(context, 'Android', '${dev['osVersion'] ?? '-'}'),
                        _kv(context, t('Versi aplikasi', 'App version'),
                            '${dev['appVersion'] ?? '-'} (${dev['appBuild'] ?? '-'})'),
                        _kv(context, 'ABI', '${dev['abi'] ?? '-'}'),
                        _kv(context, t('Bahasa', 'Language'),
                            '${dev['locale'] ?? '-'}'),
                        _kv(context, t('Pertama terlihat', 'First seen'),
                            ago(dev['firstSeen'])),
                        _kv(context, t('Terakhir terlihat', 'Last seen'),
                            ago(dev['lastSeen'])),
                        _kv(context, 'ID', '${dev['installId']}'),
                      ]),
                    ),
                    if (widget.me.can('restrict')) ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        if (dev['ip'] != null)
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.block),
                              label: Text(t('Blokir IP', 'Block IP')),
                              onPressed: () => showRestrictSheet(
                                  context, widget.api,
                                  ip: '${dev['ip']}'),
                            ),
                          ),
                        if (dev['ip'] != null && dev['user'] is Map)
                          const SizedBox(width: 10),
                        if (dev['user'] is Map)
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.person_off_outlined),
                              label: Text(t('Suspend akun', 'Suspend account')),
                              onPressed: () => showRestrictSheet(
                                  context, widget.api,
                                  email: '${(dev['user'] as Map)['email']}'),
                            ),
                          ),
                      ]),
                    ],
                    Section(t('RIWAYAT MASUK', 'SIGN-IN HISTORY')),
                    _logins(
                        context,
                        (d?['logins'] as List?)?.whereType<Map>().toList() ??
                            const []),
                    Section(t('PERISTIWA TERBARU', 'RECENT EVENTS')),
                    _events(
                        context,
                        (d?['events'] as List?)?.whereType<Map>().toList() ??
                            const []),
                  ],
                ),
    );
  }

  List<Widget> _liveSection(BuildContext context) {
    final r = _reading;
    final status = switch (_feed) {
      'live' => t('Langsung · tiap 2 detik', 'Live · every 2 s'),
      'stale' => t('Perangkat berhenti mengirim (aplikasi ditutup?)',
          'The device stopped reporting (app closed?)'),
      'waiting' => t('Menunggu perangkat... (bisa sampai 1 menit)',
          'Waiting for the device... (up to a minute)'),
      _ => '',
    };
    return [
      Section(t('LANGSUNG', 'LIVE')),
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _feed == 'live'
                          ? const Color(0xFF43A047)
                          : Colors.orange)),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(status,
                      style: TextStyle(
                          fontSize: 12, color: context.colors.textSecondary))),
            ]),
            if (r != null) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 18, runSpacing: 12, children: [
                _stat(context, t('CPU aplikasi', 'App CPU'),
                    fmtPct(numOf(r['cpu']), digits: 1)),
                _stat(context, 'RSS', '${numOf(r['rssMb']) ?? '-'} MB'),
                _stat(context, 'RAM',
                    '${numOf(r['memAvailMb']) ?? '-'} / ${numOf(r['memTotalMb']) ?? '-'} MB'),
                _stat(context, t('Baterai', 'Battery'),
                    '${numOf(r['battery']) ?? '-'}%${r['charging'] == true ? ' ⚡' : ''}'),
                _stat(context, t('Suhu', 'Temp'),
                    numOf(r['tempC']) == null ? '-' : '${numOf(r['tempC'])}°C'),
                _stat(context, t('Termal', 'Thermal'), () {
                  final i = numOf(r['thermal'])?.toInt();
                  return i == null || i < 0 || i >= _thermal.length
                      ? '-'
                      : _thermal[i];
                }()),
                _stat(context, t('Sisa penyimpanan', 'Free storage'),
                    '${numOf(r['storageFreeMb']) ?? '-'} MB'),
                if (r['lowMem'] == true)
                  _stat(context, t('Memori', 'Memory'), t('rendah', 'low')),
              ]),
              if (_cpu.values.length > 1) ...[
                const SizedBox(height: 12),
                SizedBox(
                    height: 44,
                    width: double.infinity,
                    child: Sparkline(
                        values: _cpu.values,
                        color: loadColor(numOf(r['cpu'])),
                        max: 100)),
              ],
            ],
          ],
        ),
      ),
    ];
  }

  Widget _stat(BuildContext context, String k, String v) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(k,
              style:
                  TextStyle(fontSize: 11, color: context.colors.textSecondary)),
          Text(v,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ],
      );

  Widget _logins(BuildContext context, List<Map> rows) {
    if (rows.isEmpty)
      return Panel(
          child: Text(t('Belum ada riwayat masuk.', 'No sign-ins recorded.'),
              style: TextStyle(color: context.colors.textSecondary)));
    return Panel(
      child: Column(children: [
        for (final r in rows.take(30))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Expanded(
                  child: Text('${r['ip'] ?? '-'}',
                      style: const TextStyle(fontSize: 13))),
              Pill('${r['via'] ?? ''}'),
              const SizedBox(width: 8),
              Text(ago(r['at']),
                  style: TextStyle(
                      fontSize: 12, color: context.colors.textSecondary)),
            ]),
          ),
      ]),
    );
  }

  Widget _events(BuildContext context, List<Map> rows) {
    if (rows.isEmpty)
      return Panel(
          child: Text(t('Belum ada peristiwa.', 'No events.'),
              style: TextStyle(color: context.colors.textSecondary)));
    return Panel(
      child: Column(children: [
        for (final r in rows.take(40))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Pill('${r['level'] ?? 'info'}',
                  color: r['level'] == 'error'
                      ? Colors.red
                      : (r['level'] == 'warn' ? Colors.orange : null)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  [r['event'], r['action'], r['error']]
                      .where((e) => e != null && '$e'.isNotEmpty)
                      .join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
              const SizedBox(width: 8),
              Text(ago(r['createdAt']),
                  style: TextStyle(
                      fontSize: 11, color: context.colors.textSecondary)),
            ]),
          ),
      ]),
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
