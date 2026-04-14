import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/web_rescue_service.dart';

class SosScreen extends StatefulWidget {
  static const String routeName = '/sos';

  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  final WebRescueService _service = const WebRescueService();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _sourceUrlCtrl = TextEditingController();

  bool _sending = false;
  bool _updating = false;
  Position? _position;
  int? _latestSosId;
  int _victims = 1;
  String _sosType = 'rescue';

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _noteCtrl.dispose();
    _sourceUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _position = pos;
      });
    } catch (_) {
      // Ignore temporary GPS errors, user can retry.
    }
  }

  Future<void> _submitSos() async {
    if (_position == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chưa có vị trí GPS, thử lại sau vài giây')));
      return;
    }

    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty || _addressCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập đủ họ tên, số điện thoại và địa chỉ')));
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      final createdId = await _service.createSos(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        note: _noteCtrl.text.trim(),
        victims: _victims,
        sosType: _sosType,
        lat: _position!.latitude,
        lng: _position!.longitude,
        sourceUrl: _sourceUrlCtrl.text.trim().isEmpty ? null : _sourceUrlCtrl.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        _latestSosId = createdId;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            createdId == null
                ? 'Đã gửi SOS thành công, hệ thống đang điều phối'
                : 'Đã gửi SOS #$createdId, bạn có thể cập nhật thêm thông tin bên dưới',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gửi SOS thất bại: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<void> _updateLatestSos() async {
    final id = _latestSosId;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chưa có SOS mới để cập nhật')));
      return;
    }

    setState(() {
      _updating = true;
    });

    try {
      await _service.updateSosDetails(
        id: id,
        address: _addressCtrl.text.trim(),
        note: _noteCtrl.text.trim(),
        victims: _victims,
        sosType: _sosType,
        sourceUrl: _sourceUrlCtrl.text.trim().isEmpty ? null : _sourceUrlCtrl.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã cập nhật thêm thông tin cho SOS #$id')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cập nhật SOS thất bại: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _updating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffeef2ff),
      appBar: AppBar(
        backgroundColor: const Color(0xff0f172a),
        title: const Text('Gửi SOS khẩn cấp'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xfffee2e2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.emergency, color: Color(0xffdc2626)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Vị trí hiện tại', style: TextStyle(fontWeight: FontWeight.w800)),
                          Text(
                            _position == null
                                ? 'Đang lấy GPS...'
                                : '${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}',
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    IconButton(onPressed: _loadLocation, icon: const Icon(Icons.refresh)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Thông tin cần cứu hộ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Họ và tên', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(labelText: 'Số điện thoại', border: OutlineInputBorder()),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _addressCtrl,
                      decoration: const InputDecoration(labelText: 'Địa chỉ chi tiết', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _noteCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Mô tả tình trạng', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _sourceUrlCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nguồn tin/Ảnh hiện trường (URL)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _sosType,
                      decoration: const InputDecoration(labelText: 'Loại SOS', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'rescue', child: Text('Cần cứu hộ người')),
                        DropdownMenuItem(value: 'vehicle', child: Text('Cần cứu hộ xe')),
                        DropdownMenuItem(value: 'supplies', child: Text('Cần nhu yếu phẩm')),
                        DropdownMenuItem(value: 'other', child: Text('Yêu cầu khác')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _sosType = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text('Số người cần hỗ trợ:', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: () {
                            if (_victims > 1) {
                              setState(() {
                                _victims--;
                              });
                            }
                          },
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text('$_victims', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _victims++;
                            });
                          },
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _sending ? null : _submitSos,
                        icon: _sending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.send),
                        label: Text(_sending ? 'Đang gửi...' : 'Gửi SOS ngay'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xffdc2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: (_updating || _latestSosId == null) ? null : _updateLatestSos,
                        icon: _updating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.edit_note),
                        label: Text(
                          _latestSosId == null
                              ? 'Gửi SOS trước để cập nhật thêm thông tin'
                              : (_updating ? 'Đang cập nhật...' : 'Cập nhật thêm thông tin SOS mới'),
                        ),
                      ),
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
