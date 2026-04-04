import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Rescue {
  final String id;
  final String title;
  final String location;
  final String description;
  final String status;

  Rescue({
    required this.id,
    required this.title,
    required this.location,
    this.description = '',
    this.status = 'unknown',
  });

  factory Rescue.fromJson(Map<String, dynamic> json) {
    return Rescue(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? json['name']?.toString() ?? 'Không rõ',
      location: json['location']?.toString() ?? json['place']?.toString() ?? 'Không rõ',
      description: json['description']?.toString() ?? json['info']?.toString() ?? '',
      status: json['status']?.toString() ?? json['state']?.toString() ?? 'unknown',
    );
  }
}

class ApiClient {
  final String baseUrl;
  String? _token;

  ApiClient({this.baseUrl = 'http://localhost:3000/api'});

  void setToken(String token) {
    _token = token;
  }

  String? get token => _token;

  void clearToken() {
    _token = null;
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final uri = Uri.parse('$baseUrl/login');
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (resp.statusCode != 200) {
      throw Exception('Login thất bại ${resp.statusCode}: ${resp.body}');
    }

    final body = jsonDecode(resp.body);
    final token = body['token']?.toString() ?? body['accessToken']?.toString();
    if (token == null || token.isEmpty) {
      throw Exception('Login thành công nhưng không nhận token');
    }

    _token = token;
    return {
      'username': body['username']?.toString() ?? username,
      'role': body['role']?.toString() ?? '',
      'userId': body['userId']?.toString() ?? '',
      'token': token,
    };
  }

  Future<List<Rescue>> getRescues() async {
    final uri = Uri.parse('$baseUrl/rescues');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    final resp = await http.get(uri, headers: headers);

    if (resp.statusCode == 401) {
      throw Exception('Chưa xác thực (401)');
    }

    if (resp.statusCode != 200) {
      throw Exception('Lỗi lấy rescues ${resp.statusCode}: ${resp.body}');
    }

    final body = jsonDecode(resp.body);
    List<dynamic> items;
    if (body is List) {
      items = body;
    } else if (body is Map && body['data'] is List) {
      items = body['data'];
    } else {
      throw Exception('Dữ liệu rescues không đúng định dạng');
    }

    return items
        .map((item) => Rescue.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

class ReportScreen extends StatefulWidget {
  static const String routeName = '/report';

  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _apiClient = ApiClient();
  bool _isLoading = false;
  String? _error;
  List<Rescue> _rescues = [];
  List<Rescue> _filteredRescues = [];
  String _filterStatus = 'all'; // 'all', 'pending', 'done'

  @override
  void initState() {
    super.initState();
    _loadRescues();
  }

  Future<void> _loadRescues() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await _apiClient.getRescues();
      setState(() {
        _rescues = list;
        _applyFilter();
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFilter() {
    if (_filterStatus == 'all') {
      _filteredRescues = _rescues;
    } else {
      _filteredRescues = _rescues.where((r) => r.status.toLowerCase() == _filterStatus).toList();
    }
  }

  void _setFilter(String status) {
    setState(() {
      _filterStatus = status;
      _applyFilter();
    });
  }

  Future<void> _refreshRescues() async {
    await _loadRescues();
  }

  void _openDetail(Rescue rescue) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RescueDetailScreen(rescue: rescue)),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_username');
    await prefs.remove('auth_role');
    await prefs.remove('auth_userid');
    _apiClient.clearToken();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text(
                'Menu',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              onTap: () {
                Navigator.pop(context); // Close drawer
              },
            ),
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text('Map'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to map screen
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildRescueView(),
            ),
            if (_isLoading)
              Container(
                color: Colors.black26,
                child: const Center(
                  child: SizedBox(
                    height: 80,
                    width: 80,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRescueView() {
    final total = _rescues.length;
    final inProgress =
        (_rescues.where((r) => r.title.toLowerCase().contains('chờ')).length)
            .clamp(0, total);
    final completed =
        (_rescues
                .where(
                  (r) =>
                      r.title.toLowerCase().contains('đã hỗ trợ') ||
                      r.title.toLowerCase().contains('hoàn thành'),
                )
                .length)
            .clamp(0, total);
    final risk = (total > 0 ? (total * 100 ~/ 200).clamp(0, 100) : 0);

    Widget infoCard(String title, String value, Color color, IconData icon) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshRescues,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bảng điều khiển tổng quan',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Cập nhật lúc: ${DateTime.now().toLocal()}',
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                infoCard(
                  'Tổng số yêu cầu',
                  total.toString(),
                  Colors.blue,
                  Icons.request_page,
                ),
                const SizedBox(width: 12),
                infoCard(
                  'Đang xử lý',
                  inProgress.toString(),
                  Colors.orange,
                  Icons.sync,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                infoCard(
                  'Đã hoàn thành',
                  completed.toString(),
                  Colors.green,
                  Icons.check_circle,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.warning, color: Colors.red, size: 20),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Mức độ rủi ro',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '$risk%',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: risk / 100.0,
                          backgroundColor: Colors.red.withOpacity(0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Filter buttons
            Row(
              children: [
                FilterChip(
                  label: const Text('Tất cả'),
                  selected: _filterStatus == 'all',
                  onSelected: (_) => _setFilter('all'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Chờ xử lý'),
                  selected: _filterStatus == 'pending',
                  onSelected: (_) => _setFilter('pending'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Đã hoàn thành'),
                  selected: _filterStatus == 'done',
                  onSelected: (_) => _setFilter('done'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              shadowColor: Colors.black26,
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Yêu cầu SOS gần đây',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: _refreshRescues,
                          child: const Text('Làm mới'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_error != null)
                      Center(
                        child: Text(
                          'Lỗi: $_error',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    if (_filteredRescues.isEmpty && _error == null)
                      const Center(child: Text('Không có yêu cầu SOS')),
                    if (_filteredRescues.isNotEmpty)
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredRescues.length.clamp(0, 5),
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final rescue = _filteredRescues[index];
                          return ListTile(
                            title: Text(rescue.title),
                            subtitle: Text('${rescue.location} - ${rescue.status}'),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                            ),
                            onTap: () => _openDetail(rescue),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RescueDetailScreen extends StatelessWidget {
  final Rescue rescue;

  const RescueDetailScreen({super.key, required this.rescue});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết Rescue')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ID: ${rescue.id}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Tiêu đề: ${rescue.title}'),
            const SizedBox(height: 8),
            Text('Vị trí: ${rescue.location}'),
            const SizedBox(height: 8),
            Text(
              'Mô tả: ${rescue.description.isNotEmpty ? rescue.description : 'Không có thông tin'}',
            ),
          ],
        ),
      ),
    );
  }
}
