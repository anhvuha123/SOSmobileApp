import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/emergency_report.dart';
import '../services/firebase_service.dart';

class RescuerScreen extends StatefulWidget {
  static const String routeName = '/rescuer';

  const RescuerScreen({super.key});

  @override
  State<RescuerScreen> createState() => _RescuerScreenState();
}

class _RescuerScreenState extends State<RescuerScreen> {
  final MapController _mapController = MapController();
  LatLng center = const LatLng(10.762622, 106.660172);
  double zoom = 13;

  String? currentRescuerId; // Giả sử có ID của rescuer hiện tại
  EmergencyReport? currentTask;
  LatLng? currentLocation;

  @override
  void initState() {
    super.initState();
    // Giả sử rescuer ID là 'rescuer1', trong thực tế lấy từ auth
    currentRescuerId = 'rescuer1';
    _startLocationUpdates();
  }

  void _startLocationUpdates() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Geolocator.getPositionStream().listen((Position position) {
      if (mounted) {
        setState(() {
          currentLocation = LatLng(position.latitude, position.longitude);
        });
      }
      if (currentRescuerId != null) {
        FirebaseService.updateRescuerLocation(
          currentRescuerId!,
          position.latitude,
          position.longitude,
        );
      }
    });
  }

  void _acceptTask(EmergencyReport report) async {
    if (currentRescuerId != null) {
      await FirebaseService.rescuerAcceptTask(currentRescuerId!, report.id);
      setState(() {
        currentTask = report;
      });
      // Move to task location
      _mapController.move(LatLng(report.lat, report.lng), 15);

      // Hiển thị thông báo thành công
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã chấp nhận nhiệm vụ: ${report.title}'),
          duration: const Duration(seconds: 2),
        ),
      );

      // Tự động mở Google Maps với chỉ đường sau 2 giây
      Future.delayed(const Duration(seconds: 2), () {
        _openGoogleMapsDirections(report);
      });
    }
  }

  void _rejectTask() async {
    if (currentRescuerId != null) {
      await FirebaseService.rescuerRejectTask(currentRescuerId!);
      setState(() {
        currentTask = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã từ chối nhiệm vụ')),
      );
    }
  }

  void _openGoogleMapsDirections(EmergencyReport report) async {
    if (currentLocation != null) {
      final origin = '${currentLocation!.latitude},${currentLocation!.longitude}';
      final destination = '${report.lat},${report.lng}';
      final url = 'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination&travelmode=driving';

      try {
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } else {
          // Thử với URL đơn giản hơn nếu URL phức tạp không hoạt động
          final simpleUrl = 'https://www.google.com/maps/search/?api=1&query=${report.lat},${report.lng}';
          if (await canLaunchUrl(Uri.parse(simpleUrl))) {
            await launchUrl(Uri.parse(simpleUrl), mode: LaunchMode.externalApplication);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Không thể mở ứng dụng bản đồ. Vui lòng cài đặt Google Maps hoặc ứng dụng bản đồ khác.')),
            );
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi mở bản đồ: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có vị trí hiện tại. Đang lấy vị trí...')),
      );
      // Thử lấy vị trí hiện tại một lần nữa
      _getCurrentLocationAndOpenMaps(report);
    }
  }

  void _getCurrentLocationAndOpenMaps(EmergencyReport report) async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      setState(() {
        currentLocation = LatLng(position.latitude, position.longitude);
      });
      // Thử mở maps lại với vị trí mới
      _openGoogleMapsDirections(report);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể lấy vị trí hiện tại. Vui lòng bật GPS và thử lại.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đội cứu hộ'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.switch_account, color: Colors.white),
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/');
            },
            tooltip: 'Chuyển sang chế độ Admin',
          ),
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
          final reports = snapshot.data!.where((r) =>
            r.status == ReportStatus.pending || r.status == ReportStatus.inProgress
          ).toList();

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: zoom,
                ),
                children: [
                  TileLayer(
                    urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                    userAgentPackageName: 'appmobilesos',
                  ),
                  MarkerLayer(
                    markers: [
                      // Markers for tasks
                      ...reports.map((r) {
                        return Marker(
                          point: LatLng(r.lat, r.lng),
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.warning,
                            color: Colors.red,
                            size: 35,
                          ),
                        );
                      }).toList(),
                      // Marker for current rescuer location
                      if (currentLocation != null)
                        Marker(
                          point: currentLocation!,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.person_pin_circle,
                            color: Colors.blue,
                            size: 35,
                          ),
                        ),
                    ],
                  ),
                  // Route polyline
                  if (currentTask != null && currentLocation != null)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [
                            currentLocation!,
                            LatLng(currentTask!.lat, currentTask!.lng),
                          ],
                          color: Colors.blue,
                          strokeWidth: 4.0,
                        ),
                      ],
                    ),
                ],
              ),

              // Task details if accepted
              if (currentTask != null)
                Positioned(
                  bottom: 210,
                  left: 16,
                  right: 16,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Nhiệm vụ: ${currentTask!.title}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('Mô tả: ${currentTask!.subtitle}'),
                          Text('Người cần hỗ trợ: ${currentTask!.people}'),
                          Text('Số người cứu hộ đã nhận: ${currentTask!.assignedRescuers.length}'),
                          Text('Yêu cầu chuẩn bị: ${currentTask!.level}'),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _openGoogleMapsDirections(currentTask!),
                                  icon: const Icon(Icons.directions),
                                  label: const Text('Chỉ dẫn'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    await FirebaseService.updateReportStatus(currentTask!.id, ReportStatus.completed);
                                    _rejectTask();
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                  child: const Text('Hoàn thành'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Available tasks
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 200,
                  color: Colors.white,
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text('Nhiệm vụ khả dụng', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Expanded(
                        child: ListView(
                          children: reports.map((r) {
                            return ListTile(
                              title: Text(r.title),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Trạng thái: ${r.status.name}'),
                                  Text('Đã có ${r.assignedRescuers.length} người nhận'),
                                  Text('Yêu cầu: ${r.level}'),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ElevatedButton(
                                    onPressed: () => _acceptTask(r),
                                    child: const Text('Nhận'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _rejectTask,
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                                    child: const Text('Từ chối'),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
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
    );
  }
}