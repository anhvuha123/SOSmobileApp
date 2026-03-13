import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/emergency_report.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _reportsRef = _firestore.collection('reports');

  static const FirebaseOptions _webFirebaseOptions = FirebaseOptions(
    apiKey: 'YOUR_API_KEY',
    authDomain: 'YOUR_AUTH_DOMAIN',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_STORAGE_BUCKET',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    appId: 'YOUR_APP_ID',
    measurementId: 'YOUR_MEASUREMENT_ID',
  );

  static Future<void> init() async {
    if (Firebase.apps.isNotEmpty) return;

    if (kIsWeb) {
      await Firebase.initializeApp(options: _webFirebaseOptions);
    } else {
      await Firebase.initializeApp();
    }
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
