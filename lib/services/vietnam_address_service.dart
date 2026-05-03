import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/vietnam_address.dart';

class VietnamAddressService {
  static const String _baseUrl = 'https://provinces.open-api.vn/api';

  Future<List<Province>> getProvinces() async {
    final uri = Uri.parse('$_baseUrl/p/?depth=1');
    final resp = await http.get(uri);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Không tải được danh sách tỉnh/thành');
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map>()
        .map((item) => Province.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  Future<List<District>> getDistricts(int provinceCode) async {
    final uri = Uri.parse('$_baseUrl/p/$provinceCode?depth=2');
    final resp = await http.get(uri);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Không tải được danh sách quận/huyện');
    }

    final decoded = jsonDecode(resp.body);
    final districts = decoded is Map<String, dynamic> ? decoded['districts'] : null;
    if (districts is! List) return const [];

    return districts
        .whereType<Map>()
        .map((item) => District.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  Future<List<Ward>> getWards(int districtCode) async {
    final uri = Uri.parse('$_baseUrl/d/$districtCode?depth=2');
    final resp = await http.get(uri);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Không tải được danh sách phường/xã');
    }

    final decoded = jsonDecode(resp.body);
    final wards = decoded is Map<String, dynamic> ? decoded['wards'] : null;
    if (wards is! List) return const [];

    return wards
        .whereType<Map>()
        .map((item) => Ward.fromJson(item.cast<String, dynamic>()))
        .toList();
  }
}
