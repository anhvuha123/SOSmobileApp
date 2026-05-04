import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/web_rescue.dart';
import '../services/map_tiles.dart';
import '../services/web_rescue_service.dart';
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
  StreamSubscription<Position>? _locationSub;
  
  List<WebRescue> _rescues = const [];
  WebRescue? _selected;
  LatLng? _userLocation;
  bool _loading = true;
  String? _error;
  bool _satelliteMode = false;

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

    try {
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final userPoint = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() {
        _userLocation = userPoint;
        _center = userPoint;
        _mapController.move(userPoint, 14);
      });

      _locationSub = Geolocator.getPositionStream().listen((position) {
        final point = LatLng(position.latitude, position.longitude);
        if (!mounted) return;
        setState(() {
          _userLocation = point;
        });
      });
    } catch (e) {
      // Fallback: use default center if geolocation fails
    }
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
        SnackBar(content: Text('Cập nhật: ${_labelStatus(status)}')),
      );
    } catch (e) {
      setState(() {
        _rescues = _rescues
            .map((item) => item.id == rescue.id ? item.copyWith(status: status) : item)
            .toList();
        if (_selected?.id == rescue.id) {
          _selected = _selected!.copyWith(status: status);
        }
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật tạm thời (offline)')),
      );
    }
  }

  Future<void> _openDirections(WebRescue rescue) async {
    final destination = '${rescue.lat},${rescue.lng}';
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$destination&travelmode=driving');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Không mở được Google Maps')),
    );
  }

  String _labelStatus(String status) {
    switch (status) {
      case 'new': return 'Mới';
      case 'rescuing': return 'Đang cứu hộ';
      case 'done': return 'Hoàn thành';
      case 'cancel': case 'canceled': case 'cancelled': return 'Đã hủy';
      default: return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'new': return const Color(0xfff59e0b);
      case 'rescuing': return const Color(0xff2563eb);
      case 'done': return const Color(0xff16a34a);
      case 'cancel': case 'canceled': case 'cancelled': return const Color(0xff64748b);
      default: return const Color(0xff64748b);
    }
  }

  String _timeText(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Vừa';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  Widget _controlButton(IconData icon, VoidCallback onPressed) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Icon(icon, size: 18, color: const Color(0xff1e3a8a)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = _rescues.where((r) => r.status == 'new' || r.status == 'rescuing').toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        title: const Text('Bản đồ cứu hộ', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, RescuerScreen.routeName),
            icon: const Icon(Icons.person, color: Colors.white),
          ),
        ],
      ),
      body: Stack(
        children: [
          // MAP - Main area
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 100),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(initialCenter: _center, initialZoom: _zoom),
                  children: [
                    TileLayer(
                      urlTemplate: mapTileUrl(_satelliteMode ? MapBaseLayer.satellite : MapBaseLayer.standard),
                      userAgentPackageName: 'appmobilosos',
                    ),
                    MarkerLayer(
                      markers: _rescues
                          .where((r) => r.lat != 0 && r.lng != 0)
                          .map((r) => Marker(
                            point: LatLng(r.lat, r.lng),
                            width: 36,
                            height: 36,
                            child: GestureDetector(
                              onTap: () => _moveTo(r),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _selected?.id == r.id ? const Color(0xffdc2626) : const Color(0xffef4444),
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _statusColor(r.status).withOpacity(0.4),
                                      blurRadius: _selected?.id == r.id ? 12 : 8,
                                      spreadRadius: _selected?.id == r.id ? 2 : 0,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 16),
                              ),
                            ),
                          ))
                          .toList(),
                    ),
                    if (_userLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _userLocation!,
                            width: 32,
                            height: 32,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context).colorScheme.primary,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: Icon(Icons.my_location_rounded, color: Colors.white, size: 14),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Controls - Top right
          Positioned(
            right: 12,
            top: 12,
            child: Column(
              children: [
                _controlButton(Icons.add, () {
                  setState(() => _zoom = (_zoom + 1).clamp(5, 18).toDouble());
                  _mapController.move(_center, _zoom);
                }),
                const SizedBox(height: 8),
                _controlButton(Icons.remove, () {
                  setState(() => _zoom = (_zoom - 1).clamp(5, 18).toDouble());
                  _mapController.move(_center, _zoom);
                }),
                const SizedBox(height: 8),
                _controlButton(_satelliteMode ? Icons.layers : Icons.satellite_alt, () {
                  setState(() => _satelliteMode = !_satelliteMode);
                }),
                const SizedBox(height: 8),
                _controlButton(Icons.my_location, () {
                  if (_userLocation != null) {
                    _mapController.move(_userLocation!, 14);
                  }
                }),
              ],
            ),
          ),

          // Detail Card - Bottom when selected
          if (_selected != null)
            Positioned(
              bottom: 110,
              left: 12,
              right: 12,
              child: GestureDetector(
                onTap: () {}, // Prevent dismissal on tap
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selected!.address,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_selected!.victims} người • ${_timeText(_selected!.createdAt)}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _statusColor(_selected!.status).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _labelStatus(_selected!.status),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _statusColor(_selected!.status),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  await _setStatus(_selected!, 'rescuing');
                                  await _openDirections(_selected!);
                                },
                                icon: const Icon(Icons.navigation, size: 16),
                                label: const Text('Chỉ đường'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.tonal(
                                onPressed: () => _setStatus(_selected!, 'done'),
                                child: const Text('Xong'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // List - Bottom sheet (MINIMAL)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 100,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, -4))],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 20,
                          decoration: BoxDecoration(
                            color: const Color(0xffdc2626),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${active.length} đang mở • ${_rescues.length} tổng',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        const Spacer(),
                        if (_loading)
                          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        else if (_error != null)
                          const Icon(Icons.warning_amber, size: 16, color: Color(0xffdc2626))
                        else
                          const Icon(Icons.check_circle, size: 16, color: Color(0xff16a34a)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _error != null
                            ? Center(child: Text(_error!, style: const TextStyle(fontSize: 12)))
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                scrollDirection: Axis.horizontal,
                                itemCount: _rescues.length,
                                itemBuilder: (context, index) {
                                  final rescue = _rescues[index];
                                  final isSelected = _selected?.id == rescue.id;
                                  return GestureDetector(
                                    onTap: () => _moveTo(rescue),
                                    child: Container(
                                      width: 120,
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            rescue.address,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: _statusColor(rescue.status).withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              _labelStatus(rescue.status),
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                                color: _statusColor(rescue.status),
                                              ),
                                            ),
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

          // SOS Button - Center bottom
          Positioned(
            bottom: 110,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => Navigator.pushNamed(context, SosScreen.routeName),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Color(0xffff8a8a), Color(0xffdc2626)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xffdc2626).withOpacity(0.5),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'SOS',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
