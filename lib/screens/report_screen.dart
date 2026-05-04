import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/web_rescue.dart';
import '../services/map_tiles.dart';
import '../services/web_rescue_service.dart';

String _statusLabel(String status) {
  switch (status) {
    case 'new': return 'Mới';
    case 'rescuing': return 'Đang nhận';
    case 'done': return 'Hoàn thành';
    default: return status;
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'new': return const Color(0xfff59e0b);
    case 'rescuing': return const Color(0xff2563eb);
    case 'done': return const Color(0xff16a34a);
    default: return const Color(0xff64748b);
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

int _statusOrder(String status) {
  switch (status) {
    case 'new': return 0;
    case 'rescuing': return 1;
    case 'done': return 2;
    default: return 3;
  }
}

List<String> _assignedRescuerNames(List<dynamic> assignedRescuers) {
  final names = <String>[];
  for (final item in assignedRescuers) {
    final name = _rescuerName(item);
    if (name.isNotEmpty && !names.contains(name)) {
      names.add(name);
    }
  }
  return names;
}

String _rescuerName(dynamic item) {
  if (item == null) return '';
  if (item is String) return item.trim();
  if (item is Map) {
    final map = item.cast<dynamic, dynamic>();
    final candidates = [
      map['name'],
      map['fullName'],
      map['username'],
      map['displayName'],
      map['email'],
    ];
    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return item.toString();
  }
  return item.toString();
}

class ReportScreen extends StatefulWidget {
  static const String routeName = '/report';

  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final WebRescueService _service = const WebRescueService();
  final MapController _mapController = MapController();
  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = true;
  String? _error;
  List<WebRescue> _rescues = const [];
  String _filter = 'all';
  String _query = '';
  LatLng _center = const LatLng(10.762622, 106.660172);
  double _zoom = 13;

  Timer? _polling;

  @override
  void initState() {
    super.initState();
    _load();
    _polling = Timer.periodic(const Duration(seconds: 6), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _polling?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final data = await _service.getRescues();
      if (!mounted) return;
      setState(() {
        _rescues = data;
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

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn chắc chắn muốn đăng xuất?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Đăng xuất', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true && mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
    }
  }

  Future<void> _acceptMission(WebRescue rescue) async {
    try {
      await _service.updateRescueStatus(rescue.id, 'rescuing');
      await _load(silent: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhiệm vụ đã được chấp nhận và đẩy vào bản đồ.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }

  Future<void> _finishMission(WebRescue rescue) async {
    try {
      await _service.updateRescueStatus(rescue.id, 'done');
      await _load(silent: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhiệm vụ đã được đánh dấu hoàn thành.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }

  List<WebRescue> get _visibleRescues {
    final query = _query.trim().toLowerCase();
    final rescues = _rescues.where((rescue) {
      final matchesFilter = _filter == 'all' || rescue.status == _filter;
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;

      final names = _assignedRescuerNames(rescue.assignedRescuers).join(' ').toLowerCase();
      return rescue.name.toLowerCase().contains(query) ||
          rescue.phone.toLowerCase().contains(query) ||
          rescue.address.toLowerCase().contains(query) ||
          rescue.note.toLowerCase().contains(query) ||
          rescue.sosType.toLowerCase().contains(query) ||
          names.contains(query);
    }).toList();

    rescues.sort((a, b) {
      final statusCompare = _statusOrder(a.status).compareTo(_statusOrder(b.status));
      if (statusCompare != 0) return statusCompare;
      return (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0));
    });
    return rescues;
  }

  int get _totalCount => _rescues.length;
  int get _newCount => _rescues.where((r) => r.status == 'new').length;
  int get _rescuingCount => _rescues.where((r) => r.status == 'rescuing').length;

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
    final visibleRescues = _visibleRescues;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.primary,
                child: const Row(
                  children: [
                    CircleAvatar(radius: 22, backgroundColor: Colors.white, child: Icon(Icons.dashboard_rounded, color: Color(0xff1d4ed8))),
                    SizedBox(width: 12),
                    Expanded(child: Text('Bảng điều phối', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.map_outlined),
                title: const Text('Bản đồ chính'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/home');
                },
              ),
              ListTile(
                leading: const Icon(Icons.refresh_rounded),
                title: const Text('Làm mới'),
                onTap: () {
                  Navigator.pop(context);
                  _load();
                },
              ),
              const Spacer(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _logout();
                },
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
            icon: const Icon(Icons.menu_rounded, color: Colors.white),
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        title: const Text('Bảng điều phối', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Bản đồ',
            onPressed: () => Navigator.pushNamed(context, '/home'),
            icon: const Icon(Icons.map_outlined, color: Colors.white),
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh, color: Colors.white)),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout_rounded, color: Colors.white)),
        ],
      ),
      body: Stack(
        children: [
          // Bản đồ nền
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(initialCenter: _center, initialZoom: _zoom),
              children: [
                TileLayer(
                  urlTemplate: mapTileUrl(MapBaseLayer.standard),
                  userAgentPackageName: 'appmobilosos',
                ),
                MarkerLayer(
                  markers: visibleRescues
                      .where((r) => r.lat != 0 && r.lng != 0)
                      .map((r) => Marker(
                            point: LatLng(r.lat, r.lng),
                            width: 32,
                            height: 32,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _statusColor(r.status),
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: Center(
                                child: Text(
                                  _statusLabel(r.status)[0],
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
          // Top: Search + Filter
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.96),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 10, offset: Offset(0, 4))],
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        hintText: 'Tìm nhiệm vụ, đội, địa chỉ...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Xóa',
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(Icons.clear_rounded),
                              ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterPill(label: 'Tất cả', selected: _filter == 'all', onTap: () => setState(() => _filter = 'all')),
                        const SizedBox(width: 8),
                        _FilterPill(label: 'Mới', selected: _filter == 'new', onTap: () => setState(() => _filter = 'new')),
                        const SizedBox(width: 8),
                        _FilterPill(label: 'Đang nhận', selected: _filter == 'rescuing', onTap: () => setState(() => _filter = 'rescuing')),
                        const SizedBox(width: 8),
                        _FilterPill(label: 'Hoàn thành', selected: _filter == 'done', onTap: () => setState(() => _filter = 'done')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Right: Control buttons
          Positioned(
            right: 12,
            top: 200,
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
              ],
            ),
          ),
          // Bottom: Danh sách nhiệm vụ
          if (!_loading)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 240,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, -4))],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Nhiệm vụ điều phối',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                Text(
                                  '${visibleRescues.length} nhiệm vụ • Mới: $_newCount • Đang nhận: $_rescuingCount',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _loading
                          ? _SkeletonLoadingList()
                          : visibleRescues.isEmpty
                              ? Center(
                                  child: Text(
                                    'Không có nhiệm vụ',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  itemCount: visibleRescues.length,
                                  itemBuilder: (context, index) {
                                    final rescue = visibleRescues[index];
                                    final rescuerNames = _assignedRescuerNames(rescue.assignedRescuers).join(', ');

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.all(12),
                                        leading: Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: _statusColor(rescue.status),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Center(
                                            child: Icon(Icons.location_on_rounded, color: Colors.white, size: 20),
                                          ),
                                        ),
                                        title: Text(
                                          rescue.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w700),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 2),
                                            Text(
                                              rescue.address,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                            if (rescuerNames.isNotEmpty)
                                              Text(
                                                'Đội: $rescuerNames',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 11, color: Color(0xff1d4ed8)),
                                              ),
                                            Text(
                                              _timeText(rescue.createdAt),
                                              style: const TextStyle(fontSize: 11, color: Colors.black54),
                                            ),
                                          ],
                                        ),
                                        trailing: rescue.status == 'new'
                                            ? SizedBox(
                                                width: 80,
                                                child: FilledButton.tonal(
                                                  onPressed: () => _acceptMission(rescue),
                                                  child: const Text('Nhận', style: TextStyle(fontSize: 11)),
                                                ),
                                              )
                                            : FilledButton.tonal(
                                                onPressed: () => _finishMission(rescue),
                                                child: const Text('Xong', style: TextStyle(fontSize: 11)),
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
          // Loading indicator
          if (_loading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}

class _SkeletonLoadingList extends StatelessWidget {
  const _SkeletonLoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 14,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 12,
                        width: 180,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 12,
                        width: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 60,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      backgroundColor: Colors.white.withOpacity(0.7),
      selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
    );
  }
}
