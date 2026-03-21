import 'package:cloud_firestore/cloud_firestore.dart';

class Rescuer {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final bool isAvailable;
  final Timestamp lastUpdated;

  Rescuer({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.isAvailable,
    required this.lastUpdated,
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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'lat': lat,
      'lng': lng,
      'isAvailable': isAvailable,
      'lastUpdated': lastUpdated,
    };
  }
}