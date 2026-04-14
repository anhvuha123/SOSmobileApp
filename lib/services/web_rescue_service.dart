import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/web_rescue.dart';
import 'api_config.dart';

class WebRescueService {
  const WebRescueService();

  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) return null;
    return token;
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
