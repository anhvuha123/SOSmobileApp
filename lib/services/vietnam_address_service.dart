import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/vietnam_address.dart';

class VietnamAddressService {
  static const String _baseUrl = 'https://provinces.open-api.vn/api';
  static const Duration _timeout = Duration(seconds: 4);

  static List<Province>? _provincesCache;
  static final Map<int, List<District>> _districtsCache = {};
  static final Map<int, List<Ward>> _wardsCache = {};

  Future<List<Province>> getProvinces() async {
    final cached = _provincesCache;
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    final uri = Uri.parse('$_baseUrl/p/?depth=1');
    final resp = await http.get(uri).timeout(_timeout);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }
      throw Exception('Không tải được danh sách tỉnh/thành');
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! List) return const [];

    final provinces = decoded
        .whereType<Map>()
        .map((item) => Province.fromJson(item.cast<String, dynamic>()))
        .toList();

    _provincesCache = provinces;
    return provinces;
  }

  Future<List<District>> getDistricts(int provinceCode) async {
    final cached = _districtsCache[provinceCode];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    final uri = Uri.parse('$_baseUrl/p/$provinceCode?depth=2');
    final resp = await http.get(uri).timeout(_timeout);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }
      throw Exception('Không tải được danh sách quận/huyện');
    }

    final decoded = jsonDecode(resp.body);
    final districts = decoded is Map<String, dynamic> ? decoded['districts'] : null;
    if (districts is! List) return const [];

    final items = districts
        .whereType<Map>()
        .map((item) => District.fromJson(item.cast<String, dynamic>()))
        .toList();

    _districtsCache[provinceCode] = items;
    return items;
  }

  Future<List<Ward>> getWards(int districtCode) async {
    final cached = _wardsCache[districtCode];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    final uri = Uri.parse('$_baseUrl/d/$districtCode?depth=2');
    final resp = await http.get(uri).timeout(_timeout);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }
      throw Exception('Không tải được danh sách phường/xã');
    }

    final decoded = jsonDecode(resp.body);
    final wards = decoded is Map<String, dynamic> ? decoded['wards'] : null;
    if (wards is! List) return const [];

    final items = wards
        .whereType<Map>()
        .map((item) => Ward.fromJson(item.cast<String, dynamic>()))
        .toList();

    _wardsCache[districtCode] = items;
    return items;
  }
}
