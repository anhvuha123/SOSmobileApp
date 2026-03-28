import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import '../models/emergency_report.dart';

class ReportScreen extends StatefulWidget {
  static const String routeName = '/report';
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _controller = TextEditingController();
  String _selectedDisaster = "Ngập lụt";
  String _location = "123 Đường Lê Lợi, Quận 1, TP.HCM";
  double _lat = 10.762622;
  double _lng = 106.660172;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f5f5),

      appBar: AppBar(
        title: const Text('Báo cáo tình hình'),
        centerTitle: true,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// CARD VỊ TRÍ
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.location_on, color: Colors.orange),
                    ),

                    const SizedBox(width: 12),

                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Vị trí hiện tại của bạn",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "123 Đường Lê Lợi, Quận 1, TP.HCM",
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            /// LOẠI SỰ CỐ
            const Text(
              "Loại sự cố",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _disasterBox("Ngập lụt", Icons.flood),
                _disasterBox("Sạt lở", Icons.landscape),
                _disasterBox("Hư hỏng", Icons.build),
                _disasterBox("Khác", Icons.more_horiz),
              ],
            ),

            const SizedBox(height: 20),

            /// MÔ TẢ
            const Text(
              "Mô tả chi tiết",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: _controller,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "Mô tả cụ thể tình hình hiện tại...",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 20),

            /// ẢNH
            const Text(
              "Hình ảnh hiện trường",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                _imageBox(),
                const SizedBox(width: 10),
                _imageBox(),
                const SizedBox(width: 10),
                _imageBox(),
              ],
            ),

            const SizedBox(height: 30),

            /// BUTTON
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () async {
                  final report = EmergencyReport(
                    id: '', // Will be set by Firestore
                    title: _location,
                    subtitle: _selectedDisaster,
                    people: 1, // Assume 1 for now
                    lat: _lat,
                    lng: _lng,
                    level: 'medium',
                    time: Timestamp.now(),
                  );
                  await FirebaseService.addReport(report);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Đã gửi báo cáo")),
                    );
                    Navigator.pop(context);
                  }
                },
                child: const Text(
                  "Gửi báo cáo ngay lập tức",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// BOX LOẠI SỰ CỐ
  Widget _disasterBox(String title, IconData icon) {
    return Card(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedDisaster = title;
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: _selectedDisaster == title ? Colors.blue : Colors.orange),
              const SizedBox(height: 10),
              Text(title, textAlign: TextAlign.center, style: TextStyle(color: _selectedDisaster == title ? Colors.blue : Colors.black)),
            ],
          ),
        ),
      ),
    );
  }

  /// BOX HÌNH ẢNH
  Widget _imageBox() {
    return Card(
      child: InkWell(
        onTap: () {
          // Handle image selection
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 80,
          width: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.orange),
          ),
          child: const Icon(Icons.camera_alt, color: Colors.orange),
        ),
      ),
    );
  }
}
