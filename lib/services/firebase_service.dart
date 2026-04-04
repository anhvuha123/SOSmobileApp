import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/emergency_report.dart';
import '../models/rescuer.dart';
import '../firebase_options.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _reportsRef = _firestore.collection('reports');
  static final CollectionReference _rescuersRef = _firestore.collection('rescuers');

  static Future<void> init() async {
    if (Firebase.apps.isNotEmpty) return;

    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }

  static Future<void> addReport(EmergencyReport report) async {
    await _reportsRef.add(report.toMap());
  }

  static Stream<List<EmergencyReport>> streamReports() {
    return _reportsRef.orderBy('time', descending: true).snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => EmergencyReport.fromFirestore(doc)).toList(),
        );
  }

  static Future<void> addRescuer(Rescuer rescuer) async {
    await _rescuersRef.doc(rescuer.id).set(rescuer.toMap());
  }

  static Future<void> assignTaskToRescuer(String rescuerId, String reportId) async {
    await _rescuersRef.doc(rescuerId).update({
      'currentTaskId': reportId,
      'status': RescuerStatus.onTask.name,
      'isAvailable': false,
    });
  }

  static Future<void> rescuerAcceptTask(String rescuerId, String reportId) async {
    // Add rescuer to assigned list
    final reportRef = _reportsRef.doc(reportId);
    final reportDoc = await reportRef.get();
    final data = reportDoc.data() as Map<String, dynamic>;
    final assigned = List<String>.from(data['assignedRescuers'] ?? []);
    if (!assigned.contains(rescuerId)) {
      assigned.add(rescuerId);
      await reportRef.update({'assignedRescuers': assigned});
    }
    await assignTaskToRescuer(rescuerId, reportId);
  }

  static Future<void> rescuerRejectTask(String rescuerId) async {
    await _rescuersRef.doc(rescuerId).update({
      'currentTaskId': null,
      'status': RescuerStatus.available.name,
      'isAvailable': true,
    });
  }

  static Future<void> updateRescuerLocation(String id, double lat, double lng) async {
    await _rescuersRef.doc(id).update({
      'lat': lat,
      'lng': lng,
      'lastUpdated': Timestamp.now(),
    });
  }

  static Stream<List<Rescuer>> streamRescuers() {
    return _rescuersRef.where('isAvailable', isEqualTo: true).snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => Rescuer.fromFirestore(doc)).toList(),
        );
  }

  static Future<void> updateReportStatus(String id, ReportStatus status) async {
    await _reportsRef.doc(id).update({'status': status.name});
  }

  static Future<void> deleteReport(String id) async {
    await _reportsRef.doc(id).delete();
  }

  static Future<List<Rescuer>> getNearbyRescuers(double lat, double lng, double radiusKm) async {
    // Note: This is a simplified version. In production, use GeoFire or similar for geospatial queries.
    final querySnapshot = await _rescuersRef.where('isAvailable', isEqualTo: true).get();
    final rescuers = querySnapshot.docs.map((doc) => Rescuer.fromFirestore(doc)).toList();

    // Filter by distance (simple approximation)
    const double kmPerDegree = 111.32;
    final rescuersNearby = rescuers.where((r) {
      final distance = ((r.lat - lat).abs() * kmPerDegree) + ((r.lng - lng).abs() * kmPerDegree * 0.8);
      return distance <= radiusKm;
    }).toList();

    return rescuersNearby;
  }
}
