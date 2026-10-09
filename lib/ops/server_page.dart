import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_theme_colors.dart';
import 'ops_api.dart';
import 'ops_widgets.dart';

/// Live view of the machine the service runs on: one reading per second.
class ServerPage extends StatefulWidget {
  const ServerPage({super.key, required this.api});
  final OpsApi api;

  @override
  State<ServerPage> createState() => _ServerPageState();
}

class _ServerPageState extends State<ServerPage> with WidgetsBindingObserver {
  final _cpu = Rolling(150);
  final _mem = Rolling(150);
  final _rx = Rolling(150);
  final _tx = Rolling(150);
  StreamSubscription<Json>? _sub;
  Json? _s; // latest sample
  bool _live = false;
  bool _busy = false;
  bool _disposed = false;
  int _failures = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connect();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // No reason to keep the machine sampling while the app is out of sight.
    if (state == AppLifecycleState.resumed) {
      if (_sub == null) _connect();
    } else if (state == AppLifecycleState.paused) {
      _sub?.cancel();
      _sub = null;
      if (mounted) setState(() => _live = false);
    }
  }

  void _connect() {
    if (_disposed || _sub != null) return;
    _sub = widget.api.serverFeed().listen(
          _onFrame,
          onError: (_) => _lost(),
          onDone: _lost,
          cancelOnError: true,
        );
  }

  void _lost() {
    _sub = null;
    if (_disposed || !mounted) return;
    setState(() => _live = false);
    _failures++;
    final wait = Duration(seconds: (_failures * 2).clamp(2, 15));
    Future<void>.delayed(wait, _connect);
  }

  void _onFrame(Json f) {
    if (!mounted) return;
    switch (f['type']) {
      case 'history':
        final items = f['items'];
        if (items is List && _cpu.items.isEmpty) {
          for (final e in items) {
            if (e is Map) {
              _cpu.add(numOf(e['cpu']));
              _mem.add(numOf(e['mem']));
              _rx.add(numOf(e['rx']));
              _tx.add(numOf(e['tx']));
            }
          }
        }
        break;
      case 'sample':
        final s = f['sample'];
        if (s is! Map) return;
        _failures = 0;
        final sample = Json.from(s);
        _cpu.add(numOf((sample['cpu'] as Map?)?['busy']));
        final mem = sample['mem'] as Map?;
        final total = numOf(mem?['total']) ?? 0;
        _mem.add(total > 0 ? (numOf(mem?['used']) ?? 0) / total * 100 : 0);
        _rx.add(numOf((sample['net'] as Map?)?['rxBps']));
        _tx.add(numOf((sample['net'] as Map?)?['txBps']));
        setState(() {
          _s = sample;
          _live = true;
          _busy = false;
        });
        break;
      case 'busy':
        setState(() => _busy = true);
        break;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  Json _m(String k) =>
      (_s?[k] is Map) ? Json.from(_s![k] as Map) : <String, dynamic>{};

  @override
  Widget build(BuildContext context) {
    final s = _s;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _status(context),
        if (_busy)
          EmptyNote(t('Terlalu banyak pemantau. Coba lagi sebentar.',
              'Too many viewers. Try again shortly.')),
        if (s == null && !_busy)
          EmptyNote(t(
              'Menunggu data pertama...', 'Waiting for the first reading...')),
        if (s != null) ..._body(context),
      ],
    );
  }

  Widget _status(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _live ? const Color(0xFF43A047) : Colors.orange),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _live
                    ? t('Langsung · tiap 1 detik', 'Live · every second')
                    : t('Menyambung ulang...', 'Reconnecting...'),
                style: TextStyle(
                    fontSize: 12, color: context.colors.textSecondary),
              ),
            ),
          ],
        ),
      );

  List<Widget> _body(BuildContext context) {
    final cpu = _m('cpu');
    final load = _m('load');
    final mem = _m('mem');
    final net = _m('net');
    final disk = _m('disk');
    final node = _m('node');
    final system = _m('system');
    final busy = numOf(cpu['busy']);
    final memTotal = numOf(mem['total']) ?? 0;
    final memUsed = numOf(mem['used']) ?? 0;
    final memPct = memTotal > 0 ? memUsed / memTotal * 100 : 0.0;
    final diskTotal = numOf(disk['total']) ?? 0;
    final diskUsed = numOf(disk['used']) ?? 0;
    final diskPct = diskTotal > 0 ? diskUsed / diskTotal * 100 : 0.0;
    final cores = (cpu['cores'] is List)
        ? (cpu['cores'] as List).map((e) => numOf(e) ?? 0).toList()
        : <num>[];

    return [
      LayoutBuilder(builder: (context, c) {
        final w = (c.maxWidth - 10) / 2;
        return Wrap(spacing: 10, runSpacing: 10, children: [
          SizedBox(
            width: w,
            child: Metric(
              label: 'CPU',
              value: fmtPct(busy),
              sub:
                  'user ${fmtPct(numOf(cpu['user']))} · sys ${fmtPct(numOf(cpu['system']))}\nio ${fmtPct(numOf(cpu['iowait']))} · steal ${fmtPct(numOf(cpu['steal']))}',
              series: _cpu.values,
              seriesMax: 100,
              color: loadColor(busy),
            ),
          ),
          SizedBox(
            width: w,
            child: Metric(
              label: 'RAM',
              value: fmtPct(memPct),
              sub:
                  '${fmtBytes(memUsed)} / ${fmtBytes(memTotal)}\nswap ${fmtBytes(numOf(mem['swapUsed']))} / ${fmtBytes(numOf(mem['swapTotal']))}',
              series: _mem.values,
              seriesMax: 100,
              color: loadColor(memPct),
            ),
          ),
          SizedBox(
            width: w,
            child: Metric(
              label: t('Jaringan masuk', 'Network in'),
              value: fmtRate(numOf(net['rxBps'])),
              sub: t('Total ${fmtBytes(numOf(net['rxTotal']))}',
                  'Total ${fmtBytes(numOf(net['rxTotal']))}'),
              series: _rx.values,
              color: const Color(0xFF1E88E5),
            ),
          ),
          SizedBox(
            width: w,
            child: Metric(
              label: t('Jaringan keluar', 'Network out'),
              value: fmtRate(numOf(net['txBps'])),
              sub: t('Total ${fmtBytes(numOf(net['txTotal']))}',
                  'Total ${fmtBytes(numOf(net['txTotal']))}'),
              series: _tx.values,
              color: const Color(0xFF8E24AA),
            ),
          ),
        ]);
      }),
      Section(t('DISK & BEBAN', 'DISK & LOAD')),
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kv(context, t('Disk terpakai', 'Disk used'),
                '${fmtBytes(diskUsed)} / ${fmtBytes(diskTotal)} (${fmtPct(diskPct)})'),
            const SizedBox(height: 6),
            BarMeter(fraction: diskPct / 100),
            const SizedBox(height: 10),
            _kv(context, t('Baca / tulis disk', 'Disk read / write'),
                '${fmtRate(numOf(disk['readBps']))} / ${fmtRate(numOf(disk['writeBps']))}'),
            _kv(context, 'Load avg',
                '${load['l1'] ?? '-'} · ${load['l5'] ?? '-'} · ${load['l15'] ?? '-'}'),
            _kv(context, t('Proses / thread', 'Processes / threads'),
                '${_s?['processCount'] ?? '-'} / ${load['threads'] ?? '-'}'),
            _kv(context, 'Uptime', fmtDuration(numOf(system['uptime']))),
            _kv(context, 'Kernel',
                '${system['kernel'] ?? '-'} · ${system['cpus'] ?? '-'} CPU'),
          ],
        ),
      ),
      if (cores.length > 1) ...[
        Section(t('INTI CPU', 'CPU CORES')),
        Panel(
          child: Column(
            children: [
              for (var i = 0; i < cores.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                          width: 44,
                          child: Text('#$i',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: context.colors.textSecondary))),
                      Expanded(child: BarMeter(fraction: cores[i] / 100)),
                      SizedBox(
                          width: 50,
                          child: Text(fmtPct(cores[i]),
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 12))),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
      Section(t('PROSES API (NODE)', 'API PROCESS (NODE)')),
      Panel(
        child: Column(
          children: [
            _kv(context, 'RSS', fmtBytes(numOf(node['rss']))),
            _kv(context, 'Heap',
                '${fmtBytes(numOf(node['heapUsed']))} / ${fmtBytes(numOf(node['heapTotal']))}'),
            _kv(context, t('Jeda event loop', 'Event loop lag'),
                '${node['lagMs'] ?? '-'} ms'),
            _kv(context, 'Uptime', fmtDuration(numOf(node['uptime']))),
          ],
        ),
      ),
      Section('GPU'),
      _gpu(context),
      if (_s?['pm2'] is List && (_s!['pm2'] as List).isNotEmpty) ...[
        Section('PM2'),
        Panel(
          child: Column(
            children: [
              for (final p in (_s!['pm2'] as List).whereType<Map>())
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text('${p['name']}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600))),
                      Pill('${p['status']}',
                          color: p['status'] == 'online'
                              ? const Color(0xFF43A047)
                              : Colors.red),
                      const SizedBox(width: 8),
                      Text('${fmtBytes(numOf(p['mem']))}',
                          style: TextStyle(
                              fontSize: 12,
                              color: context.colors.textSecondary)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
      if (_s?['mongo'] is Map) ...[
        Section('MONGODB'),
        Panel(child: _mongo(context, Json.from(_s!['mongo'] as Map))),
      ],
      if (_s?['procs'] is List && (_s!['procs'] as List).isNotEmpty) ...[
        Section(t('PROSES TERATAS', 'TOP PROCESSES')),
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            children: [
              for (final p in (_s!['procs'] as List).whereType<Map>())
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                          width: 52,
                          child: Text('${p['pid']}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: context.colors.textSecondary))),
                      Expanded(
                          child: Text('${p['name']}',
                              overflow: TextOverflow.ellipsis)),
                      SizedBox(
                          width: 56,
                          child: Text('${p['cpu']}%',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700))),
                      SizedBox(
                          width: 70,
                          child: Text(fmtBytes(numOf(p['rss'])),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: context.colors.textSecondary))),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    ];
  }

  Widget _gpu(BuildContext context) {
    final g = _s?['gpu'];
    final gpus = (g is Map && g['available'] == true && g['gpus'] is List)
        ? (g['gpus'] as List).whereType<Map>().toList()
        : <Map>[];
    if (gpus.isEmpty) {
      return Panel(
        child: Text(
            t('Server ini tidak memiliki GPU.', 'This server has no GPU.'),
            style: TextStyle(color: context.colors.textSecondary)),
      );
    }
    return Panel(
      child: Column(
        children: [
          for (final x in gpus)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${x['name']}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  BarMeter(fraction: (numOf(x['util']) ?? 0) / 100),
                  const SizedBox(height: 4),
                  Text(
                      '${fmtPct(numOf(x['util']))} · ${fmtBytes(numOf(x['memUsed']))} / ${fmtBytes(numOf(x['memTotal']))} · ${x['temp']}°C',
                      style: TextStyle(
                          fontSize: 12, color: context.colors.textSecondary)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _mongo(BuildContext context, Json m) {
    final ops = m['opcounters'] is Map
        ? Json.from(m['opcounters'] as Map)
        : <String, dynamic>{};
    return Column(
      children: [
        _kv(context, t('Koneksi', 'Connections'),
            '${m['connections'] ?? '-'} / ${m['available'] ?? '-'}'),
        _kv(context, t('Memori', 'Memory'), '${m['residentMb'] ?? '-'} MB'),
        _kv(context, 'Ops',
            'q ${ops['query'] ?? '-'} · i ${ops['insert'] ?? '-'} · u ${ops['update'] ?? '-'} · d ${ops['delete'] ?? '-'}'),
      ],
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
          ],
        ),
      );
}
