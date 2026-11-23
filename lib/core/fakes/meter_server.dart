// THE BACKEND. Don't edit this file: it plays the part Kwanele
// Municipality's API plays, and your app must work with it as it is. Read
// README.md for its contract.
//
// It is a Dio HttpClientAdapter: your Dio client sends it real requests
// (method, path, headers, JSON body) and gets real responses back (status
// codes, JSON bodies, ProblemDetails), as it would from a server. Nothing
// leaves the phone, and restarting the app resets everything.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Kwanele Municipality's meter-reading API, in memory.
final class MeterServer implements HttpClientAdapter {
  /// Creates the server with its seed data.
  ///
  /// [latency] is the pretend network time for every request. [roundDone]
  /// seeds Thandeka's round with every meter already read. [clock] decides
  /// when access tokens run out (five minutes after they're issued).
  new({
    this.latency = const Duration(milliseconds: 400),
    bool roundDone = false,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       _meters = _seedMeters(roundDone: roundDone);

  /// How long every request takes.
  final Duration latency;

  final DateTime Function() _clock;

  /// False: no signal. Every request fails as a phone with no signal would,
  /// before it reaches the server. The Test tools sheet switches it.
  bool online = true;

  /// How many times POST /auth/refresh has been called.
  int refreshCalls = 0;

  /// How many requests reached the server (not those sent with no signal).
  int requestsReceived = 0;

  final Map<String, Map<String, Object?>> _meters;
  final Map<String, List<Map<String, Object?>>> _readings = {};
  final Map<String, Map<String, Object?>> _idempotent = {};
  final Map<String, _Access> _access = {};
  final Map<String, _Refresh> _refresh = {};
  bool _lostResponseUsed = false;
  int _tokens = 0;

  static const _password = 'Kwanele-2026';
  static const _readers = {
    'thandeka@kwanele.test': 'Thandeka Mokoena',
    'sipho@kwanele.test': 'Sipho Dlamini',
  };
  static const _rounds = {
    'thandeka@kwanele.test': ('R7', 'Round 7 · Kwanele Ext 4'),
    'sipho@kwanele.test': ('R8', 'Round 8 · Kwanele Ext 5'),
  };
  static const _pageSize = 10;
  static const _accessLife = Duration(minutes: 5);

  /// Every access token issued so far stops working at once, as if five
  /// minutes had passed. The next request with one gets a 401.
  void expireAccessTokens() {
    for (final token in _access.values) {
      token.expired = true;
    }
  }

  /// Signs [email] in without the app: a refresh token the app can start
  /// from, as if it had been stored at an earlier sign-in. For tests.
  String issueRefreshTokenFor(String email) =>
      _issue(email)['refreshToken']! as String;

  /// Every reading the server holds for [meterId] this cycle.
  List<Map<String, Object?>> readingsFor(String meterId) => [
    ...?_readings[meterId],
  ];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await Future<void>.delayed(latency);
    if (!online) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'No signal',
        error: const SocketException('Network is unreachable'),
      );
    }
    requestsReceived++;
    final method = options.method.toUpperCase();
    final path = options.uri.pathSegments.where((s) => s.isNotEmpty).toList();
    // Every endpoint is under /v1.
    if (path.isEmpty || path.first != 'v1') {
      return _problem(404, 'Not Found', 'No such endpoint.');
    }
    final segments = path.sublist(1);
    final body = switch (options.data) {
      final Map<String, Object?> map => map,
      final String text when text.isNotEmpty => _decode(text),
      _ => const <String, Object?>{},
    };

    switch ((method, segments)) {
      case ('POST', ['auth', 'sign-in']):
        return _signIn(body);
      case ('POST', ['auth', 'refresh']):
        return _refreshToken(body);
      case ('POST', ['auth', 'sign-out']):
        final token = _refresh[body['refreshToken']];
        if (token != null) _revokeFamily(token.family);
        return _empty(204);
      default:
        break;
    }

    // Everything else needs a live access token.
    final reader = _readerFor(options);
    if (reader == null) {
      return _problem(401, 'Unauthorized', 'Sign in again.');
    }
    final (roundId, roundName) = _rounds[reader]!;

    switch ((method, segments)) {
      case ('GET', ['round', 'today']):
        return _round(
          roundId,
          roundName,
          options.uri.queryParameters['pageToken'],
        );
      case ('GET', ['meters', final id]):
        final meter = _meterOf(roundId, id);
        if (meter == null) return _meterNotFound();
        if (id == 'M-1012') {
          return _problem(
            500,
            'Internal Server Error',
            'An error occurred while processing your request.',
            traceId: '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01',
          );
        }
        return _json(200, _meterWire(meter));
      case ('GET', ['meters', final id, 'readings']):
        final meter = _meterOf(roundId, id);
        if (meter == null) return _meterNotFound();
        return _json(200, {
          'meterId': id,
          'readings': [
            for (final previous in meter['history']! as List<Object?>) previous,
          ],
        });
      case ('POST', ['meters', final id, 'readings']):
        final meter = _meterOf(roundId, id);
        if (meter == null) return _meterNotFound();
        return _postReading(options, meter, body);
      default:
        return _problem(404, 'Not Found', 'No such endpoint.');
    }
  }

  @override
  void close({bool force = false}) {}

  // --- auth -------------------------------------------------------------

  ResponseBody _signIn(Map<String, Object?> body) {
    final email = '${body['email'] ?? ''}'.trim().toLowerCase();
    if (!_readers.containsKey(email) || body['password'] != _password) {
      return _problem(
        401,
        'Unauthorized',
        "That email and password don't match.",
      );
    }
    return _json(200, _issue(email));
  }

  ResponseBody _refreshToken(Map<String, Object?> body) {
    refreshCalls++;
    final presented = _refresh[body['refreshToken']];
    if (presented == null || presented.revoked) {
      return _problem(401, 'Unauthorized', 'Sign in again.');
    }
    if (presented.spent) {
      // A refresh token used twice was copied: end every session it led to.
      _revokeFamily(presented.family);
      return _problem(401, 'Unauthorized', 'Sign in again.');
    }
    presented.spent = true;
    return _json(200, _issue(presented.email, family: presented.family));
  }

  Map<String, Object?> _issue(String email, {int? family}) {
    final n = ++_tokens;
    final accessToken = 'at-$n-${email.split('@').first}';
    final refreshToken = 'rt-$n-${email.split('@').first}';
    final familyId = family ?? n;
    _access[accessToken] = _Access(email, _clock().add(_accessLife), familyId);
    _refresh[refreshToken] = _Refresh(email, familyId);
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'expiresIn': _accessLife.inSeconds,
      'readerName': _readers[email],
      'email': email,
    };
  }

  void _revokeFamily(int family) {
    for (final token in _refresh.values) {
      if (token.family == family) token.revoked = true;
    }
    for (final token in _access.values) {
      if (token.family == family) token.expired = true;
    }
  }

  String? _readerFor(RequestOptions options) {
    final header = _header(options, 'authorization');
    if (header == null || !header.startsWith('Bearer ')) return null;
    final token = _access[header.substring('Bearer '.length)];
    if (token == null || token.expired) return null;
    if (!_clock().isBefore(token.expiresAt)) return null;
    return token.email;
  }

  // --- the round --------------------------------------------------------

  ResponseBody _round(String roundId, String roundName, String? pageToken) {
    final meters = _meters.values.where((m) => m['roundId'] == roundId);
    final all = meters.toList();
    final start = switch (pageToken) {
      null || '' => 0,
      final token when token.startsWith('p') =>
        ((int.tryParse(token.substring(1)) ?? 1) - 1) * _pageSize,
      _ => -1,
    };
    if (start < 0 || start > all.length) {
      return _problem(400, 'Bad Request', 'That page token is not valid.');
    }
    final end = (start + _pageSize).clamp(0, all.length);
    final page = start ~/ _pageSize + 1;
    return _json(200, {
      'roundId': roundId,
      'roundName': roundName,
      'date': _saDate(_clock()),
      'totalMeters': all.length,
      'metersLeft': all.where((m) => m['status'] == 'Due').length,
      'meters': [for (final meter in all.sublist(start, end)) _summary(meter)],
      // The last page leaves nextPageToken out altogether.
      if (end < all.length) 'nextPageToken': 'p${page + 1}',
    });
  }

  Map<String, Object?>? _meterOf(String roundId, String id) {
    final meter = _meters[id];
    // Another reader's meter is "not found", as if it didn't exist.
    return meter == null || meter['roundId'] != roundId ? null : meter;
  }

  ResponseBody _meterNotFound() =>
      _problem(404, 'Not Found', 'There is no meter with that id.');

  Map<String, Object?> _summary(Map<String, Object?> meter) => {
    'id': meter['id'],
    'address': meter['address'],
    'meterNumber': meter['meterNumber'],
    'status': meter['status'],
  };

  Map<String, Object?> _meterWire(Map<String, Object?> meter) {
    final readings = _readings[meter['id']] ?? const [];
    return {
      'id': meter['id'],
      'address': meter['address'],
      'meterNumber': meter['meterNumber'],
      'accountNumber': meter['accountNumber'],
      'status': meter['status'],
      'lastReading': meter['lastReading'],
      'lastReadOn': meter['lastReadOn'],
      'thisCycle': readings.isEmpty ? null : readings.last,
      'readingsThisCycle': readings.length,
    };
  }

  // --- readings ---------------------------------------------------------

  ResponseBody _postReading(
    RequestOptions options,
    Map<String, Object?> meter,
    Map<String, Object?> body,
  ) {
    final key = _header(options, 'idempotency-key');
    if (key == null || key.isEmpty) {
      return _problem(
        400,
        'Bad Request',
        'Send an Idempotency-Key header with every reading.',
      );
    }
    // The same key again: the same answer again, and nothing stored twice.
    if (_idempotent[key] case final earlier?) {
      return _json(201, earlier, headers: {'idempotent-replayed': 'true'});
    }

    final value = body['value'];
    final replaced = body['meterReplaced'] == true;
    final last = meter['lastReading']! as int;
    if (value is! int || value < 0 || value > 9999999) {
      return _validation({
        'value': ['Enter the reading in whole kWh, from 0 to 9 999 999.'],
      });
    }
    if (value < last && !replaced) {
      return _validation({
        'value': [_lowerThanLast(last)],
      });
    }

    final consumption = replaced ? value : value - last;
    final readings = _readings.putIfAbsent(meter['id']! as String, () => []);
    // Two readings in one cycle: the server keeps both, and the billing
    // office has to query which is right.
    meter['status'] = readings.isEmpty ? 'Read' : 'Query';
    final reading = <String, Object?>{
      'readingId': 'RD-${meter['id']}-${readings.length + 1}',
      'meterId': meter['id'],
      'value': value,
      'meterReplaced': replaced,
      'consumption': consumption,
      // The server decides what's unusual: more than 1 500 kWh in a month.
      'flagged': consumption > 1500,
      'readAt': _clock().toUtc().toIso8601String(),
      'status': meter['status'],
    };
    readings.add(reading);
    _idempotent[key] = reading;

    // M-1007's first reading reaches the server and is stored, but the
    // answer never reaches the phone: the signal drops on the way back.
    if (meter['id'] == 'M-1007' && !_lostResponseUsed) {
      _lostResponseUsed = true;
      throw DioException.receiveTimeout(
        timeout: const Duration(seconds: 20),
        requestOptions: options,
      );
    }
    return _json(201, reading);
  }

  ResponseBody _validation(Map<String, List<String>> errors) => _problem(
    400,
    'One or more validation errors occurred.',
    null,
    extra: {'errors': errors},
  );

  // --- wire helpers -----------------------------------------------------

  int _traces = 0;

  ResponseBody _problem(
    int status,
    String title,
    String? detail, {
    String? traceId,
    Map<String, Object?> extra = const {},
  }) => _json(status, {
    'type': 'https://tools.ietf.org/html/rfc9110#section-15',
    'title': title,
    'status': status,
    'detail': ?detail,
    'traceId':
        traceId ??
        '00-${(++_traces).toRadixString(16).padLeft(32, 'a')}-'
            '00f067aa0ba902b7-01',
    ...extra,
  }, contentType: 'application/problem+json');

  ResponseBody _json(
    int status,
    Object? body, {
    Map<String, String> headers = const {},
    String contentType = 'application/json',
  }) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: ['$contentType; charset=utf-8'],
      for (final MapEntry(:key, :value) in headers.entries) key: [value],
    },
  );

  ResponseBody _empty(int status) => ResponseBody.fromString('', status);

  static Map<String, Object?> _decode(String text) =>
      switch (jsonDecode(text)) {
        final Map<String, Object?> map => map,
        _ => const {},
      };

  static String? _header(RequestOptions options, String name) {
    for (final MapEntry(:key, :value) in options.headers.entries) {
      if (key.toLowerCase() == name) return '$value';
    }
    return null;
  }

  static String _lowerThanLast(int last) =>
      "That's lower than the last reading (${_kwh(last)} kWh). If the meter "
      'was replaced, tick "Meter replaced".';

  static String _kwh(int value) {
    final digits = '$value';
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(' ');
      out.write(digits[i]);
    }
    return '$out';
  }

  // South Africa is UTC+2 all year.
  static String _saDate(DateTime now) => now
      .toUtc()
      .add(const Duration(hours: 2))
      .toIso8601String()
      .substring(0, 10);

  static Map<String, Map<String, Object?>> _seedMeters({
    required bool roundDone,
  }) {
    const streets = [
      ('M-1001', '2 Lwandle Street', 'KW-58210431', 'ACC-400311', 48213),
      ('M-1002', '4 Lwandle Street', 'KW-58210432', 'ACC-400312', 30115),
      ('M-1003', '6 Lwandle Street', 'KW-58210433', 'ACC-400313', 12907),
      ('M-1004', '8 Lwandle Street', 'KW-58210434', 'ACC-400314', 66340),
      ('M-1005', '1 Isibaya Crescent', 'KW-58210435', 'ACC-400315', 22058),
      ('M-1006', '3 Isibaya Crescent', 'KW-58210436', 'ACC-400316', 9876),
      ('M-1007', '5 Isibaya Crescent', 'KW-58210437', 'ACC-400317', 30876),
      ('M-1008', '7 Isibaya Crescent', 'KW-58210438', 'ACC-400318', 51200),
      ('M-1009', '11 Umthombo Road', 'KW-58210439', 'ACC-400319', 7710),
      ('M-1010', '13 Umthombo Road', 'KW-58210440', 'ACC-400320', 40433),
      ('M-1011', '15 Umthombo Road', 'KW-58210441', 'ACC-400321', 18342),
      ('M-1012', '17 Umthombo Road', 'KW-58210442', 'ACC-400322', 27561),
      ('M-1013', '19 Umthombo Road', 'KW-58210443', 'ACC-400323', 35009),
      ('M-1014', '21 Umthombo Road', 'KW-58210444', 'ACC-400324', 61988),
      ('M-2001', '9 Ndlovu Lane', 'KW-58290101', 'ACC-500101', 14420),
      ('M-2002', '12 Ndlovu Lane', 'KW-58290102', 'ACC-500102', 25031),
    ];
    const readAlready = {'M-1003', 'M-1009', 'M-1013'};
    return {
      for (final (id, address, number, account, last) in streets)
        id: {
          'id': id,
          'roundId': id.startsWith('M-1') ? 'R7' : 'R8',
          'address': address,
          'meterNumber': number,
          'accountNumber': account,
          'lastReading': last,
          'lastReadOn': '2026-10-23',
          'status': roundDone || readAlready.contains(id) ? 'Read' : 'Due',
          'history': [
            {'value': last, 'readOn': '2026-10-23'},
            {'value': last - 412, 'readOn': '2026-09-23'},
            {'value': last - 790, 'readOn': '2026-08-24'},
          ],
        },
    };
  }
}

final class _Access {
  new(this.email, this.expiresAt, this.family);
  final String email;
  final DateTime expiresAt;
  final int family;
  bool expired = false;
}

final class _Refresh {
  new(this.email, this.family);
  final String email;
  final int family;
  bool spent = false;
  bool revoked = false;
}
