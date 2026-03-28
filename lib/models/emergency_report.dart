import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportStatus {
  pending,
  inProgress,
  completed,
  cancelled,
}

class EmergencyReport {
  final String id;
  final String title;
  final String subtitle;
  final int people;
  final double lat;
  final double lng;
  final String level;
  final Timestamp time;
  final ReportStatus status;

  EmergencyReport({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.people,
    required this.lat,
    required this.lng,
    required this.level,
    required this.time,
    this.status = ReportStatus.pending,
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
      status: ReportStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => ReportStatus.pending,
      ),
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
      'status': status.name,
    };
  }

  EmergencyReport copyWith({
    String? id,
    String? title,
    String? subtitle,
    int? people,
    double? lat,
    double? lng,
    String? level,
    Timestamp? time,
    ReportStatus? status,
  }) {
    return EmergencyReport(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      people: people ?? this.people,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      level: level ?? this.level,
      time: time ?? this.time,
      status: status ?? this.status,
    );
  }
}
