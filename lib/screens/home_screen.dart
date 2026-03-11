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

  Color _levelColor(String level) {
    switch (level.toLowerCase()) {
      case 'medium':
        return Colors.orange;
      case 'high':
        return Colors.red;
      default:
        return Colors.yellow.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            color: Colors.red.shade600,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('SOS: KHẨN CẤP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Row(children: [Icon(Icons.notifications, color: Colors.white), SizedBox(width: 12), Icon(Icons.search, color: Colors.white)]),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<EmergencyReport>>(
              stream: FirebaseService.streamReports(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Lỗi: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final reports = snapshot.data!;
                final markers = reports
                    .map(
                      (report) => Marker(
                        width: 40,
                        height: 40,
                        point: LatLng(report.lat, report.lng),
                        builder: (_) => GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedReport = report;
                            });
                            _mapController.move(LatLng(report.lat, report.lng), 14);
                          },
                          child: Icon(Icons.location_on, size: 40, color: _levelColor(report.level)),
                        ),
                      ),
                    )
                    .toList();

                return Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        center: LatLng(10.759, 106.647),
                        zoom: 13.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                          subdomains: const ['a', 'b', 'c'],
                        ),
                        MarkerLayer(markers: markers),
                      ],
                    ),
                    if (selectedReport != null)
                      Positioned(
                        bottom: 130,
                        left: 16,
                        right: 16,
                        child: Card(
                          elevation: 8,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(selectedReport!.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(selectedReport!.subtitle),
                                const SizedBox(height: 4),
                                Text('Người: ${selectedReport!.people} • Mức độ: ${selectedReport!.level} • ${selectedReport!.time.toDate()}'),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () {},
                                      icon: const Icon(Icons.navigation),
                                      label: const Text('Điều phối cứu hộ'),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      onPressed: () => setState(() => selectedReport = null),
                                      icon: const Icon(Icons.close),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Danh sách cứu hộ khẩn cấp', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 120,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: reports.length,
                                itemBuilder: (context, index) {
                                  final report = reports[index];
                                  return GestureDetector(
                                    onTap: () {
                                      _mapController.move(LatLng(report.lat, report.lng), 14);
                                      setState(() => selectedReport = report);
                                    },
                                    child: Container(
                                      width: 220,
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(report.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                          Text(report.subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          const Spacer(),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('${report.people} người', style: const TextStyle(fontSize: 12)),
                                              Chip(label: Text(report.level, style: const TextStyle(fontSize: 11)), backgroundColor: Color.lerp(Colors.white, _levelColor(report.level), 0.2)),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/report');
        },
        backgroundColor: Colors.red,
        child: const Icon(Icons.add),
      ),
    );
  }
}
