import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../core/services/secure_channel.dart';
import '../service/api_service.dart';

/// What the signed-in account may do here. Empty/absent for everybody else.
class OpsMe {
  const OpsMe({required this.role, required this.perms});
  final String role;
  final Set<String> perms;

  bool get isOwner => role == 'owner';
  bool can(String perm) => perms.contains(perm);

  static OpsMe? fromJson(dynamic j) {
    if (j is! Map) return null;
    final perms = j['perms'];
    return OpsMe(
      role: j['role']?.toString() ?? 'member',
      perms:
          perms is List ? perms.map((e) => e.toString()).toSet() : <String>{},
    );
  }
}

typedef Json = Map<String, dynamic>;

/// Everything the console screens need. The real one talks to the server; the
/// tests and the emulator harness use a fake with sample data.
abstract class OpsApi {
  Future<OpsMe?> me();

  Stream<Json> serverFeed();
  Future<Json?> overview();

  Future<List<Json>> devices({String? q, bool online = false});

  /// One page (10 rows) of the device registry: items, total, page, pages.
  Future<Json?> devicesPage({String? q, bool online = false, int page = 1});
  Future<Json?> deviceDetail(String installId);
  Stream<Json> deviceFeed(String installId);

  Future<List<Json>> restrictions();

  /// One page (10 rows) of live restrictions: items, total, page, pages.
  Future<Json?> restrictionsPage({String? kind, int page = 1});
  Future<String?> restrict(
      {String? ip, String? email, String reason = '', DateTime? until});
  Future<bool> lift(String id);

  Future<List<Json>> trail();
  Future<List<Json>> logs({String? level, int? build});
  Future<List<Json>> users({String? q});
  Future<Json?> userDetail(String id);

  Future<Json?> members();
  Future<String?> addMember(String email, List<String> perms);
  Future<String?> updateMember(String email,
      {List<String>? perms, bool? active});
  Future<bool> removeMember(String email);

  Future<Json?> notice();
  Future<String?> setNotice(
      {String idText = '',
      String enText = '',
      bool active = false,
      DateTime? until,
      String mode = 'always'});
}

/// The real thing. Every call is a normal API call (sealed like all others);
/// a request the server refuses just comes back empty.
class HttpOpsApi implements OpsApi {
  const HttpOpsApi();

  static const _base = '/api/ops';

  Future<ApiResponse> _get(String path, [Map<String, String>? q]) =>
      ApiService.get('$_base$path', queryParameters: q);

  List<Json> _list(ApiResponse r) {
    final d = r.success ? r.data : null;
    if (d is! List) return const [];
    return [
      for (final e in d)
        if (e is Map) Json.from(e)
    ];
  }

  Json? _map(ApiResponse r) {
    final d = r.success ? r.data : null;
    return d is Map ? Json.from(d) : null;
  }

  @override
  Future<OpsMe?> me() async {
    final r = await ApiService.get('$_base/me');
    return r.success ? OpsMe.fromJson(r.data) : null;
  }

  @override
  Future<Json?> overview() async => _map(await _get('/overview'));

  @override
  Future<List<Json>> devices({String? q, bool online = false}) async =>
      _list(await _get('/devices', {
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        if (online) 'online': '1',
        'limit': '50',
      }));

  @override
  Future<Json?> devicesPage(
          {String? q, bool online = false, int page = 1}) async =>
      _map(await _get('/devices', {
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        if (online) 'online': '1',
        'page': '$page',
        'pageSize': '10',
      }));

  @override
  Future<Json?> deviceDetail(String installId) async =>
      _map(await _get('/devices/${Uri.encodeComponent(installId)}'));

  @override
  Future<List<Json>> restrictions() async => _list(await _get('/restrictions'));

  @override
  Future<Json?> restrictionsPage({String? kind, int page = 1}) async =>
      _map(await _get('/restrictions', {
        if (kind != null) 'kind': kind,
        'page': '$page',
        'pageSize': '10',
      }));

  @override
  Future<String?> restrict(
      {String? ip, String? email, String reason = '', DateTime? until}) async {
    final r = await ApiService.post('$_base/restrictions', body: {
      if (ip != null && ip.trim().isNotEmpty) 'ip': ip.trim(),
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      'reason': reason.trim(),
      if (until != null) 'until': until.toUtc().toIso8601String(),
    });
    return r.success ? null : (r.message ?? 'error');
  }

  @override
  Future<bool> lift(String id) async => (await ApiService.delete(
          '$_base/restrictions/${Uri.encodeComponent(id)}'))
      .success;

  @override
  Future<List<Json>> trail() async =>
      _list(await _get('/trail', {'limit': '60'}));

  @override
  Future<List<Json>> logs({String? level, int? build}) async =>
      _list(await _get('/logs', {
        if (level != null) 'level': level,
        if (build != null) 'build': '$build',
        'limit': '60',
      }));

  @override
  Future<List<Json>> users({String? q}) async => _list(await _get('/users', {
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        'limit': '50',
      }));

  @override
  Future<Json?> userDetail(String id) async =>
      _map(await _get('/users/${Uri.encodeComponent(id)}'));

  @override
  Future<Json?> members() async => _map(await _get('/members'));

  @override
  Future<String?> addMember(String email, List<String> perms) async {
    final r = await ApiService.post('$_base/members',
        body: {'email': email.trim(), 'perms': perms});
    return r.success ? null : (r.message ?? 'error');
  }

  @override
  Future<String?> updateMember(String email,
      {List<String>? perms, bool? active}) async {
    final r = await ApiService.patch(
        '$_base/members/${Uri.encodeComponent(email)}',
        body: {
          if (perms != null) 'perms': perms,
          if (active != null) 'active': active,
        });
    return r.success ? null : (r.message ?? 'error');
  }

  @override
  Future<bool> removeMember(String email) async =>
      (await ApiService.delete('$_base/members/${Uri.encodeComponent(email)}'))
          .success;

  @override
  Future<Json?> notice() async => _map(await _get('/notice'));

  @override
  Future<String?> setNotice(
      {String idText = '',
      String enText = '',
      bool active = false,
      DateTime? until,
      String mode = 'always'}) async {
    final r = await ApiService.put('$_base/notice', body: {
      'idText': idText,
      'enText': enText,
      'active': active,
      'mode': mode,
      if (until != null) 'until': until.toUtc().toIso8601String(),
    });
    return r.success ? null : (r.message ?? 'error');
  }

  // ------------------------------------------------------------- live feeds
  @override
  Stream<Json> serverFeed() => _feed('$_base/stream/server');

  @override
  Stream<Json> deviceFeed(String installId) =>
      _feed('$_base/stream/device/${Uri.encodeComponent(installId)}');

  /// One sealed server-sent-events connection; cancelling the subscription
  /// closes it. Ends quietly on any failure (the screen shows "reconnecting").
  Stream<Json> _feed(String path) async* {
    final headers = await ApiService.requestHeaders();
    headers['Accept'] = 'text/event-stream';
    final request = http.Request('GET', Uri.parse('${ApiConfig.baseUrl}$path'))
      ..headers.addAll(headers);
    http.StreamedResponse response;
    try {
      response = await SecureHttpClient.shared
          .send(request)
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      debugPrint('[ops] feed failed: $e');
      return;
    }
    if (response.statusCode != 200) return;
    var buffer = '';
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      buffer += chunk;
      final parts = buffer.split('\n\n');
      buffer = parts.removeLast();
      for (final part in parts) {
        for (final line in part.split('\n')) {
          if (!line.startsWith('data: ')) continue;
          try {
            final j = jsonDecode(line.substring(6));
            if (j is Map) yield Json.from(j);
          } catch (_) {}
        }
      }
    }
  }
}
