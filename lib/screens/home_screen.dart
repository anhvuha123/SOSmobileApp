import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/emergency_report.dart';
import '../services/firebase_service.dart';

class HomeScreen extends StatefulWidget {
  static const String routeName = '/';
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  EmergencyReport? selectedReport;
  LatLng _currentCenter = const LatLng(10.759, 106.647);
  double _currentZoom = 13.0;

  final List<EmergencyReport> _sampleReports = [
    EmergencyReport(
      id: 'a1',
      title: 'Khu dân cư Phú Nhuận',
      subtitle: '12 người cần thực phẩm & di dời',
      people: 12,
      lat: 10.7804,
      lng: 106.6809,
      level: 'high',
      time: Timestamp.now(),
    ),
    EmergencyReport(
      id: 'a2',
      title: 'Hẻm 154, Q.8',
      subtitle: 'Ngập nước sâu, 5 người cần tiếp tế',
      people: 5,
      lat: 10.7443,
      lng: 106.6600,
      level: 'medium',
      time: Timestamp.now(),
    ),
    EmergencyReport(
      id: 'a3',
      title: 'Đội cứu hộ 03',
      subtitle: 'Đang di chuyển đến vị trí',
      people: 8,
      lat: 10.7510,
      lng: 106.6550,
      level: 'low',
      time: Timestamp.now(),
    ),
  ];

  Color _levelColor(String level) {
    switch (level.toLowerCase()) {
      case 'medium':
        return Colors.orange;
      case 'high':
        return Colors.red;
      default:
        return Colors.green.shade700;
    }
  }

  void _centerOnReport(EmergencyReport report) {
    setState(() {
      selectedReport = report;
      _currentCenter = LatLng(report.lat, report.lng);
      _currentZoom = 14.0;
    });
    _mapController.move(_currentCenter, _currentZoom);
  }

  void _zoomIn() {
    setState(() => _currentZoom = (_currentZoom + 1).clamp(5.0, 18.0));
    _mapController.move(_currentCenter, _currentZoom);
  }

  void _zoomOut() {
    setState(() => _currentZoom = (_currentZoom - 1).clamp(5.0, 18.0));
    _mapController.move(_currentCenter, _currentZoom);
  }

  void _showSOSDialog() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 12),
              const Text('Trung tâm cứu hộ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              const SizedBox(height: 12),
              const Text('Bạn cần hỗ trợ gì?', style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.warning, color: Colors.white)),
                title: const Text('Cầu cứu khẩn cấp', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Cần đội cứu hộ can thiệp ngay lập tức'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/report');
                },
              ),
              const Divider(),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.report_problem, color: Colors.white)),
                title: const Text('Báo cáo tình hình', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Cung cấp thông tin thiệt hại khu vực'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/report');
                },
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.red.shade600,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('SOS: KHẨN CẤP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                Row(children: [Icon(Icons.notifications, color: Colors.white), SizedBox(width: 12), Icon(Icons.search, color: Colors.white)]),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<EmergencyReport>>(
              stream: FirebaseService.streamReports(),
              builder: (context, snapshot) {
                final reports = (snapshot.hasData && snapshot.data!.isNotEmpty) ? snapshot.data! : _sampleReports;
                final List<Marker> markers = reports
                    .map(
                      (report) => Marker(
                        width: 48,
                        height: 48,
                        point: LatLng(report.lat, report.lng),
                        child: GestureDetector(
                          onTap: () => _centerOnReport(report),
                          child: Icon(Icons.location_on, size: 44, color: _levelColor(report.level)),
                        ),
                      ),
                    )
                    .toList();

                return Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(initialCenter: _currentCenter, initialZoom: _currentZoom, minZoom: 5, maxZoom: 18, onPositionChanged: (p, _) {
                        setState(() {
                          _currentZoom = p.zoom;
                          _currentCenter = p.center;
                        });
                      }),
                      children: [
                        TileLayer(urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', subdomains: const ['a', 'b', 'c']),
                        MarkerLayer(markers: markers),
                      ],
                    ),
                    Positioned(
                      top: 18,
                      right: 12,
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: Column(
                          children: [
                            IconButton(onPressed: _zoomIn, icon: const Icon(Icons.zoom_in)),
                            Text(_currentZoom.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(onPressed: _zoomOut, icon: const Icon(Icons.zoom_out)),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 150,
                      left: 16,
                      right: 16,
                      child: AnimatedOpacity(
                        opacity: selectedReport == null ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        child: selectedReport == null
                            ? const SizedBox.shrink()
                            : Card(
                                elevation: 10,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(selectedReport!.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 6),
                                      Text(selectedReport!.subtitle, style: const TextStyle(color: Colors.black54)),
                                      const SizedBox(height: 6),
                                      Text('Người: ${selectedReport!.people} • Mức độ: ${selectedReport!.level}'),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.navigation), label: const Text('Định vị')), 
                                          const SizedBox(width: 8),
                                          IconButton(onPressed: () => setState(() => selectedReport = null), icon: const Icon(Icons.close)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Danh sách cứu hộ khẩn cấp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 130,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: reports.length,
                                itemBuilder: (context, index) {
                                  final report = reports[index];
                                  return GestureDetector(
                                    onTap: () => _centerOnReport(report),
                                    child: Container(
                                      width: 210,
                                      margin: const EdgeInsets.only(right: 10),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: Colors.grey.shade200),
                                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(report.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                          const SizedBox(height: 4),
                                          Text(report.subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          const Spacer(),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('${report.people} người', style: const TextStyle(fontSize: 12)),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: _levelColor(report.level).withAlpha(40),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(report.level.toUpperCase(), style: TextStyle(color: _levelColor(report.level), fontWeight: FontWeight.bold, fontSize: 10)),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showSOSDialog,
        backgroundColor: Colors.red,
        icon: const Icon(Icons.warning),
        label: const Text('SOS'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
