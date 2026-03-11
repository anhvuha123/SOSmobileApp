import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class EmergencyReport {
  final String id;
  final String title;
  final String subtitle;
  final int people;
  final LatLng location;
  final String level;
  final String time;

  EmergencyReport({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.people,
    required this.location,
    required this.level,
    required this.time,
  });

  factory EmergencyReport.fromJson(Map<String, dynamic> json) {
    return EmergencyReport(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      people: json['people'] ?? 0,
      location: LatLng(json['lat']?.toDouble() ?? 0.0, json['lng']?.toDouble() ?? 0.0),
      level: json['level'] ?? 'Thấp',
      time: json['time'] ?? '',
    );
  }
}

class MapApiService {
  static const _demoUrl = 'https://example.com/api/emergency-reports';

  static Future<List<EmergencyReport>> fetchEmergencyReports() async {
    // Thực tế: thay đổi URL và logic theo endpoint của bạn
    // Demo tạm thời dùng dữ liệu local.
    try {
      final response = await http.get(Uri.parse(_demoUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data.map((e) => EmergencyReport.fromJson(e)).toList();
      }
    } catch (_) {
      // fallback
    }

    return [
      EmergencyReport(
        id: '1',
        title: 'Hẻm 154, Phường 4, Q.8',
        subtitle: '12 người cần thực phẩm & di dời',
        people: 12,
        location: LatLng(10.758, 106.642),
        level: 'Khẩn cấp cao',
        time: '5 phút trước',
      ),
      EmergencyReport(
        id: '2',
        title: 'Đội cứu hộ 03',
        subtitle: 'Đang di chuyển - 1.2km',
        people: 6,
        location: LatLng(10.760, 106.648),
        level: 'Đang di chuyển',
        time: '2 phút trước',
      ),
    ];
  }
}
