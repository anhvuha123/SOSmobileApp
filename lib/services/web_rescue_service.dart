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

  Future<List<WebRescue>> getRescues() async {
    if (await _isDemoMode()) {
      return List<WebRescue>.of(_demoRescues);
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}/rescues');
    final resp = await http.get(uri, headers: await _headers());

    if (resp.statusCode != 200) {
      throw Exception('Lấy rescues thất bại: ${resp.statusCode}');
    }

    final decoded = jsonDecode(resp.body);
    final list = decoded is List
        ? decoded
        : (decoded is Map && decoded['data'] is List)
            ? decoded['data'] as List
            : <dynamic>[];

    return list
        .whereType<Map>()
        .map((item) => WebRescue.fromJson(item.cast<String, dynamic>()))
        .toList();
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

    final uri = Uri.parse('${ApiConfig.baseUrl}/rescues');
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

    final resp = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode(body),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Gửi SOS thất bại: ${resp.statusCode} ${resp.body}');
    }

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

    final candidates = <Uri>[
      Uri.parse('${ApiConfig.baseUrl}/rescues/$id'),
      Uri.parse('${ApiConfig.baseUrl}/rescues/$id/details'),
    ];

    for (final uri in candidates) {
      final resp = await http.patch(
        uri,
        headers: await _headers(),
        body: jsonEncode(payload),
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return;
      }
    }

    throw Exception('Không cập nhật được thông tin SOS #$id');
  }

  Future<void> updateRescueStatus(int id, String status) async {
    if (await _isDemoMode()) {
      _demoRescues = _demoRescues
          .map((item) => item.id == id ? item.copyWith(status: status) : item)
          .toList();
      return;
    }

    final candidates = <Uri>[
      Uri.parse('${ApiConfig.baseUrl}/rescues/$id/status'),
      Uri.parse('${ApiConfig.baseUrl}/rescues/$id'),
    ];

    for (final uri in candidates) {
      final resp = await http.patch(
        uri,
        headers: await _headers(),
        body: jsonEncode({'status': status}),
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return;
      }
    }

    throw Exception('Không cập nhật được trạng thái rescue #$id');
  }

  Future<void> updateRescuerLocation(double lat, double lng) async {
    if (await _isDemoMode()) {
      return;
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}/rescuer/location');
    final resp = await http.put(
      uri,
      headers: await _headers(),
      body: jsonEncode({'lat': lat, 'lng': lng}),
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
