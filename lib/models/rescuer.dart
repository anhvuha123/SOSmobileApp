import 'package:cloud_firestore/cloud_firestore.dart';

enum RescuerStatus {
  available,
  onTask,
  unavailable,
}

class Rescuer {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final bool isAvailable;
  final Timestamp lastUpdated;
  final String? currentTaskId;
  final RescuerStatus status;

  Rescuer({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.isAvailable,
    required this.lastUpdated,
    this.currentTaskId,
    this.status = RescuerStatus.available,
  });

  factory Rescuer.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Rescuer(
      id: doc.id,
      name: data['name'] ?? '',
      lat: (data['lat'] ?? 0.0).toDouble(),
      lng: (data['lng'] ?? 0.0).toDouble(),
      isAvailable: data['isAvailable'] ?? true,
      lastUpdated: data['lastUpdated'] ?? Timestamp.now(),
      currentTaskId: data['currentTaskId'],
      status: RescuerStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => RescuerStatus.available,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'lat': lat,
      'lng': lng,
      'isAvailable': isAvailable,
      'lastUpdated': lastUpdated,
      'currentTaskId': currentTaskId,
      'status': status.name,
    };
  }

  Rescuer copyWith({
    String? id,
    String? name,
    double? lat,
    double? lng,
    bool? isAvailable,
    Timestamp? lastUpdated,
    String? currentTaskId,
    RescuerStatus? status,
  }) {
    return Rescuer(
      id: id ?? this.id,
      name: name ?? this.name,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      isAvailable: isAvailable ?? this.isAvailable,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      currentTaskId: currentTaskId ?? this.currentTaskId,
      status: status ?? this.status,
    );
  }
}