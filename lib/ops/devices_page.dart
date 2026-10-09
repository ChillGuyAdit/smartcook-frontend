import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_theme_colors.dart';
import 'ops_api.dart';
import 'ops_widgets.dart';
import 'restrict_sheet.dart';

/// How long ago a reading was taken, from its age in milliseconds.
String _agoMs(dynamic ageMs) => ago(DateTime.fromMillisecondsSinceEpoch(
    DateTime.now().millisecondsSinceEpoch - (numOf(ageMs) ?? 0).toInt()));

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
  int _page = 1;
  int _pages = 1;
  int _total = 0;
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
    final res = await widget.api
        .devicesPage(q: _search.text, online: _onlineOnly, page: _page);
    if (!mounted) return;
    final rows = res?['items'];
    setState(() {
      _items = rows is List
          ? [
              for (final e in rows)
                if (e is Map) Json.from(e)
            ]
          : const [];
      _page = (numOf(res?['page']) ?? 1).toInt();
      _pages = (numOf(res?['pages']) ?? 1).toInt();
      _total = (numOf(res?['total']) ?? 0).toInt();
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
                  _debounce = Timer(const Duration(milliseconds: 400), () {
                    _page = 1;
                    _load();
                  });
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
                    ButtonSegment(
                        value: false, label: Text(t('Riwayat', 'History'))),
                  ],
                  selected: {_onlineOnly},
                  onSelectionChanged: (v) {
                    setState(() {
                      _onlineOnly = v.first;
                      _page = 1;
                    });
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
                        itemCount: _items.length + (_pages > 1 ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => i < _items.length
                            ? _tile(context, _items[i])
                            : _pager(context),
                      ),
          ),
        ),
      ],
    );
  }

  void _goto(int page) {
    setState(() => _page = page);
    _load();
  }

  Widget _pager(BuildContext context) => Row(
        children: [
          IconButton(
              tooltip: t('Sebelumnya', 'Previous'),
              onPressed: _page > 1 ? () => _goto(_page - 1) : null,
              icon: const Icon(Icons.chevron_left)),
          Expanded(
            child: Text(
                t('Halaman $_page dari $_pages · $_total perangkat',
                    'Page $_page of $_pages · $_total devices'),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12, color: context.colors.textSecondary)),
          ),
          IconButton(
              tooltip: t('Berikutnya', 'Next'),
              onPressed: _page < _pages ? () => _goto(_page + 1) : null,
              icon: const Icon(Icons.chevron_right)),
        ],
      );

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
              d['place'] ?? d['country'],
              if (d['appBuild'] != null) 'build ${d['appBuild']}',
              d['osVersion'] != null ? 'Android ${d['osVersion']}' : null
            ].where((e) => e != null && '$e'.isNotEmpty).join(' · '),
            style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
          ),
          if (!online)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                  '${t('Terakhir online', 'Last online')}: ${ago(d['lastSeen'])}'
                  '${live != null ? ' · ${t('data terakhir', 'last data')} ${_agoMs(live['ageMs'])}' : ''}',
                  style: TextStyle(
                      fontSize: 12, color: context.colors.textSecondary)),
            ),
          if (live != null) ...[
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
  final _ram = Rolling(60);
  final _rx = Rolling(60);
  final _tx = Rolling(60);
  final _temp = Rolling(60);
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
            final total = numOf(r['memTotalMb']);
            final avail = numOf(r['memAvailMb']);
            _ram.add(total != null && avail != null && total > 0
                ? (total - avail) / total * 100
                : null);
            _rx.add(numOf(r['rxBps']));
            _tx.add(numOf(r['txBps']));
            _temp.add(numOf(r['tempC']));
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
                    if (widget.me.can('live'))
                      ..._liveSection(
                          context,
                          d?['live'] is Map
                              ? Json.from(d!['live'] as Map)
                              : null,
                          dev['hw'] is Map
                              ? Json.from(dev['hw'] as Map)
                              : null),
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
                            t('Lokasi (dari IP)', 'Location (from IP)'),
                            '${dev['place'] ?? dev['country'] ?? '-'}'),
                        _kv(context, t('Zona waktu', 'Time zone'),
                            '${dev['timezone'] ?? '-'}'),
                        _kv(
                            context,
                            t('Penyedia internet', 'Internet provider'),
                            '${dev['isp'] ?? dev['carrier'] ?? '-'}'),
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
                    if (dev['hw'] is Map)
                      ..._hardware(context, Json.from(dev['hw'] as Map)),
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

  /// Live graphs while the phone reports; the last stored reading when it is quiet.
  List<Widget> _liveSection(BuildContext context, Json? stored, Json? hw) {
    final r = _reading ?? stored;
    final isLast = _reading == null && stored != null;
    final status = switch (_feed) {
      'live' => t('Langsung · tiap 2 detik', 'Live · every 2 s'),
      'stale' => t('Perangkat berhenti mengirim (aplikasi ditutup?)',
          'The device stopped reporting (app closed?)'),
      'waiting' => t('Menunggu perangkat... (bisa sampai 1 menit)',
          'Waiting for the device... (up to a minute)'),
      _ => '',
    };
    final lastNote = isLast
        ? '${t('Data terakhir', 'Last data')}: ${_agoMs(stored['ageMs'])}'
        : '';
    return [
      Section(t('LANGSUNG', 'LIVE')),
      Panel(
        child: Row(children: [
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
              child: Text(
                  [status, lastNote].where((e) => e.isNotEmpty).join('\n'),
                  style: TextStyle(
                      fontSize: 12, color: context.colors.textSecondary))),
        ]),
      ),
      if (r != null) ..._graphs(context, r, hw),
    ];
  }

  List<Widget> _graphs(BuildContext context, Json r, Json? hw) {
    final total = numOf(r['memTotalMb']);
    final avail = numOf(r['memAvailMb']);
    final used = total != null && avail != null ? total - avail : null;
    final storTotal = numOf(r['storageTotalMb']) ?? numOf(hw?['storageMb']);
    final storFree = numOf(r['storageFreeMb']);
    final storUsed =
        storTotal != null && storFree != null ? storTotal - storFree : null;
    final thermalIdx = numOf(r['thermal'])?.toInt();
    final freq = r['freq'] is List
        ? [for (final f in r['freq'] as List) numOf(f) ?? 0]
        : const <num>[];
    final maxMhz = hw?['coreMaxMhz'] is List
        ? [for (final f in hw!['coreMaxMhz'] as List) numOf(f) ?? 0]
        : const <num>[];
    return [
      const SizedBox(height: 10),
      LayoutBuilder(builder: (context, c) {
        final w = (c.maxWidth - 10) / 2;
        Widget half(Widget child) => SizedBox(width: w, child: child);
        return Wrap(spacing: 10, runSpacing: 10, children: [
          half(Metric(
              label: t('CPU aplikasi', 'App CPU'),
              value: fmtPct(numOf(r['cpu']), digits: 1),
              sub: 'RSS ${numOf(r['rssMb']) ?? '-'} MB',
              series: _cpu.values,
              seriesMax: 100,
              color: loadColor(numOf(r['cpu'])))),
          half(Metric(
              label: 'RAM',
              value: used == null ? '-' : '${used.round()} MB',
              sub: total == null
                  ? null
                  : '${t('dari', 'of')} ${total.round()} MB${r['lowMem'] == true ? ' · ${t('rendah', 'low')}' : ''}',
              series: _ram.values,
              seriesMax: 100,
              color: used != null && total != null && total > 0
                  ? loadColor(used / total * 100)
                  : null)),
          half(Metric(
              label: t('Jaringan masuk', 'Network in'),
              value: fmtRate(numOf(r['rxBps'])),
              series: _rx.values,
              color: const Color(0xFF1E88E5))),
          half(Metric(
              label: t('Jaringan keluar', 'Network out'),
              value: fmtRate(numOf(r['txBps'])),
              series: _tx.values,
              color: const Color(0xFF8E24AA))),
          half(Metric(
              label: t('Baterai', 'Battery'),
              value:
                  '${numOf(r['battery'])?.toInt() ?? '-'}%${r['charging'] == true ? ' ⚡' : ''}',
              sub: numOf(r['voltageMv']) == null
                  ? null
                  : '${(numOf(r['voltageMv'])! / 1000).toStringAsFixed(2)} V',
              series: _bat.values,
              seriesMax: 100,
              color: const Color(0xFF43A047))),
          half(Metric(
              label: t('Suhu', 'Temperature'),
              value: numOf(r['tempC']) == null ? '-' : '${numOf(r['tempC'])}°C',
              sub:
                  '${t('Termal', 'Thermal')}: ${thermalIdx == null || thermalIdx < 0 || thermalIdx >= _thermal.length ? '-' : _thermal[thermalIdx]}',
              series: _temp.values,
              color: Colors.orange)),
        ]);
      }),
      const SizedBox(height: 10),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('Penyimpanan', 'Storage'),
              style:
                  TextStyle(fontSize: 12, color: context.colors.textSecondary)),
          const SizedBox(height: 4),
          Text(
              storUsed == null || storTotal == null
                  ? '${storFree ?? '-'} MB ${t('kosong', 'free')}'
                  : '${(storUsed / 1024).toStringAsFixed(1)} / ${(storTotal / 1024).toStringAsFixed(1)} GB',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          if (storUsed != null && storTotal != null && storTotal > 0) ...[
            const SizedBox(height: 8),
            BarMeter(fraction: storUsed / storTotal),
          ],
        ]),
      ),
      if (freq.isNotEmpty) ...[
        const SizedBox(height: 10),
        Panel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${t('Inti CPU', 'CPU cores')} (${freq.length})',
                style: TextStyle(
                    fontSize: 12, color: context.colors.textSecondary)),
            const SizedBox(height: 8),
            for (var i = 0; i < freq.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  SizedBox(
                      width: 52,
                      child: Text('Core $i',
                          style: const TextStyle(fontSize: 12))),
                  Expanded(
                      child: BarMeter(
                          fraction: i < maxMhz.length && maxMhz[i] > 0
                              ? freq[i] / maxMhz[i]
                              : freq[i] / 3000,
                          height: 7)),
                  SizedBox(
                      width: 78,
                      child: Text(
                          freq[i] <= 0
                              ? t('tidur', 'idle')
                              : '${freq[i].round()} MHz',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700))),
                ]),
              ),
          ]),
        ),
      ],
    ];
  }

  /// CPU-Z style description of the phone, sent once per launch.
  List<Widget> _hardware(BuildContext context, Json hw) {
    String j(dynamic v) => v is List ? v.join(', ') : '${v ?? '-'}';
    final maxMhz = hw['coreMaxMhz'] is List
        ? [for (final f in hw['coreMaxMhz'] as List) numOf(f) ?? 0]
        : const <num>[];
    final minMhz = hw['coreMinMhz'] is List
        ? [for (final f in hw['coreMinMhz'] as List) numOf(f) ?? 0]
        : const <num>[];
    final cpu = [
      if (hw['cores'] != null) '${hw['cores']} ${t('inti', 'cores')}',
      if (maxMhz.isNotEmpty)
        '${minMhz.isEmpty ? 0 : minMhz.reduce(math.min).round()}-${maxMhz.reduce(math.max).round()} MHz',
    ].join(' · ');
    final sensors = hw['sensors'] is List ? hw['sensors'] as List : const [];
    final rows = <(String, String)>[
      (t('Chipset (SoC)', 'Chipset (SoC)'), j(hw['soc'])),
      (
        t('Platform', 'Platform'),
        '${hw['hardware'] ?? '-'} · ${hw['board'] ?? '-'}'
      ),
      ('CPU', cpu.isEmpty ? '-' : cpu),
      (t('Governor', 'Governor'), j(hw['governor'])),
      ('ABI', j(hw['abis'])),
      (
        t('RAM total', 'Total RAM'),
        hw['ramMb'] == null
            ? '-'
            : '${(numOf(hw['ramMb'])! / 1024).toStringAsFixed(1)} GB'
      ),
      (
        t('Penyimpanan', 'Storage'),
        hw['storageMb'] == null
            ? '-'
            : '${(numOf(hw['storageMb'])! / 1024).toStringAsFixed(0)} GB'
      ),
      (
        t('Layar', 'Display'),
        '${hw['screen'] ?? '-'} · ${hw['densityDpi'] ?? '-'} dpi · ${numOf(hw['refreshHz'])?.round() ?? '-'} Hz'
      ),
      ('GPU', j(hw['gpu'])),
      (t('Vendor GPU', 'GPU vendor'), j(hw['gpuVendor'])),
      ('OpenGL ES', j(hw['glVersion'])),
      ('Android', '${hw['android'] ?? '-'} (SDK ${hw['sdk'] ?? '-'})'),
      (t('Patch keamanan', 'Security patch'), j(hw['patch'])),
      ('Kernel', j(hw['kernel'])),
      (
        t('Baterai', 'Battery'),
        '${hw['batteryTech'] ?? '-'} · ${hw['batteryHealth'] ?? '-'}'
      ),
      (t('Fitur', 'Features'), j(hw['features'])),
      (
        t('Sensor', 'Sensors') + ' (${sensors.length})',
        sensors.isEmpty ? '-' : sensors.join('\n')
      ),
    ];
    return [
      Section(t('SPESIFIKASI PERANGKAT', 'DEVICE SPECS')),
      Panel(
        child: Column(children: [
          for (final (k, v) in rows) _kv(context, k, v),
        ]),
      ),
    ];
  }

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
