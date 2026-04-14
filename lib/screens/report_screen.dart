import 'package:flutter/material.dart';

import '../models/web_rescue.dart';
import '../services/web_rescue_service.dart';

class ReportScreen extends StatefulWidget {
  static const String routeName = '/report';

  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final WebRescueService _service = const WebRescueService();

  bool _loading = true;
  String? _error;
  List<WebRescue> _rescues = const [];
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

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

  Color _statusColor(String status) {
    switch (status) {
      case 'new':
        return const Color(0xfff59e0b);
      case 'rescuing':
        return const Color(0xff2563eb);
      case 'done':
        return const Color(0xff16a34a);
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

  List<WebRescue> get _filtered {
    if (_filter == 'all') return _rescues;
    return _rescues.where((r) => r.status == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final total = _rescues.length;
    final pending = _rescues.where((r) => r.status == 'new').length;
    final rescuing = _rescues.where((r) => r.status == 'rescuing').length;
    final done = _rescues.where((r) => r.status == 'done').length;

    return Scaffold(
      backgroundColor: const Color(0xffeef2ff),
      appBar: AppBar(
        backgroundColor: const Color(0xff0f172a),
        title: const Text('Báo cáo cứu hộ'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh, color: Colors.white)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Bảng điều khiển tổng quan', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('Đồng bộ trực tiếp từ backend web', style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 14),
            Row(
              children: [
                _statCard('Tổng yêu cầu', '$total', Icons.list_alt, const Color(0xff2563eb)),
                const SizedBox(width: 10),
                _statCard('Mới', '$pending', Icons.warning_amber_rounded, const Color(0xfff59e0b)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _statCard('Đang cứu hộ', '$rescuing', Icons.emergency, const Color(0xffdc2626)),
                const SizedBox(width: 10),
                _statCard('Hoàn thành', '$done', Icons.check_circle, const Color(0xff16a34a)),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _filterChip('all', 'Tất cả'),
                _filterChip('new', 'Mới'),
                _filterChip('rescuing', 'Đang cứu hộ'),
                _filterChip('done', 'Hoàn thành'),
                _filterChip('cancel', 'Đã hủy'),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Lỗi tải báo cáo: $_error'),
                ),
              )
            else if (_filtered.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Không có dữ liệu phù hợp bộ lọc.'),
                ),
              )
            else
              ..._filtered.map(
                (rescue) => Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                rescue.address,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _statusColor(rescue.status).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _statusLabel(rescue.status),
                                style: TextStyle(
                                  color: _statusColor(rescue.status),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Người gửi: ${rescue.name} - ${rescue.phone}'),
                        Text('Nạn nhân: ${rescue.victims} | Loại: ${rescue.sosType}'),
                        Text('Thời gian: ${_timeText(rescue.createdAt)}'),
                        if (rescue.note.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text('Mô tả: ${rescue.note}', style: const TextStyle(color: Colors.black54)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _filter == value,
      onSelected: (_) {
        setState(() {
          _filter = value;
        });
      },
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
                ],
              ),
              const SizedBox(height: 14),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
            ],
          ),
        ),
      ),
    );
  }
}
