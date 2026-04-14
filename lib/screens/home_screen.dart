import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/web_rescue.dart';
import '../services/map_tiles.dart';
import '../services/web_rescue_service.dart';
import 'report_screen.dart';
import 'rescuer_screen.dart';
import 'sos.dart';

class HomeScreen extends StatefulWidget {
  static const String routeName = '/home';

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  final WebRescueService _service = const WebRescueService();

  Timer? _polling;
  List<WebRescue> _rescues = const [];
  WebRescue? _selected;
  bool _loading = true;
  String? _error;
  bool _satelliteMode = false;
  int _currentIndex = 0;

  LatLng _center = const LatLng(10.762622, 106.660172);
  double _zoom = 13;

  @override
  void initState() {
    super.initState();
    _refresh();
    _polling = Timer.periodic(const Duration(seconds: 6), (_) => _refresh(silent: true));
  }

  @override
  void dispose() {
    _polling?.cancel();
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
        _rescues = rescues;
        _error = null;
        _loading = false;
        if (_selected != null) {
          _selected = rescues.where((r) => r.id == _selected!.id).cast<WebRescue?>().firstWhere((_) => true, orElse: () => null);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _moveTo(WebRescue rescue) {
    final target = LatLng(rescue.lat, rescue.lng);
    _mapController.move(target, 15);
    setState(() {
      _selected = rescue;
      _center = target;
      _zoom = 15;
    });
  }

  Future<void> _setStatus(WebRescue rescue, String status) async {
    try {
      await _service.updateRescueStatus(rescue.id, status);
      await _refresh(silent: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã cập nhật #${rescue.id} -> $status')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không cập nhật được trạng thái: $e')),
      );
    }
  }

  String _labelStatus(String status) {
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

  Color _statusColor(String status) {
    switch (status) {
      case 'new':
        return const Color(0xfff59e0b);
      case 'rescuing':
        return const Color(0xff2563eb);
      case 'done':
        return const Color(0xff16a34a);
      case 'cancel':
      case 'canceled':
      case 'cancelled':
        return const Color(0xff64748b);
      default:
        return const Color(0xff64748b);
    }
  }

  String _timeText(DateTime? dt) {
    if (dt == null) return 'Không rõ thời gian';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${diff.inDays} ngày trước';
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

  void _onBottomTabTap(int index) {
    if (index == 1) {
      setState(() {
        _currentIndex = index;
        _satelliteMode = !_satelliteMode;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _satelliteMode
                ? 'Đã bật lớp phủ vệ tinh chân thật (World Imagery)'
                : 'Đã tắt lớp phủ vệ tinh, quay về bản đồ chuẩn',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _currentIndex = index;
    });

    if (index == 2) {
      Navigator.pushNamed(context, RescuerScreen.routeName);
    } else if (index == 3) {
      Navigator.pushNamed(context, ReportScreen.routeName);
    }
  }

  Widget _bottomTabItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final selected = _currentIndex == index;
    final color = selected ? const Color(0xffdc2626) : Colors.grey.shade600;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _onBottomTabTap(index),
      child: SizedBox(
        width: 76,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = _rescues.where((r) => r.status != 'done' && r.status != 'cancel' && r.status != 'canceled' && r.status != 'cancelled').toList();

    return Scaffold(
      backgroundColor: const Color(0xffeef2ff),
      appBar: AppBar(
        backgroundColor: const Color(0xff0f172a),
        title: const Row(
          children: [
            Icon(Icons.map, color: Colors.white),
            SizedBox(width: 10),
            Expanded(child: Text('Bản đồ điều phối SOS')),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushReplacementNamed(context, RescuerScreen.routeName),
            icon: const Icon(Icons.switch_account, color: Colors.white),
            tooltip: 'Chế độ cứu hộ',
          ),
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xffe2e8f0), Color(0xfff8fafc)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 186),
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
                      markers: _rescues
                          .where((r) => r.lat != 0 && r.lng != 0)
                          .map(
                            (r) => Marker(
                              point: LatLng(r.lat, r.lng),
                              width: 44,
                              height: 44,
                              child: GestureDetector(
                                onTap: () => _moveTo(r),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _selected?.id == r.id ? const Color(0xffdc2626) : const Color(0xff991b1b),
                                    shape: BoxShape.circle,
                                    boxShadow: const [
                                      BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 6)),
                                    ],
                                  ),
                                  child: const Icon(Icons.warning_rounded, color: Colors.white, size: 28),
                                ),
                              ),
                            ),
                          )
                          .toList(),
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
                    const Text('Tổng quan cứu hộ', style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text('${active.length} yêu cầu đang mở', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _chip(Icons.place_rounded, '${_rescues.length} tổng yêu cầu', const Color(0xffdc2626)),
                        _chip(Icons.map_rounded, hasGoongApiKey ? 'Goong map' : 'OSM fallback', const Color(0xff0f172a)),
                        _chip(Icons.sync, 'Đồng bộ backend web', const Color(0xff2563eb)),
                      ],
                    ),
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
                const SizedBox(height: 6),
                _controlButton(Icons.remove, () {
                  setState(() {
                    _zoom = (_zoom - 1).clamp(5, 18).toDouble();
                    _mapController.move(_center, _zoom);
                  });
                }),
                const SizedBox(height: 6),
                _controlButton(_satelliteMode ? Icons.layers : Icons.satellite_alt, () {
                  setState(() {
                    _satelliteMode = !_satelliteMode;
                  });
                }),
                const SizedBox(height: 6),
                _controlButton(Icons.my_location, () => _mapController.move(_center, _zoom)),
              ],
            ),
          ),
          if (_selected != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 190,
              child: Card(
                elevation: 14,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_selected!.address, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('${_selected!.victims} người cần hỗ trợ', style: const TextStyle(color: Colors.black54)),
                      Text('Loại SOS: ${_selected!.sosType}', style: const TextStyle(color: Colors.black54)),
                      Text('Thời gian: ${_timeText(_selected!.createdAt)}', style: const TextStyle(color: Colors.black54)),
                      Row(
                        children: [
                          const Text('Trạng thái: '),
                          Text(
                            _labelStatus(_selected!.status),
                            style: TextStyle(color: _statusColor(_selected!.status), fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _setStatus(_selected!, 'rescuing'),
                            icon: const Icon(Icons.navigation),
                            label: const Text('Điều phối'),
                          ),
                          OutlinedButton(
                            onPressed: () => _setStatus(_selected!, 'done'),
                            child: const Text('Hoàn thành'),
                          ),
                          OutlinedButton(
                            onPressed: () => _setStatus(_selected!, 'cancel'),
                            child: const Text('Hủy'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          DraggableScrollableSheet(
            initialChildSize: 0.3,
            minChildSize: 0.1,
            maxChildSize: 0.8,
            builder: (context, scrollController) {
              return Card(
                margin: EdgeInsets.zero,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 46,
                          height: 5,
                          decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(99)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Danh sách cứu hộ khẩn cấp', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          ),
                          Text('${_rescues.length} mục', style: const TextStyle(color: Colors.black54)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: _loading
                            ? const Center(child: CircularProgressIndicator())
                            : _error != null
                                ? Center(child: Text(_error!))
                                : ListView.builder(
                                    controller: scrollController,
                                    itemCount: _rescues.length,
                                    itemBuilder: (context, index) {
                                      final rescue = _rescues[index];
                                      return Card(
                                        margin: const EdgeInsets.only(bottom: 10),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(18),
                                          side: BorderSide(color: Colors.grey.shade200),
                                        ),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(18),
                                          onTap: () => _moveTo(rescue),
                                          child: Padding(
                                            padding: const EdgeInsets.all(14),
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  backgroundColor: const Color.fromRGBO(220, 38, 38, 0.12),
                                                  child: const Icon(Icons.home, color: Color(0xffdc2626)),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(rescue.address, style: const TextStyle(fontWeight: FontWeight.w800)),
                                                      Text('Cập nhật: ${_timeText(rescue.createdAt)}', style: const TextStyle(color: Colors.black54)),
                                                      Text(
                                                        'Trạng thái: ${_labelStatus(rescue.status)}',
                                                        style: TextStyle(color: _statusColor(rescue.status), fontWeight: FontWeight.w700),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                PopupMenuButton<String>(
                                                  onSelected: (value) {
                                                    if (value == 'rescuing' || value == 'done' || value == 'cancel') {
                                                      _setStatus(rescue, value);
                                                    }
                                                  },
                                                  itemBuilder: (context) => const [
                                                    PopupMenuItem(value: 'rescuing', child: Text('Đang cứu hộ')),
                                                    PopupMenuItem(value: 'done', child: Text('Hoàn thành')),
                                                    PopupMenuItem(value: 'cancel', child: Text('Hủy')),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: GestureDetector(
        onTap: () => Navigator.pushNamed(context, SosScreen.routeName),
        child: Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xffb91c1c), Color(0xffdc2626), Color(0xffef4444)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(color: Color(0x88DC2626), blurRadius: 20, spreadRadius: 3, offset: Offset(0, 8)),
              BoxShadow(color: Color(0x33FFFFFF), blurRadius: 4, spreadRadius: 1, offset: Offset(0, -2)),
            ],
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
              SizedBox(height: 2),
              Text(
                'SOS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        elevation: 14,
        color: Colors.white,
        child: SizedBox(
          height: 70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _bottomTabItem(icon: Icons.map, label: 'Bản đồ', index: 0),
              _bottomTabItem(icon: Icons.satellite_alt_rounded, label: 'Lớp phủ', index: 1),
              const SizedBox(width: 44),
              _bottomTabItem(icon: Icons.group, label: 'Đội cứu trợ', index: 2),
              _bottomTabItem(icon: Icons.dashboard_customize_rounded, label: 'Báo cáo', index: 3),
            ],
          ),
        ),
      ),
    );
  }
}
