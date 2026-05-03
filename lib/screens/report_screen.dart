import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';

import '../models/web_rescue.dart';
import '../services/web_rescue_service.dart';

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
  String? _ipAddress;

  List<WebRescue> get _demoRescues => const [
        WebRescue(
          id: 101,
          name: 'Nguyen Van A',
          phone: '0901001001',
          address: '123 Lê Lợi, Quận 1, TP.HCM',
          note: 'Khu vực ngập sâu khoảng 50cm, cần hỗ trợ khẩn.',
          sourceUrl: null,
          victims: 3,
          sosType: 'rescue',
          status: 'new',
          lat: 10.7769,
          lng: 106.7009,
          createdAt: null,
          assignedRescuers: [],
        ),
        WebRescue(
          id: 102,
          name: 'Tran Thi B',
          phone: '0902002002',
          address: '88 Võ Văn Tần, Quận 3, TP.HCM',
          note: 'Cần đưa người già và trẻ nhỏ ra khỏi khu vực an toàn.',
          sourceUrl: null,
          victims: 5,
          sosType: 'supplies',
          status: 'rescuing',
          lat: 10.7746,
          lng: 106.6925,
          createdAt: null,
          assignedRescuers: [],
        ),
        WebRescue(
          id: 103,
          name: 'Le Van C',
          phone: '0903003003',
          address: '45 Nguyễn Huệ, Quận 1, TP.HCM',
          note: 'Đã tiếp cận hiện trường, đang xác nhận lại tình trạng.',
          sourceUrl: null,
          victims: 1,
          sosType: 'other',
          status: 'done',
          lat: 10.7721,
          lng: 106.7018,
          createdAt: null,
          assignedRescuers: [],
        ),
      ];

  @override
  void initState() {
    super.initState();
    _load();
    _getIpAddress();
  }

  Future<void> _getIpAddress() async {
    final info = NetworkInfo();
    try {
      final ip = await info.getWifiIP();
      if (!mounted) return;
      setState(() {
        _ipAddress = ip;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ipAddress = 'Không lấy được IP';
      });
    }
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

  List<WebRescue> get _filtered {
    if (_filter == 'all') {
      return _rescues;
    }
    return _rescues.where((r) => r.status == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final demoFiltered = _demoRescues.where((item) {
      if (_filter == 'all') return true;
      return item.status == _filter;
    }).toList();
    final total = _rescues.length;
    final pending = _rescues.where((r) => r.status == 'new').length;
    final rescuing = _rescues.where((r) => r.status == 'rescuing').length;
    final done = _rescues.where((r) => r.status == 'done').length;

    return Scaffold(
      backgroundColor: const Color(0xfff4f7fc),
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
        title: const Row(
          children: [
            Icon(Icons.dashboard_rounded),
            SizedBox(width: 10),
            Text('Báo cáo cứu hộ'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_ipAddress != null) ...[
                          _IpBanner(ipAddress: _ipAddress!),
                          const SizedBox(height: 12),
                        ],
                        const _ReportHeroCard(),
                        const SizedBox(height: 16),
                        _MetricGrid(
                          total: total,
                          pending: pending,
                          rescuing: rescuing,
                          done: done,
                        ),
                        const SizedBox(height: 16),
                        _FilterBar(
                          selectedFilter: _filter,
                          onSelected: (value) {
                            setState(() {
                              _filter = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _CenteredState(
                  icon: Icons.refresh_rounded,
                  title: 'Đang tải dữ liệu',
                  subtitle: 'Hệ thống đang đồng bộ danh sách cứu hộ từ backend.',
                ),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _DemoPreviewState(
                  title: 'Backend chưa sẵn sàng',
                  subtitle: 'Đây là dữ liệu mẫu để bạn xem UI ngay mà không cần kết nối server.',
                  error: _error!,
                  items: demoFiltered,
                ),
              )
            else if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _DemoPreviewState(
                  title: 'Không có dữ liệu thật',
                  subtitle: 'Vẫn có thể xem trước giao diện bằng dữ liệu mẫu bên dưới.',
                  error: null,
                  items: demoFiltered,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final rescue = filtered[index];
                      return Padding(
                        padding: EdgeInsets.only(bottom: index == filtered.length - 1 ? 0 : 12),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1120),
                            child: _RescueCard(rescue: rescue),
                          ),
                        ),
                      );
                    },
                    childCount: filtered.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReportHeroCard extends StatelessWidget {
  const _ReportHeroCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff0f172a), Color(0xff1d4ed8), Color(0xff2563eb)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1f0f172a),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: const Icon(Icons.dashboard_rounded, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bảng điều khiển tổng quan',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Dữ liệu cứu hộ được đồng bộ trực tiếp từ backend web, tối ưu cho việc theo dõi nhanh và ra quyết định.',
                    style: TextStyle(
                      color: Color(0xffdbeafe),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IpBanner extends StatelessWidget {
  const _IpBanner({required this.ipAddress});

  final String ipAddress;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xffeff6ff),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffbfdbfe)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xffdbeafe),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.wifi_rounded, color: Color(0xff1d4ed8)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kết nối hiện tại',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: const Color(0xff1e3a8a),
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ipAddress,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xff1e3a8a),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.total,
    required this.pending,
    required this.rescuing,
    required this.done,
  });

  final int total;
  final int pending;
  final int rescuing;
  final int done;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _MetricCard(
        title: 'Tổng yêu cầu',
        value: '$total',
        icon: Icons.list_alt_rounded,
        color: const Color(0xff2563eb),
      ),
      _MetricCard(
        title: 'Mới',
        value: '$pending',
        icon: Icons.warning_amber_rounded,
        color: const Color(0xfff59e0b),
      ),
      _MetricCard(
        title: 'Đang cứu hộ',
        value: '$rescuing',
        icon: Icons.emergency_rounded,
        color: const Color(0xffdc2626),
      ),
      _MetricCard(
        title: 'Hoàn thành',
        value: '$done',
        icon: Icons.check_circle_rounded,
        color: const Color(0xff16a34a),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 960
            ? 4
            : width >= 620
                ? 2
                : 1;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: crossAxisCount == 1 ? 2.9 : 1.8,
          children: cards,
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      surfaceTintColor: theme.colorScheme.surfaceTint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selectedFilter,
    required this.onSelected,
  });

  final String selectedFilter;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _FilterChip(
          label: 'Tất cả',
          selected: selectedFilter == 'all',
          onSelected: () => onSelected('all'),
        ),
        _FilterChip(
          label: 'Mới',
          selected: selectedFilter == 'new',
          onSelected: () => onSelected('new'),
        ),
        _FilterChip(
          label: 'Đang cứu hộ',
          selected: selectedFilter == 'rescuing',
          onSelected: () => onSelected('rescuing'),
        ),
        _FilterChip(
          label: 'Hoàn thành',
          selected: selectedFilter == 'done',
          onSelected: () => onSelected('done'),
        ),
        _FilterChip(
          label: 'Đã hủy',
          selected: selectedFilter == 'cancel',
          onSelected: () => onSelected('cancel'),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: colorScheme.primary,
      backgroundColor: colorScheme.surface,
      side: BorderSide(
        color: selected ? colorScheme.primary : colorScheme.outlineVariant,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}

class _RescueList extends StatelessWidget {
  const _RescueList({required this.items});

  final List<WebRescue> items;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final rescue = items[index];
        return Padding(
          padding: EdgeInsets.only(bottom: index == items.length - 1 ? 0 : 12),
          child: _RescueCard(rescue: rescue),
        );
      },
    );
  }
}

class _RescueCard extends StatelessWidget {
  const _RescueCard({required this.rescue});

  final WebRescue rescue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(rescue.status);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      surfaceTintColor: theme.colorScheme.surfaceTint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    rescue.address,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _StatusBadge(label: _statusLabel(rescue.status), color: statusColor),
              ],
            ),
            const SizedBox(height: 12),
            _MetaRow(
              icon: Icons.person_rounded,
              text: 'Người gửi: ${rescue.name} • ${rescue.phone}',
            ),
            const SizedBox(height: 8),
            _MetaRow(
              icon: Icons.groups_rounded,
              text: 'Nạn nhân: ${rescue.victims} • Loại: ${rescue.sosType}',
            ),
            const SizedBox(height: 8),
            _MetaRow(
              icon: Icons.schedule_rounded,
              text: 'Thời gian: ${_timeText(rescue.createdAt)}',
            ),
            if (rescue.note.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  rescue.note,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _CenteredState extends StatelessWidget {
  const _CenteredState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(icon, color: theme.colorScheme.primary, size: 34),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.error,
    required this.onRetry,
  });

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 0,
            color: theme.colorScheme.surface,
            surfaceTintColor: theme.colorScheme.surfaceTint,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 34),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Không tải được báo cáo',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoPreviewState extends StatelessWidget {
  const _DemoPreviewState({
    required this.title,
    required this.subtitle,
    required this.error,
    required this.items,
  });

  final String title;
  final String subtitle;
  final String? error;
  final List<WebRescue> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 0,
                color: theme.colorScheme.surface,
                surfaceTintColor: theme.colorScheme.surfaceTint,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Icon(Icons.visibility_rounded, color: theme.colorScheme.primary, size: 34),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          error!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (items.isNotEmpty) ...[
                const SizedBox(height: 16),
                _RescueList(items: items),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
