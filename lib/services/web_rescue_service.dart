import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/web_rescue.dart';
import 'api_config.dart';

class WebRescueService {
  const WebRescueService();

  static List<WebRescue> _demoRescues = [
    WebRescue(
      id: 101,
      name: 'Demo User 1',
      phone: '0900000001',
      address: 'Quận 1, TP.HCM',
      note: 'Demo rescue task',
      sourceUrl: null,
      victims: 2,
      sosType: 'medical',
      status: 'new',
      lat: 10.775,
      lng: 106.705,
      createdAt: DateTime.now().subtract(const Duration(minutes: 8)),
      assignedRescuers: const [],
    ),
    WebRescue(
      id: 102,
      name: 'Demo User 2',
      phone: '0900000002',
      address: 'TP Thủ Đức',
      note: 'Demo rescue task',
      sourceUrl: null,
      victims: 1,
      sosType: 'fire',
      status: 'rescuing',
      lat: 10.845,
      lng: 106.75,
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      assignedRescuers: const [],
    ),
    WebRescue(
      id: 103,
      name: 'Demo User 3',
      phone: '0900000003',
      address: 'Quận 7, TP.HCM',
      note: 'Demo rescue task',
      sourceUrl: null,
      victims: 4,
      sosType: 'other',
      status: 'done',
      lat: 10.732,
      lng: 106.718,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      assignedRescuers: const [],
    ),
  ];

  // Cache rescue data for 30 seconds
  static List<WebRescue>? _rescueCache;
  static DateTime? _rescueCacheTime;
  static const int _cacheValiditySeconds = 30;

  static bool _isCacheValid() {
    if (_rescueCache == null || _rescueCacheTime == null) return false;
    final diff = DateTime.now().difference(_rescueCacheTime!);
    return diff.inSeconds < _cacheValiditySeconds;
  }

  static void _setCache(List<WebRescue> rescues) {
    _rescueCache = rescues;
    _rescueCacheTime = DateTime.now();
  }

  static List<WebRescue>? _getCache() {
    if (_isCacheValid()) {
      return _rescueCache;
    }
    _rescueCache = null;
    _rescueCacheTime = null;
    return null;
  }

  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) return null;
    return token;
  }

  Future<bool> _isDemoMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('demo_mode') ?? false;
  }

  Future<Map<String, String>> _headers({bool json = true}) async {
    final token = await _token();
    final headers = <String, String>{};
    if (json) {
      headers['Content-Type'] = 'application/json';
    }
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<http.Response> _requestWithFallbacks({
    required String action,
    required Future<http.Response> Function(String baseUrl) request,
  }) async {
    Object? lastError;

    for (final baseUrl in ApiConfig.rescueBaseUrlCandidates()) {
      try {
        final resp = await request(baseUrl);
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          return resp;
        }

        lastError = Exception('$action thất bại: ${resp.statusCode} ${resp.body}');
      } catch (e) {
        lastError = e;
      }
    }

    throw Exception('Không kết nối được tới backend. Lỗi cuối: $lastError');
  }

  Future<List<WebRescue>> getRescues() async {
    if (await _isDemoMode()) {
      return List<WebRescue>.of(_demoRescues);
    }

    // Check cache first
    final cachedRescues = _getCache();
    if (cachedRescues != null) {
      return List<WebRescue>.of(cachedRescues);
    }

    final headers = await _headers();
    final resp = await _requestWithFallbacks(
      action: 'Lấy rescues',
      request: (baseUrl) => http.get(Uri.parse('$baseUrl/rescues'), headers: headers),
    );

    final decoded = jsonDecode(resp.body);
    final list = decoded is List
        ? decoded
        : (decoded is Map && decoded['data'] is List)
            ? decoded['data'] as List
            : <dynamic>[];

    final rescues = list
        .whereType<Map>()
        .map((item) => WebRescue.fromJson(item.cast<String, dynamic>()))
        .toList();

    // Cache the result
    _setCache(rescues);

    return rescues;
  }

  Future<int?> createSos({
    required String name,
    required String phone,
    required String address,
    required String note,
    required int victims,
    required String sosType,
    required double lat,
    required double lng,
    String? sourceUrl,
  }) async {
    if (await _isDemoMode()) {
      final nextId = _demoRescues.isEmpty ? 1 : (_demoRescues.map((item) => item.id).reduce((a, b) => a > b ? a : b) + 1);
      _demoRescues = [
        WebRescue(
          id: nextId,
          name: name,
          phone: phone,
          address: address,
          note: note,
          sourceUrl: sourceUrl,
          victims: victims,
          sosType: sosType,
          status: 'new',
          lat: lat,
          lng: lng,
          createdAt: DateTime.now(),
          assignedRescuers: const [],
        ),
        ..._demoRescues,
      ];
      return nextId;
    }

    final body = {
      'name': name,
      'phone': phone,
      'address': address,
      'note': note,
      'victims': victims,
      'sos_type': sosType,
      'lat': lat,
      'lng': lng,
      'source_url': sourceUrl ?? '',
    };

    final headers = await _headers();
    final resp = await _requestWithFallbacks(
      action: 'Gửi SOS',
      request: (baseUrl) => http.post(Uri.parse('$baseUrl/rescues'), headers: headers, body: jsonEncode(body)),
    );

    if (resp.body.isEmpty) return null;

    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map<String, dynamic>) {
        if (decoded['id'] != null) {
          return _toInt(decoded['id']);
        }
        if (decoded['data'] is Map<String, dynamic>) {
          return _toInt((decoded['data'] as Map<String, dynamic>)['id']);
        }
      }
    } catch (_) {
      // Some backends return plain text or empty body for create.
    }

    return null;
  }

  Future<void> updateSosDetails({
    required int id,
    required String address,
    required String note,
    required int victims,
    required String sosType,
    String? sourceUrl,
  }) async {
    if (await _isDemoMode()) {
      _demoRescues = _demoRescues.map((item) {
        if (item.id != id) return item;
        return WebRescue(
          id: item.id,
          name: item.name,
          phone: item.phone,
          address: address,
          note: note,
          sourceUrl: sourceUrl ?? item.sourceUrl,
          victims: victims,
          sosType: sosType,
          status: item.status,
          lat: item.lat,
          lng: item.lng,
          createdAt: item.createdAt,
          assignedRescuers: item.assignedRescuers,
        );
      }).toList();
      return;
    }

    final payload = {
      'address': address,
      'note': note,
      'victims': victims,
      'sos_type': sosType,
      'source_url': sourceUrl ?? '',
    };

    final paths = <String>['/rescues/$id', '/rescues/$id/details'];
    Object? lastError;
    final headers = await _headers();

    for (final path in paths) {
      try {
        await _requestWithFallbacks(
          action: 'Cập nhật SOS',
          request: (baseUrl) => http.patch(
            Uri.parse('$baseUrl$path'),
            headers: headers,
            body: jsonEncode(payload),
          ),
        );
        return;
      } catch (e) {
        lastError = e;
      }
    }

    throw Exception('Không cập nhật được thông tin SOS #$id. Lỗi cuối: $lastError');
  }

  Future<void> updateRescueStatus(int id, String status) async {
    if (await _isDemoMode()) {
      _demoRescues = _demoRescues
          .map((item) => item.id == id ? item.copyWith(status: status) : item)
          .toList();
      return;
    }

    final paths = <String>['/rescues/$id/status', '/rescues/$id'];
    Object? lastError;
    final headers = await _headers();

    for (final path in paths) {
      try {
        await _requestWithFallbacks(
          action: 'Cập nhật trạng thái rescue',
          request: (baseUrl) => http.patch(
            Uri.parse('$baseUrl$path'),
            headers: headers,
            body: jsonEncode({'status': status}),
          ),
        );
        return;
      } catch (e) {
        lastError = e;
      }
    }

    throw Exception('Không cập nhật được trạng thái rescue #$id. Lỗi cuối: $lastError');
  }

  Future<void> updateRescuerLocation(double lat, double lng) async {
    if (await _isDemoMode()) {
      return;
    }

    final headers = await _headers();
    final resp = await _requestWithFallbacks(
      action: 'Cập nhật GPS đội cứu hộ',
      request: (baseUrl) => http.put(Uri.parse('$baseUrl/rescuer/location'), headers: headers, body: jsonEncode({'lat': lat, 'lng': lng})),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Cập nhật GPS đội cứu hộ thất bại: ${resp.statusCode}');
    }
  }

  static int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? fallback;
  }
}
