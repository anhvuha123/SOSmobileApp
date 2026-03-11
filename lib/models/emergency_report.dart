import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyReport {
  final String id;
  final String title;
  final String subtitle;
  final int people;
  final double lat;
  final double lng;
  final String level;
  final Timestamp time;

  EmergencyReport({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.people,
    required this.lat,
    required this.lng,
    required this.level,
    required this.time,
  });

  factory EmergencyReport.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EmergencyReport(
      id: doc.id,
      title: data['title'] ?? '',
      subtitle: data['subtitle'] ?? '',
      people: (data['people'] ?? 1).toInt(),
      lat: (data['lat'] ?? 0.0).toDouble(),
      lng: (data['lng'] ?? 0.0).toDouble(),
      level: data['level'] ?? 'low',
      time: data['time'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'subtitle': subtitle,
      'people': people,
      'lat': lat,
      'lng': lng,
      'level': level,
      'time': time,
    };
  }
}
