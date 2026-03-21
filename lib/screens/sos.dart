import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/rescuer.dart';
import '../services/firebase_service.dart';

class SosScreen extends StatefulWidget {
  static const String routeName = '/sos';
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  bool _isLoading = false;
  bool _sosSent = false;
  List<Rescuer> _nearbyRescuers = [];
  int _requestedMembers = 0;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    } catch (e) {
      // Handle location error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể lấy vị trí hiện tại')),
        );
      }
    }
  }

  Future<void> _sendSOS() async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vị trí không khả dụng')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Ask for number of members needed
    final int? members = await _showMembersDialog();
    if (members == null || members <= 0) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _requestedMembers = members;
    });

    // Find nearby rescuers
    final nearby = await FirebaseService.getNearbyRescuers(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      10.0, // 10km radius
    );

    setState(() {
      _nearbyRescuers = nearby.take(members).toList();
      _sosSent = true;
      _isLoading = false;
    });

    // Simulate sending SOS signal
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi tín hiệu SOS')),
      );
    }
  }

  Future<int?> _showMembersDialog() async {
    int members = 1;
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Số lượng thành viên cần thiết'),
        content: TextField(
          keyboardType: TextInputType.number,
          onChanged: (value) {
            members = int.tryParse(value) ?? 1;
          },
          decoration: const InputDecoration(
            hintText: 'Nhập số lượng',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, members),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cầu cứu khẩn cấp'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Location Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.location_on, color: Colors.red),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Vị trí hiện tại của bạn",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currentPosition != null
                                ? "${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}"
                                : "Đang lấy vị trí...",
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // SOS Button
            if (!_sosSent) ...[
              const Text(
                "Gửi tín hiệu cầu cứu",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendSOS,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "GỬI SOS NGAY",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ] else ...[
              // After SOS sent
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.warning, color: Colors.red),
                          SizedBox(width: 8),
                          Text(
                            "Đang chờ đội cứu hộ",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text("Số lượng thành viên yêu cầu: $_requestedMembers"),
                      const SizedBox(height: 8),
                      Text("Số lượng cứu trợ viên gần nhất: ${_nearbyRescuers.length}"),
                      if (_nearbyRescuers.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text(
                          "Cứu trợ viên đang đến:",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ..._nearbyRescuers.map((rescuer) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text("• ${rescuer.name}"),
                        )),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
