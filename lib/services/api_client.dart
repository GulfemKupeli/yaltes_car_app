import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaltes_car_app/app_constants.dart';
import 'package:yaltes_car_app/models/bookings.dart';

class ApiClient {
  ApiClient._internal();
  static final ApiClient instance = ApiClient._internal();

  String? _token;
  String? get token => _token;
  void setToken(String? t) => _token = t;

  String get _base => AppConstants.BASE_URL;

  dynamic _json(http.Response r) => jsonDecode(utf8.decode(r.bodyBytes));
  String _text(http.Response r) => utf8.decode(r.bodyBytes);
  bool _ok(http.Response r) => r.statusCode >= 200 && r.statusCode < 300;

  Map<String, String> _headers({bool json = true}) => {
    if (json) 'Content-Type': 'application/json; charset=utf-8',
    'accept': 'application/json; charset=utf-8',
    if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token',
  };

  Future<void> login(String email, String password) async {
    final r = await http.post(
      Uri.parse('$_base/auth/login'),
      headers: _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (_ok(r)) {
      final map = _json(r) as Map<String, dynamic>;
      _token = map['access_token'] as String?;
      await saveToken();
      return;
    }

    final msg = _text(r);
    if (r.statusCode == 422) {
      debugPrint('VALIDATION ERROR: $msg');
      throw Exception('Validation failed: $msg');
    }
    debugPrint('LOGIN ERROR BODY: $msg');
    throw Exception('Login failed with status ${r.statusCode}: $msg');
  }

  Future<Map<String, dynamic>> updateMe({
    String? fullName,
    String? email,
    String? password,
  }) async {
    final body = <String, dynamic>{};
    void putIfNotEmpty(String k, String? v) {
      final t = (v ?? '').trim();
      if (t.isNotEmpty) body[k] = t;
    }

    putIfNotEmpty('full_name', fullName);
    putIfNotEmpty('email', email);
    putIfNotEmpty('password', password);

    final r = await http.put(
      Uri.parse('$_base/me'),
      headers: _headers(),
      body: jsonEncode(body),
    );

    if (!_ok(r)) {
      if (r.statusCode == 401 || r.statusCode == 403) {
        await clearToken();
      }
      throw Exception('Update me failed (${r.statusCode}): ${_text(r)}');
    }
    return _json(r) as Map<String, dynamic>;
  }

  Future<void> adminLogin(String email, String password) async {
    final r = await http.post(
      Uri.parse('$_base/admin/login'),
      headers: _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (_ok(r)) {
      final map = _json(r) as Map<String, dynamic>;
      _token = map['access_token'] as String?;
      await saveToken();
      return;
    }

    final msg = _text(r);
    if (r.statusCode == 422) {
      debugPrint('ADMIN VALIDATION ERROR: $msg');
      throw Exception('Validation failed: $msg');
    }
    debugPrint('ADMIN LOGIN ERROR BODY: $msg');
    throw Exception('Admin login failed with status ${r.statusCode}: $msg');
  }

  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final r = await http.post(
      Uri.parse('$_base/auth/register'),
      headers: _headers(),
      body: jsonEncode({
        'full_name': fullName,
        'email': email,
        'password': password,
      }),
    );
    if (_ok(r)) return _json(r) as Map<String, dynamic>;
    if (r.statusCode == 422) throw Exception('Validation failed: ${_text(r)}');
    if (r.statusCode == 400) throw Exception(_text(r));
    throw Exception('Register failed with status ${r.statusCode}: ${_text(r)}');
  }

  Future<Map<String, dynamic>> me() async {
    final r = await http.get(
      Uri.parse('$_base/me'),
      headers: _headers(json: false),
    );
    if (!_ok(r)) throw Exception('Me failed: ${_text(r)}');
    return _json(r) as Map<String, dynamic>;
  }

  static const _kTokenKey = 'jwt';

  Future<void> saveToken() async {
    final sp = await SharedPreferences.getInstance();
    if (_token != null && _token!.isNotEmpty) {
      await sp.setString(_kTokenKey, _token!);
    }
  }

  Future<bool> loadToken() async {
    final sp = await SharedPreferences.getInstance();
    final t = sp.getString(_kTokenKey);
    if (t != null && t.isNotEmpty) {
      _token = t;
      return true;
    }
    return false;
  }

  Future<void> clearToken() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kTokenKey);
    _token = null;
  }

  Future<void> logout() => clearToken();

  Future<List<dynamic>> listVehicles() async {
    final r = await http.get(
      Uri.parse('$_base/vehicles'),
      headers: _headers(json: false),
    );
    if (!_ok(r)) throw Exception('Vehicles error: ${_text(r)}');
    return _json(r) as List<dynamic>;
  }

  Future<Map<String, dynamic>> getVehicle(String id) async {
    final r = await http.get(
      Uri.parse('$_base/vehicles/$id'),
      headers: _headers(json: false),
    );
    if (!_ok(r)) throw Exception('Get vehicle error: ${_text(r)}');
    return _json(r) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createVehicle(Map<String, dynamic> body) async {
    final r = await http.post(
      Uri.parse('$_base/vehicles'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    if (!_ok(r)) throw Exception('Create vehicle error: ${_text(r)}');
    return _json(r) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateVehicle(
    String id,
    Map<String, dynamic> body,
  ) async {
    final r = await http.put(
      Uri.parse('$_base/vehicles/$id'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    if (!_ok(r)) throw Exception('Update vehicle error: ${_text(r)}');
    return _json(r) as Map<String, dynamic>;
  }

  Future<void> deleteVehicle(String id) async {
    final r = await http.delete(
      Uri.parse('$_base/vehicles/$id'),
      headers: _headers(json: false),
    );
    if (!_ok(r)) throw Exception('Delete vehicle error: ${_text(r)}');
  }

  Future<List<dynamic>> listBookings() async {
    final r = await http.get(
      Uri.parse('$_base/bookings'),
      headers: _headers(json: false),
    );
    if (!_ok(r)) throw Exception('Bookings error: ${_text(r)}');
    return _json(r) as List<dynamic>;
  }

  Future<Map<String, dynamic>> approveBooking(String id) async {
    final r = await http.post(
      Uri.parse('$_base/bookings/$id/approve'),
      headers: _headers(json: false),
    );
    if (!_ok(r)) throw Exception('Approve booking error: ${_text(r)}');
    return _json(r) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> cancelBooking(String id) async {
    final r = await http.post(
      Uri.parse('$_base/bookings/$id/cancel'),
      headers: _headers(json: false),
    );
    if (!_ok(r)) throw Exception('Cancel booking error: ${_text(r)}');
    return _json(r) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> completeBooking(String id) async {
    final r = await http.post(
      Uri.parse('$_base/bookings/$id/complete'),
      headers: _headers(json: false),
    );
    if (!_ok(r)) throw Exception('Complete booking error: ${_text(r)}');
    return _json(r) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createBooking({
    required String vehicleId,
    required DateTime startsAt,
    required DateTime endsAt,
    String? purpose,
  }) async {
    final body = {
      'vehicle_id': vehicleId,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
      if (purpose != null && purpose.isNotEmpty) 'purpose': purpose,
    };
    final r = await http.post(
      Uri.parse('$_base/bookings'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    if (!_ok(r)) {
      throw Exception('Create booking error ${r.statusCode}: ${_text(r)}');
    }
    return _json(r) as Map<String, dynamic>;
  }

  Future<List<dynamic>> availability(DateTime from, DateTime to) async {
    final frm = Uri.encodeQueryComponent(from.toUtc().toIso8601String());
    final end = Uri.encodeQueryComponent(to.toUtc().toIso8601String());
    final r = await http.get(
      Uri.parse('$_base/availability?frm=$frm&to=$end'),
      headers: _headers(json: false),
    );
    if (!_ok(r)) throw Exception('Availability error: ${_text(r)}');
    return _json(r) as List<dynamic>;
  }

  Future<String> uploadImage(File file) async {
    final uri = Uri.parse('$_base/upload');

    final req = http.MultipartRequest('POST', uri);
    if (token != null && token!.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $token';
    }

    req.headers['Accept'] = 'application/json; charset=utf-8';

    final ext = p.extension(file.path).toLowerCase();
    final mediaType = (ext == '.png')
        ? MediaType('image', 'png')
        : MediaType('image', 'jpeg');

    req.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: p.basename(file.path),
        contentType: mediaType,
      ),
    );

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    debugPrint(
      'UPLOAD RESP ${res.statusCode} ${res.headers['content-type']} ${_text(res)}',
    );

    if (!_ok(res)) {
      throw Exception('Upload error: ${res.statusCode} ${_text(res)}');
    }
    final data = _json(res) as Map<String, dynamic>;
    return data['url'] as String;
  }

  Future<List<Booking>> myBookings() async {
    final r = await http.get(
      Uri.parse('$_base/bookings/me'),
      headers: _headers(json: false),
    );
    if (!_ok(r)) {
      throw Exception('My bookings error: ${_text(r)}');
    }
    final arr = _json(r) as List<dynamic>;
    return arr.map((e) => Booking.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> registerPushToken(String token, {String? platform}) async {
    final r = await http.post(
      Uri.parse('$_base/devices/register'),
      headers: _headers(),
      body: jsonEncode({
        'token': token,
        if (platform != null) 'platform': platform,
      }),
    );
    if (!_ok(r)) {
      throw Exception('Push token register failed: ${_text(r)}');
    }
  }
}
