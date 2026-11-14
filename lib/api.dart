import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';

/// An error from the API, with a message that is safe to show residents.
class ApiException implements Exception {
  ApiException(this.message, {this.status, this.field});
  final String message;
  final int? status;
  final String? field;
  bool get unauthorized => status == 401;
  @override
  String toString() => message;
}

/// Thin client for the CivicSpeak resident API (/api/...).
class ApiClient {
  ApiClient({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;
  String? token;

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = apiBaseUrl.endsWith('/') ? apiBaseUrl.substring(0, apiBaseUrl.length - 1) : apiBaseUrl;
    return Uri.parse('$base/api/$path').replace(queryParameters: query);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> _send(Future<http.Response> Function() call) async {
    http.Response res;
    try {
      res = await call().timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw ApiException("The server took too long to answer. Check your connection and try again.");
    } catch (_) {
      throw ApiException("Can't reach CivicSpeak right now. Check your connection and try again.");
    }
    Map<String, dynamic> data = {};
    if (res.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {
        // Not JSON (for example an HTML error page).
      }
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    throw ApiException(
      (data['error'] as String?) ?? 'Something went wrong (error ${res.statusCode}). Please try again.',
      status: res.statusCode,
      field: data['field'] as String?,
    );
  }

  Future<Map<String, dynamic>> get(String path, [Map<String, String>? query]) =>
      _send(() => _http.get(_uri(path, query), headers: _headers));

  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) =>
      _send(() => _http.post(_uri(path), headers: _headers, body: jsonEncode(body ?? {})));

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) =>
      _send(() => _http.patch(_uri(path), headers: _headers, body: jsonEncode(body)));

  // ---- endpoints
  Future<Map<String, dynamic>> meta() => get('meta/');
  Future<Map<String, dynamic>> register(Map<String, dynamic> body) => post('auth/register/', body);
  Future<Map<String, dynamic>> login(String username, String password) =>
      post('auth/login/', {'username': username, 'password': password});
  Future<Map<String, dynamic>> me() => get('me/');
  Future<Map<String, dynamic>> updateMe(Map<String, dynamic> body) => patch('me/', body);

  Future<List<Map<String, dynamic>>> proposals(String status) async {
    final data = await get('proposals/', {'status': status});
    return List<Map<String, dynamic>>.from(data['results'] as List? ?? const []);
  }

  Future<Map<String, dynamic>> proposal(int id) => get('proposals/$id/');
  Future<bool> toggleFollow(int id) async => (await post('proposals/$id/follow/'))['following'] == true;
  Future<Map<String, dynamic>> sendFeedback(int id, String choice, String comment) =>
      post('proposals/$id/feedback/', {'choice': choice, 'comment': comment});
  Future<Map<String, dynamic>> funding(int id) => get('proposals/$id/funding/');
  Future<Map<String, dynamic>> mapPins(String status, bool onlyFollowing) =>
      get('map/', {'status': status, if (onlyFollowing) 'only_following': '1'});
  Future<Map<String, dynamic>> community() => get('community/');
  Future<Map<String, dynamic>> notifications() => get('notifications/');
  Future<void> markNotificationsRead() => post('notifications/read/');
  Future<void> registerDevice(String token, String platform) => post('devices/', {'token': token, 'platform': platform});
  Future<void> unregisterDevice(String token) => post('devices/remove/', {'token': token});
}
