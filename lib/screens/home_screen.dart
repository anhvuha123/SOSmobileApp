import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'report_screen.dart';
import 'sos.dart';
import 'rescuer_screen.dart';
import '../models/emergency_report.dart';
import '../models/rescuer.dart';
import '../services/firebase_service.dart';

class HomeScreen extends StatefulWidget {
  static const String routeName = '/home';

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final MapController _mapController = MapController();

  LatLng center = const LatLng(10.762622, 106.660172);
  double zoom = 13;

  EmergencyReport? selected;

  void moveTo(EmergencyReport r) {
    final LatLng pos = LatLng(r.lat, r.lng);

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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                  Navigator.pushNamed(context, SosScreen.routeName);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void showRescuers() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Đội cứu trợ gần đây",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              StreamBuilder<List<Rescuer>>(
                stream: FirebaseService.streamRescuers(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text("Lỗi tải dữ liệu");
                  }
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }
                  final rescuers = snapshot.data!;
                  return Column(
                    children: [
                      Text("Hiện có ${rescuers.length} thành viên cứu trợ tại khu vực này"),
                      const SizedBox(height: 10),
                      ...rescuers.map((rescuer) => ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(rescuer.name),
                        subtitle: Text(rescuer.isAvailable ? "Sẵn sàng" : "Đang bận"),
                      )),
                    ],
                  );
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
            Icon(Icons.home, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text("SOS - Admin"),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.switch_account, color: Colors.white),
            onPressed: () {
              Navigator.pushReplacementNamed(context, RescuerScreen.routeName);
            },
            tooltip: 'Chuyển sang chế độ cứu hộ',
          ),
          const SizedBox(width: 10),
          const Icon(Icons.notifications),
          const SizedBox(width: 10),
          const Icon(Icons.search),
          const SizedBox(width: 10),
        ],
      ),

      body: StreamBuilder<List<EmergencyReport>>(
        stream: FirebaseService.streamReports(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final reports = snapshot.data!;
          return Stack(
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
                        "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                    userAgentPackageName: 'appmobilesos',
                  ),

                  MarkerLayer(
                    markers: reports.map((r) {
                      return Marker(
                        point: LatLng(r.lat, r.lng),
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
                    FloatingActionButton(
                      heroTag: "zoomIn",
                      onPressed: zoomIn,
                      child: const Icon(Icons.add),
                    ),
                    const SizedBox(height: 6),
                    FloatingActionButton(
                      heroTag: "zoomOut",
                      onPressed: zoomOut,
                      child: const Icon(Icons.remove),
                    ),
                    const SizedBox(height: 6),
                    const FloatingActionButton(
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
                                      selected!.title,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),

                                    const SizedBox(height: 4),

                                    Text(
                                      "${selected!.people} người cần hỗ trợ",
                                      style: const TextStyle(color: Colors.grey),
                                    ),

                                    Text(
                                      selected!.subtitle,
                                      style: const TextStyle(color: Colors.grey),
                                    ),

                                    Text(
                                      "Mức độ: ${selected!.level}",
                                      style: const TextStyle(color: Colors.grey),
                                    ),

                                    Text(
                                      "Thời gian: ${selected!.time.toDate()}",
                                      style: const TextStyle(color: Colors.grey),
                                    ),

                                    Text(
                                      "Trạng thái: ${selected!.status.name}",
                                      style: const TextStyle(color: Colors.blue),
                                    ),
                                  ],
                                ),
                              ),

                              Column(
                                children: [
                                  DropdownButton<ReportStatus>(
                                    value: selected!.status,
                                    onChanged: (newStatus) async {
                                      if (newStatus != null) {
                                        await FirebaseService.updateReportStatus(selected!.id, newStatus);
                                        setState(() {
                                          selected = selected!.copyWith(status: newStatus);
                                        });
                                      }
                                    },
                                    items: ReportStatus.values.map((status) {
                                      return DropdownMenuItem(
                                        value: status,
                                        child: Text(status.name),
                                      );
                                    }).toList(),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () async {
                                      await FirebaseService.deleteReport(selected!.id);
                                      setState(() {
                                        selected = null;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xffff6a00),
                              ),
                              onPressed: () async {
                                if (selected != null) {
                                  // Cập nhật status thành inProgress
                                  await FirebaseService.updateReportStatus(selected!.id, ReportStatus.inProgress);
                                  setState(() {
                                    selected = selected!.copyWith(status: ReportStatus.inProgress);
                                  });
                                  // Simulate gửi notification đến rescuers
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Đã gửi thông báo đến đội cứu hộ')),
                                  );
                                }
                              },
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
              DraggableScrollableSheet(
                initialChildSize: 0.3,
                minChildSize: 0.1,
                maxChildSize: 0.8,
                builder: (context, scrollController) {
                  return Card(
                    margin: EdgeInsets.zero,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Danh sách cứu hộ khẩn cấp",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: ListView(
                              controller: scrollController,
                              children: reports.map((r) {
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => moveTo(r),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: const Color.fromRGBO(255, 106, 0, 0.2),
                                            child: const Icon(Icons.home, color: Color(0xffff6a00)),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(r.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                                Text("Cập nhật lúc ${r.time.toDate()}", style: const TextStyle(color: Colors.grey)),
                                                Text("Trạng thái: ${r.status.name}", style: const TextStyle(color: Colors.blue)),
                                              ],
                                            ),
                                          ),
                                          PopupMenuButton<String>(
                                            onSelected: (value) async {
                                              if (value == 'delete') {
                                                await FirebaseService.deleteReport(r.id);
                                              } else {
                                                final status = ReportStatus.values.firstWhere((e) => e.name == value);
                                                await FirebaseService.updateReportStatus(r.id, status);
                                              }
                                            },
                                            itemBuilder: (context) => [
                                              const PopupMenuItem(value: 'pending', child: Text('Đang chờ')),
                                              const PopupMenuItem(value: 'inProgress', child: Text('Đang thực hiện')),
                                              const PopupMenuItem(value: 'completed', child: Text('Đã hoàn thành')),
                                              const PopupMenuItem(value: 'cancelled', child: Text('Đã hủy')),
                                              const PopupMenuDivider(),
                                              const PopupMenuItem(value: 'delete', child: Text('Xóa')),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              )
            ],
          );
        },
      ),

      /// SOS BUTTON
      // floatingActionButton: FloatingActionButton(
      //   backgroundColor: const Color(0xffdc2626),
      //   onPressed: showSOS,
      //   child: const Icon(Icons.emergency),
      // ),

      // floatingActionButtonLocation:
      //     FloatingActionButtonLocation.centerDocked,

      /// BOTTOM NAV
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: const Color(0xffdc2626),
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(color: Color(0xffdc2626), fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(color: Colors.grey),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });

          if (index == 2) {
            Navigator.pushNamed(context, ReportScreen.routeName);
          } else if (index == 3) {
            showRescuers();
          } else if (index == 4) {
            Navigator.pushNamed(context, RescuerScreen.routeName);
          } else if (index == 5) {
            showSOS();
          }
        },
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.map), label: "Bản đồ"),
          BottomNavigationBarItem(
              icon: Icon(Icons.layers), label: "Lớp phủ"),
          BottomNavigationBarItem(
              icon: Icon(Icons.add_circle), label: "Báo cáo"),
          BottomNavigationBarItem(
              icon: Icon(Icons.group), label: "Đội cứu trợ"),
          BottomNavigationBarItem(
              icon: Icon(Icons.local_hospital), label: "Chế độ cứu hộ"),
          BottomNavigationBarItem(
              icon: Icon(Icons.emergency), label: "Cầu cứu"),
        ],
      ),
    );
  }
}