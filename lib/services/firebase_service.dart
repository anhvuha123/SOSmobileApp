import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/emergency_report.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _reportsRef = _firestore.collection('reports');

  static Future<void> init() async {
    // Cấu hình firebase_options.dart thông qua flutterfire configure
    await Firebase.initializeApp();
  }

  static Future<void> addReport(EmergencyReport report) async {
    await _reportsRef.add(report.toMap());
  }

  static Stream<List<EmergencyReport>> streamReports() {
    return _reportsRef.orderBy('time', descending: true).snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => EmergencyReport.fromFirestore(doc)).toList(),
        );
  }
}
