import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'report_screen.dart';

class HomeScreen extends StatefulWidget {
  static const String routeName = '/';

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final MapController _mapController = MapController();

  LatLng center = const LatLng(10.762622, 106.660172);
  double zoom = 13;

  Map<String, dynamic>? selected;

  final List<Map<String, dynamic>> demoReports = [
    {
      "title": "Hẻm 154, Q8",
      "subtitle": "Ngập sâu",
      "people": 12,
      "lat": 10.75,
      "lng": 106.65
    },
    {
      "title": "Khu dân cư Q7",
      "subtitle": "Cần di dời",
      "people": 5,
      "lat": 10.73,
      "lng": 106.70
    },
  ];

  void moveTo(Map<String, dynamic> r) {
    final LatLng pos = LatLng(r["lat"], r["lng"]);

    _mapController.move(pos, 15);

    setState(() {
      selected = r;
    });
  }

  void zoomIn() {
    zoom++;
    _mapController.move(center, zoom);
  }

  void zoomOut() {
    zoom--;
    _mapController.move(center, zoom);
  }

  void showSOS() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Trung tâm khẩn cấp",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.report),
                title: const Text("Báo cáo tình hình"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, ReportScreen.routeName);
                },
              ),
              ListTile(
                leading: const Icon(Icons.emergency),
                title: const Text("Cầu cứu khẩn cấp"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, ReportScreen.routeName);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff8f7f5),

      /// HEADER
      appBar: AppBar(
        backgroundColor: const Color(0xffdc2626),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.white),
            SizedBox(width: 8),
            Text("SOS: KHẨN CẤP"),
          ],
        ),
        actions: const [
          Icon(Icons.notifications),
          SizedBox(width: 10),
          Icon(Icons.search),
          SizedBox(width: 10),
        ],
      ),

      body: Stack(
        children: [

          /// MAP
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: zoom,
            ),
            children: [

              TileLayer(
                urlTemplate:
                    "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: const ['a', 'b', 'c'],
              ),

              MarkerLayer(
                markers: demoReports.map((r) {
                  return Marker(
                    point: LatLng(r["lat"], r["lng"]),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () => moveTo(r),
                      child: const Icon(
                        Icons.warning,
                        color: Colors.red,
                        size: 35,
                      ),
                    ),
                  );
                }).toList(),
              )
            ],
          ),

          /// ZOOM BUTTON
          Positioned(
            right: 10,
            top: 20,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: "zoomIn",
                  onPressed: zoomIn,
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 6),
                FloatingActionButton.small(
                  heroTag: "zoomOut",
                  onPressed: zoomOut,
                  child: const Icon(Icons.remove),
                ),
                const SizedBox(height: 6),
                const FloatingActionButton.small(
                  heroTag: "gps",
                  onPressed: null,
                  child: Icon(Icons.my_location),
                ),
              ],
            ),
          ),

          /// CARD INFO
          if (selected != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 200,
              child: Card(
                elevation: 10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [

                      Row(
                        children: [

                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.grey.shade300,
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [

                                Text(
                                  selected!["title"],
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),

                                const SizedBox(height: 4),

                                Text(
                                  "${selected!["people"]} người cần hỗ trợ",
                                  style: const TextStyle(color: Colors.grey),
                                ),

                                Text(
                                  selected!["subtitle"],
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xffff6a00),
                          ),
                          onPressed: () {},
                          icon: const Icon(Icons.navigation),
                          label: const Text("Điều phối cứu hộ"),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),

          /// LIST BOTTOM
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  const Text(
                    "Danh sách cứu hộ khẩn cấp",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 10),

                  ...demoReports.map((r) {
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            const Color.fromRGBO(255, 106, 0, 0.2),
                        child: const Icon(Icons.home,
                            color: Color(0xffff6a00)),
                      ),
                      title: Text(r["title"]),
                      subtitle:
                          const Text("Phát tín hiệu 5 phút trước"),
                      trailing:
                          const Icon(Icons.chevron_right),
                      onTap: () => moveTo(r),
                    );
                  }),
                ],
              ),
            ),
          )
        ],
      ),

      /// SOS BUTTON
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xffdc2626),
        onPressed: showSOS,
        child: const Icon(Icons.emergency),
      ),

      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerDocked,

      /// BOTTOM NAV
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });

          if (index == 2) {
            Navigator.pushNamed(context, ReportScreen.routeName);
          }
        },
        items: [
          BottomNavigationBarItem(
              icon: Icon(Icons.map), label: "Bản đồ"),
          BottomNavigationBarItem(
              icon: Icon(Icons.layers), label: "Lớp phủ"),
          BottomNavigationBarItem(
              icon: Icon(Icons.description), label: "Báo cáo"),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: "Cài đặt"),
        ],
      ),
    );
  }
}