import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/web_rescue.dart';
import '../services/map_tiles.dart';
import '../services/web_rescue_service.dart';
import 'report_screen.dart';

class RescuerScreen extends StatefulWidget {
  static const String routeName = '/rescuer';

  const RescuerScreen({super.key});

  @override
  State<RescuerScreen> createState() => _RescuerScreenState();
}

class _RescuerScreenState extends State<RescuerScreen> {
  final MapController _mapController = MapController();
  final WebRescueService _service = const WebRescueService();

  Timer? _polling;
  StreamSubscription<Position>? _locationSub;

  List<WebRescue> _rescues = const [];
  WebRescue? _currentTask;
  LatLng? _currentLocation;
  bool _loading = true;
  String? _error;
  bool _satelliteMode = false;
  bool _statusOverviewCollapsed = false;

  LatLng _center = const LatLng(10.762622, 106.660172);
  double _zoom = 13;

  @override
  void initState() {
    super.initState();
    _refresh();
    _startLocationTracking();
    _polling = Timer.periodic(const Duration(seconds: 6), (_) => _refresh(silent: true));
  }

  @override
  void dispose() {
    _polling?.cancel();
    _locationSub?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final rescues = await _service.getRescues();
      if (!mounted) return;
      setState(() {
        _rescues = rescues.where((r) => r.status == 'new' || r.status == 'rescuing').toList();
        if (_currentTask != null) {
          _currentTask = rescues.where((r) => r.id == _currentTask!.id).cast<WebRescue?>().firstWhere((_) => true, orElse: () => null);
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _startLocationTracking() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return;
    }

    _locationSub = Geolocator.getPositionStream().listen((position) async {
      final point = LatLng(position.latitude, position.longitude);
      if (!mounted) return;

      setState(() {
        _currentLocation = point;
        _center = point;
      });

      try {
        await _service.updateRescuerLocation(position.latitude, position.longitude);
      } catch (_) {
        // Keep UI responsive even when location update endpoint is temporarily unavailable.
      }
    });
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'new':
        return 'Mới';
      case 'rescuing':
        return 'Đang cứu hộ';
      case 'done':
        return 'Hoàn thành';
      case 'cancel':
      case 'canceled':
      case 'cancelled':
        return 'Đã hủy';
      default:
        return status;
    }
  }

  Future<void> _acceptTask(WebRescue rescue) async {
    try {
      await _service.updateRescueStatus(rescue.id, 'rescuing');
      setState(() {
        _currentTask = rescue.copyWith(status: 'rescuing');
      });
      _mapController.move(LatLng(rescue.lat, rescue.lng), 15);
      await _refresh(silent: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã nhận nhiệm vụ #${rescue.id}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể nhận nhiệm vụ: $e')),
      );
    }
  }

  Future<void> _finishTask() async {
    final task = _currentTask;
    if (task == null) return;

    try {
      await _service.updateRescueStatus(task.id, 'done');
      setState(() {
        _currentTask = null;
      });
      await _refresh(silent: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã hoàn thành nhiệm vụ')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không thể hoàn thành nhiệm vụ: $e')));
    }
  }

  Future<void> _openDirections(WebRescue rescue) async {
    if (_currentLocation == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đang lấy vị trí hiện tại...')));
      return;
    }

    final origin = '${_currentLocation!.latitude},${_currentLocation!.longitude}';
    final destination = '${rescue.lat},${rescue.lng}';
    final url = 'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination&travelmode=driving';

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không mở được chỉ đường')));
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _controlButton(IconData icon, VoidCallback onPressed) {
    return Material(
      color: Colors.white,
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 20, color: const Color(0xff0f172a)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _rescues.where((r) => r.status == 'new').length;

    return Scaffold(
      backgroundColor: const Color(0xffeef2ff),
      appBar: AppBar(
        backgroundColor: const Color(0xff0f172a),
        title: const Row(
          children: [
            Icon(Icons.shield, color: Colors.white),
            SizedBox(width: 10),
            Text('Bảng điều phối', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, ReportScreen.routeName),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              backgroundColor: Colors.white.withValues(alpha: 0.1),
            ),
            icon: const Icon(Icons.dashboard_rounded, size: 18),
            label: const Text('Dashboard'),
          ),
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 220),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(initialCenter: _center, initialZoom: _zoom),
                  children: [
                    TileLayer(
                      urlTemplate: mapTileUrl(_satelliteMode ? MapBaseLayer.satellite : MapBaseLayer.standard),
                      userAgentPackageName: 'appmobilesos',
                    ),
                    MarkerLayer(
                      markers: [
                        ..._rescues
                            .where((r) => r.lat != 0 && r.lng != 0)
                            .map(
                              (r) => Marker(
                                point: LatLng(r.lat, r.lng),
                                width: 44,
                                height: 44,
                                child: const Icon(Icons.location_on_rounded, color: Color(0xffdc2626), size: 38),
                              ),
                            ),
                        if (_currentLocation != null)
                          Marker(
                            point: _currentLocation!,
                            width: 44,
                            height: 44,
                            child: const Icon(Icons.person_pin_circle, color: Color(0xff2563eb), size: 38),
                          ),
                      ],
                    ),
                    if (_currentTask != null && _currentLocation != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [_currentLocation!, LatLng(_currentTask!.lat, _currentTask!.lng)],
                            color: const Color(0xff2563eb),
                            strokeWidth: 4.0,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            top: 16,
            right: 124,
            child: Card(
              elevation: 12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Trạng thái tuyến cứu hộ',
                            style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _statusOverviewCollapsed = !_statusOverviewCollapsed;
                            });
                          },
                          icon: Icon(_statusOverviewCollapsed ? Icons.unfold_more : Icons.unfold_less),
                          tooltip: _statusOverviewCollapsed ? 'Mở rộng' : 'Thu gọn',
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    if (!_statusOverviewCollapsed) ...[
                      const SizedBox(height: 6),
                      Text('$pendingCount nhiệm vụ chờ xử lý', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _chip(Icons.notifications_active_rounded, '${_rescues.length} nhiệm vụ mở', const Color(0xffdc2626)),
                          _chip(Icons.navigation_rounded, _currentTask == null ? 'Chưa nhận nhiệm vụ' : 'Đang nhận nhiệm vụ', const Color(0xff2563eb)),
                          _chip(Icons.map_rounded, hasGoongApiKey ? 'Goong map' : 'OSM fallback', const Color(0xff0f172a)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            top: 16,
            child: Column(
              children: [
                _controlButton(Icons.add, () {
                  setState(() {
                    _zoom = (_zoom + 1).clamp(5, 18).toDouble();
                    _mapController.move(_center, _zoom);
                  });
                }),
                const SizedBox(height: 8),
                _controlButton(Icons.remove, () {
                  setState(() {
                    _zoom = (_zoom - 1).clamp(5, 18).toDouble();
                    _mapController.move(_center, _zoom);
                  });
                }),
                const SizedBox(height: 8),
                _controlButton(_satelliteMode ? Icons.layers : Icons.satellite_alt, () {
                  setState(() {
                    _satelliteMode = !_satelliteMode;
                  });
                }),
                const SizedBox(height: 8),
                _controlButton(Icons.my_location, () {
                  if (_currentLocation != null) {
                    _mapController.move(_currentLocation!, 15);
                  }
                }),
              ],
            ),
          ),
          if (_currentTask != null)
            Positioned(
              bottom: 210,
              left: 16,
              right: 16,
              child: Card(
                elevation: 12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Nhiệm vụ hiện tại', style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(_currentTask!.address, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      Text('Số người cần hỗ trợ: ${_currentTask!.victims}'),
                      Text('Trạng thái: ${_statusLabel(_currentTask!.status)}'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _openDirections(_currentTask!),
                              icon: const Icon(Icons.directions),
                              label: const Text('Chỉ đường'),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff2563eb)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _finishTask,
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff16a34a)),
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
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 200,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(color: Color(0x22000000), blurRadius: 20, offset: Offset(0, -4)),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(99)),
                  ),
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Nhiệm vụ khả dụng', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    ),
                  ),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _error != null
                            ? Center(child: Text(_error!))
                            : ListView.builder(
                                itemCount: _rescues.length,
                                itemBuilder: (context, index) {
                                  final rescue = _rescues[index];
                                  return Card(
                                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      side: BorderSide(color: Colors.grey.shade200),
                                    ),
                                    child: ListTile(
                                      title: Text(rescue.address, style: const TextStyle(fontWeight: FontWeight.w800)),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Trạng thái: ${_statusLabel(rescue.status)}'),
                                          Text('Nạn nhân: ${rescue.victims}'),
                                          Text('Loại SOS: ${rescue.sosType}'),
                                        ],
                                      ),
                                      trailing: ElevatedButton(
                                        onPressed: () => _acceptTask(rescue),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xffdc2626),
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('Nhận'),
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (_currentLocation == null) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vị trí chưa sẵn sàng')));
            return;
          }

          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Gửi SOS nhanh'),
              content: const Text('Gửi tín hiệu SOS từ vị trí hiện tại tới hệ thống cứu hộ?'),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Hủy')),
                ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Gửi')),
              ],
            ),
          );

          if (confirm == true) {
            try {
              final id = await _service.createSos(
                name: 'Đội cứu hộ (auto)',
                phone: '',
                address: 'Vị trí hiện tại',
                note: 'SOS gửi từ ứng dụng đội cứu hộ',
                victims: 1,
                sosType: 'urgent',
                lat: _currentLocation!.latitude,
                lng: _currentLocation!.longitude,
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gửi SOS thành công ${id != null ? '#$id' : ''}')));
              await _refresh(silent: true);
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không thể gửi SOS: $e')));
            }
          }
        },
        icon: const Icon(Icons.warning_amber_rounded),
        label: const Text('Gửi SOS'),
      ),
    );
  }
}
