import 'dart:async';

import 'package:smartcook/ops/ops_api.dart';

/// In-memory stand-in for the server side of the console: sample data, live
/// feeds the test can push into, and a record of what the screens asked for.
class FakeOpsApi implements OpsApi {
  FakeOpsApi({this.meValue});

  OpsMe? meValue;
  final calls = <String>[];

  // live feeds -------------------------------------------------------------
  final serverControllers = <StreamController<Json>>[];
  int serverCancelled = 0;
  final deviceControllers = <StreamController<Json>>[];
  int deviceCancelled = 0;

  StreamController<Json> get lastServer => serverControllers.last;
  StreamController<Json> get lastDevice => deviceControllers.last;

  @override
  Future<OpsMe?> me() async {
    calls.add('me');
    return meValue;
  }

  @override
  Stream<Json> serverFeed() {
    calls.add('serverFeed');
    late StreamController<Json> c;
    c = StreamController<Json>(onCancel: () => serverCancelled++);
    serverControllers.add(c);
    return c.stream;
  }

  @override
  Stream<Json> deviceFeed(String installId) {
    calls.add('deviceFeed:$installId');
    late StreamController<Json> c;
    c = StreamController<Json>(onCancel: () => deviceCancelled++);
    deviceControllers.add(c);
    return c.stream;
  }

  static Json sample(
          {double cpu = 42.5, int memUsed = 235, int memTotal = 1000}) =>
      {
        'type': 'sample',
        'sample': {
          't': DateTime.now().millisecondsSinceEpoch,
          'cpu': {
            'busy': cpu,
            'user': 30.0,
            'system': 10.0,
            'iowait': 2.0,
            'steal': 0.5,
            'cores': [cpu],
            'count': 1
          },
          'load': {
            'l1': 0.52,
            'l5': 0.34,
            'l15': 0.2,
            'running': 1,
            'threads': 118
          },
          'mem': {
            'total': memTotal * 1048576,
            'used': memUsed * 1048576,
            'available': (memTotal - memUsed) * 1048576,
            'swapTotal': 0,
            'swapUsed': 0
          },
          'net': {
            'rxBps': 2048.0,
            'txBps': 4096.0,
            'rxTotal': 5e9,
            'txTotal': 9e9
          },
          'disk': {
            'total': 15e9,
            'used': 4.1e9,
            'free': 10.9e9,
            'readBps': 0.0,
            'writeBps': 1024.0
          },
          'node': {
            'rss': 65 * 1048576,
            'heapUsed': 30 * 1048576,
            'heapTotal': 45 * 1048576,
            'lagMs': 1.2,
            'uptime': 3600
          },
          'system': {
            'uptime': 86400,
            'cpus': 1,
            'kernel': '5.2.0',
            'platform': 'linux'
          },
          'procs': [
            {
              'pid': 1234,
              'name': 'node',
              'cpu': 3.5,
              'rss': 60 * 1048576,
              'state': 'S'
            },
            {
              'pid': 99,
              'name': 'cloudflared',
              'cpu': 0.4,
              'rss': 20 * 1048576,
              'state': 'S'
            },
          ],
          'processCount': 25,
          'pm2': [
            {
              'name': 'smartcook-backend',
              'status': 'online',
              'restarts': 3,
              'mem': 70 * 1048576
            },
            {
              'name': 'smartcook-tunnel',
              'status': 'errored',
              'restarts': 9,
              'mem': 0
            },
          ],
          'mongo': {
            'connections': 7,
            'available': 100,
            'residentMb': 512,
            'opcounters': {'query': 10, 'insert': 2, 'update': 3, 'delete': 1}
          },
          'gpu': {'available': false},
        },
      };

  // overview ---------------------------------------------------------------
  @override
  Future<Json?> overview() async {
    calls.add('overview');
    return {
      'users': 18,
      'newToday': 2,
      'devices': 11,
      'online': 3,
      'restrictions': 1,
      'errorsByBuild': [
        {'build': 16, 'errors': 40, 'devices': 3}
      ],
      'buildMix': [
        {'build': 22, 'devices': 6},
        {'build': 16, 'devices': 5}
      ],
    };
  }

  // devices ----------------------------------------------------------------
  List<Json> deviceRows = [
    {
      'installId': 'install-aaaa-1111',
      'userId': 'u1',
      'user': {'email': 'ani@example.com', 'name': 'Ani'},
      'deviceModel': 'M2006C3MG',
      'manufacturer': 'Xiaomi',
      'osVersion': '10',
      'appBuild': 22,
      'ip': '203.0.113.9',
      'country': 'ID',
      'timezone': 'Asia/Jakarta',
      'online': true,
      'restricted': false,
      'lastSeen': DateTime.now().toIso8601String(),
      'firstSeen':
          DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
      'live': {
        'cpu': 12.3,
        'battery': 80,
        'charging': true,
        'tempC': 33.5,
        'stale': false
      },
    },
    {
      'installId': 'install-bbbb-2222',
      'user': null,
      'deviceModel': 'Pixel 8',
      'manufacturer': 'Google',
      'osVersion': '15',
      'appBuild': 16,
      'ip': '198.51.100.4',
      'country': 'US',
      'online': false,
      'restricted': true,
      'lastSeen':
          DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(),
      'live': null,
    },
  ];

  @override
  Future<List<Json>> devices({String? q, bool online = false}) async {
    calls.add('devices:q=${q ?? ''}:online=$online');
    return deviceRows.where((d) => !online || d['online'] == true).toList();
  }

  @override
  Future<Json?> devicesPage(
      {String? q, bool online = false, int page = 1}) async {
    calls.add('devicesPage:q=${q ?? ''}:online=$online:page=$page');
    final all =
        deviceRows.where((d) => !online || d['online'] == true).toList();
    final pages = all.isEmpty ? 1 : (all.length / 10).ceil();
    final p = page.clamp(1, pages);
    return {
      'items': all.skip((p - 1) * 10).take(10).toList(),
      'total': all.length,
      'page': p,
      'pages': pages,
      'pageSize': 10,
    };
  }

  @override
  Future<Json?> deviceDetail(String installId) async {
    calls.add('deviceDetail:$installId');
    final d = deviceRows.where((r) => r['installId'] == installId);
    if (d.isEmpty) return null;
    return {
      'device': {
        ...d.first,
        'carrier': 'Telkomsel',
        'appVersion': '1.2.0',
        'abi': 'armeabi-v7a',
        'locale': 'id-ID',
        'batches': 4
      },
      'events': [
        {
          'event': 'render_error',
          'level': 'error',
          'action': 'build',
          'error': 'Null check operator used on a null value',
          'createdAt': DateTime.now().toIso8601String()
        },
        {
          'event': 'app_launch',
          'level': 'info',
          'createdAt': DateTime.now().toIso8601String()
        },
      ],
      'logins': [
        {
          'ip': '203.0.113.9',
          'via': 'google',
          'at': DateTime.now().toIso8601String()
        },
      ],
      'live': d.first['live'],
    };
  }

  // restrictions -----------------------------------------------------------
  List<Json> rules = [
    {
      'id': 'r1',
      'kind': 'ip',
      'value': '203.0.113.0/24',
      'reason': 'abuse',
      'by': 'boss@example.com',
      'createdAt': DateTime.now().toIso8601String(),
      'until': null
    },
    {
      'id': 'r2',
      'kind': 'email',
      'value': 'bad@example.com',
      'reason': '',
      'by': 'boss@example.com',
      'createdAt': DateTime.now().toIso8601String(),
      'until': DateTime.now().add(const Duration(days: 7)).toIso8601String()
    },
  ];
  String? restrictError;
  final restricted = <Json>[];

  @override
  Future<List<Json>> restrictions() async {
    calls.add('restrictions');
    return List<Json>.from(rules);
  }

  @override
  Future<Json?> restrictionsPage({String? kind, int page = 1}) async {
    calls.add('restrictionsPage:${kind ?? 'all'}:$page');
    final all = rules.where((r) => kind == null || r['kind'] == kind).map((r) {
      final until = DateTime.tryParse('${r['until'] ?? ''}');
      return {
        ...r,
        'remainingSeconds': until == null
            ? null
            : until.difference(DateTime.now()).inSeconds.clamp(1, 1 << 30),
      };
    }).toList();
    final pages = all.isEmpty ? 1 : (all.length / 10).ceil();
    final p = page.clamp(1, pages);
    return {
      'items': all.skip((p - 1) * 10).take(10).toList(),
      'total': all.length,
      'page': p,
      'pages': pages,
      'pageSize': 10,
    };
  }

  @override
  Future<String?> restrict(
      {String? ip, String? email, String reason = '', DateTime? until}) async {
    calls.add('restrict');
    if (restrictError != null) return restrictError;
    restricted
        .add({'ip': ip, 'email': email, 'reason': reason, 'until': until});
    return null;
  }

  @override
  Future<bool> lift(String id) async {
    calls.add('lift:$id');
    rules.removeWhere((r) => r['id'] == id);
    return true;
  }

  @override
  Future<List<Json>> trail() async {
    calls.add('trail');
    return [
      {
        'who': 'boss@example.com',
        'action': 'restriction.add',
        'target': 'ip:203.0.113.0/24',
        'at': DateTime.now().toIso8601String()
      },
    ];
  }

  @override
  Future<List<Json>> logs({String? level, int? build}) async {
    calls.add('logs:${level ?? 'all'}');
    return [
      {
        'event': 'render_error',
        'level': 'error',
        'error': 'Null check operator used on a null value',
        'deviceModel': 'M2006C3MG',
        'deviceManufacturer': 'Xiaomi',
        'osVersion': '10',
        'appBuild': 16,
        'createdAt': DateTime.now().toIso8601String()
      },
    ];
  }

  @override
  Future<List<Json>> users({String? q}) async {
    calls.add('users:${q ?? ''}');
    return [
      {
        'id': 'u1',
        'email': 'ani@example.com',
        'name': 'Ani',
        'provider': 'google',
        'devices': 2,
        'suspended': false,
        'verifiedWithGoogle': true,
        'createdAt': DateTime.now().toIso8601String()
      },
      {
        'id': 'u2',
        'email': 'budi@example.com',
        'name': '',
        'provider': 'email',
        'devices': 0,
        'suspended': true,
        'verifiedWithGoogle': false,
        'createdAt': DateTime.now().toIso8601String()
      },
    ];
  }

  @override
  Future<Json?> userDetail(String id) async {
    calls.add('userDetail:$id');
    final u = (await users()).firstWhere((e) => e['id'] == id);
    return {
      'user': {...u, 'onboarded': true},
      'devices': [
        {
          'installId': 'install-aaaa-1111',
          'deviceModel': 'M2006C3MG',
          'manufacturer': 'Xiaomi',
          'ip': '203.0.113.9',
          'lastSeen': DateTime.now().toIso8601String()
        },
      ],
      'logins': [
        {
          'ip': '203.0.113.9',
          'via': 'google',
          'at': DateTime.now().toIso8601String()
        },
      ],
    };
  }

  // members ----------------------------------------------------------------
  List<Json> memberRows = [
    {
      'email': 'adm@example.com',
      'perms': ['logs', 'devices'],
      'active': true
    },
  ];

  @override
  Future<Json?> members() async {
    calls.add('members');
    return {
      'owners': ['boss@example.com'],
      'members': memberRows,
      'allPerms': [
        'monitor',
        'devices',
        'live',
        'people',
        'restrict',
        'logs',
        'trail',
        'members',
        'notice'
      ],
    };
  }

  String? memberError;
  final added = <Json>[];

  @override
  Future<String?> addMember(String email, List<String> perms) async {
    calls.add('addMember');
    if (memberError != null) return memberError;
    added.add({'email': email, 'perms': perms});
    memberRows.add({'email': email, 'perms': perms, 'active': true});
    return null;
  }

  @override
  Future<String?> updateMember(String email,
      {List<String>? perms, bool? active}) async {
    calls.add('updateMember:$email:${perms ?? ''}:${active ?? ''}');
    return null;
  }

  @override
  Future<bool> removeMember(String email) async {
    calls.add('removeMember:$email');
    memberRows.removeWhere((m) => m['email'] == email);
    return true;
  }

  // notice -----------------------------------------------------------------
  Json noticeValue = {
    'id_text': 'Perawatan malam ini',
    'en_text': 'Maintenance tonight',
    'active': true
  };

  @override
  Future<Json?> notice() async {
    calls.add('notice');
    return noticeValue;
  }

  @override
  Future<String?> setNotice(
      {String idText = '',
      String enText = '',
      bool active = false,
      DateTime? until,
      String mode = 'always'}) async {
    calls.add('setNotice:$active:$idText:$mode:${until != null}');
    noticeValue = {
      'id_text': idText,
      'en_text': enText,
      'active': active,
      'mode': mode
    };
    return null;
  }
}
