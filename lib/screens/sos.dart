import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/vietnam_address.dart';
import '../services/vietnam_address_service.dart';
import '../services/web_rescue_service.dart';

class SosScreen extends StatefulWidget {
  static const String routeName = '/sos';

  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  final WebRescueService _service = const WebRescueService();
  final VietnamAddressService _addressService = VietnamAddressService();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _detailAddressCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _sourceUrlCtrl = TextEditingController();

  bool _sending = false;
  bool _updating = false;
  Position? _position;
  int? _latestSosId;
  int _victims = 1;
  String _sosType = 'rescue';

  // Cascading address
  List<Province> _provinces = [];
  List<District> _districts = [];
  List<Ward> _wards = [];
  Province? _selectedProvince;
  District? _selectedDistrict;
  Ward? _selectedWard;
  bool _loadingProvinces = true;
  bool _loadingDistricts = false;
  bool _loadingWards = false;

  @override
  void initState() {
    super.initState();
    _loadLocation();
    _loadProvinces();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _detailAddressCtrl.dispose();
    _noteCtrl.dispose();
    _sourceUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProvinces() async {
    try {
      final provinces = await _addressService.getProvinces();
      if (!mounted) return;
      setState(() {
        _provinces = provinces;
        _loadingProvinces = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingProvinces = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tải tỉnh: $e')));
    }
  }

  Future<void> _loadDistricts(Province province) async {
    setState(() {
      _loadingDistricts = true;
      _selectedDistrict = null;
      _selectedWard = null;
      _districts = [];
      _wards = [];
    });
    try {
      final districts = await _addressService.getDistricts(province.code);
      if (!mounted) return;
      setState(() {
        _districts = districts;
        _loadingDistricts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingDistricts = false);
    }
  }

  Future<void> _loadWards(District district) async {
    setState(() {
      _loadingWards = true;
      _selectedWard = null;
      _wards = [];
    });
    try {
      final wards = await _addressService.getWards(district.code);
      if (!mounted) return;
      setState(() {
        _wards = wards;
        _loadingWards = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingWards = false);
    }
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
      // ignore
    }
  }

  Future<void> _submitSos() async {
    if (_position == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chưa có vị trí GPS, thử lại sau vài giây')));
      return;
    }

    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty || _selectedProvince == null || _selectedDistrict == null || _selectedWard == null || _detailAddressCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng điền: họ tên, số điện thoại, địa chỉ (tỉnh/huyện/xã) và chi tiết nhà')));
      return;
    }

    setState(() => _sending = true);

    try {
      final fullAddress = '${_detailAddressCtrl.text.trim()}, ${_selectedWard!.name}, ${_selectedDistrict!.name}, ${_selectedProvince!.name}';
      final createdId = await _service.createSos(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        address: fullAddress,
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
        _sending = false;
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
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _updateLatestSos() async {
    final id = _latestSosId;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chưa có SOS mới để cập nhật')));
      return;
    }

    setState(() => _updating = true);

    try {
      final fullAddress = _selectedProvince != null && _selectedDistrict != null && _selectedWard != null
          ? '${_detailAddressCtrl.text.trim()}, ${_selectedWard!.name}, ${_selectedDistrict!.name}, ${_selectedProvince!.name}'
          : _detailAddressCtrl.text.trim();
      await _service.updateSosDetails(
        id: id,
        address: fullAddress,
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
      if (mounted) setState(() => _updating = false);
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

    if (confirm == true) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff4f7fc),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: const Color(0xff163a70),
                child: Row(
                  children: [
                    const CircleAvatar(radius: 22, backgroundColor: Colors.white, child: Icon(Icons.person, color: Color(0xff163a70))),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Tài khoản', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                  ],
                ),
              ),
              ListTile(leading: const Icon(Icons.person_outline), title: const Text('Thông tin cá nhân'), onTap: () => Navigator.pop(context)),
              ListTile(leading: const Icon(Icons.bar_chart), title: const Text('Thống kê'), subtitle: const Text('Đã hoàn thành, tỷ lệ chấp nhận'), onTap: () => Navigator.pop(context)),
              ListTile(leading: const Icon(Icons.bug_report), title: const Text('Báo lỗi'), onTap: () => Navigator.pop(context)),
              const Spacer(),
              ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('Đăng xuất', style: TextStyle(color: Colors.red)), onTap: () {
                Navigator.pop(context);
                _logout();
              }),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        backgroundColor: const Color(0xff163a70),
        leading: Builder(builder: (ctx) => IconButton(onPressed: () => Scaffold.of(ctx).openDrawer(), icon: const Icon(Icons.menu))),
        title: const Row(children: [Icon(Icons.campaign_rounded, color: Colors.white), SizedBox(width: 10), Text('Gửi SOS khẩn cấp')]),
        actions: [IconButton(onPressed: _logout, icon: const Icon(Icons.logout), tooltip: 'Đăng xuất')],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: const LinearGradient(colors: [Color(0xff1d4ed8), Color(0xff2563eb), Color(0xff3b82f6)])),
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Gửi yêu cầu cứu hộ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)), SizedBox(height: 4), Text('Điền thông tin rõ ràng để điều phối nhanh nhất.', style: TextStyle(color: Color(0xffdbeafe), fontSize: 13))]),
            ),
            const SizedBox(height: 16),
            Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(color: const Color(0xfffee2e2), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.emergency, color: Color(0xffdc2626), size: 24)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Vị trí hiện tại', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), Text(_position == null ? 'Đang lấy GPS...' : '${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}', style: const TextStyle(color: Colors.black54, fontSize: 12))])),
              IconButton(onPressed: _loadLocation, icon: const Icon(Icons.refresh, size: 20), padding: EdgeInsets.zero),
            ]))),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Thông tin cần cứu hộ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 14),
                    TextField(controller: _nameCtrl, decoration: InputDecoration(labelText: 'Họ và tên', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12))),
                    const SizedBox(height: 12),
                    TextField(controller: _phoneCtrl, decoration: InputDecoration(labelText: 'Số điện thoại', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)), keyboardType: TextInputType.phone),
                    const SizedBox(height: 12),
                    if (_loadingProvinces) const Center(child: CircularProgressIndicator()) else DropdownButtonFormField<Province>(value: _selectedProvince, decoration: InputDecoration(labelText: 'Tỉnh/Thành phố', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)), items: _provinces.map((p) => DropdownMenuItem(value: p, child: Text(p.name, style: const TextStyle(fontSize: 13)))).toList(), onChanged: (province) { if (province != null) { setState(() => _selectedProvince = province); _loadDistricts(province); } }),
                    const SizedBox(height: 12),
                    if (_selectedProvince == null)
                      TextField(enabled: false, decoration: InputDecoration(labelText: 'Chọn tỉnh trước', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)))
                    else if (_loadingDistricts)
                      const Center(child: CircularProgressIndicator())
                    else
                      DropdownButtonFormField<District>(value: _selectedDistrict, decoration: InputDecoration(labelText: 'Quận/Huyện', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)), items: _districts.map((d) => DropdownMenuItem(value: d, child: Text(d.name, style: const TextStyle(fontSize: 13)))).toList(), onChanged: (district) { if (district != null) { setState(() => _selectedDistrict = district); _loadWards(district); } }),
                    const SizedBox(height: 12),
                    if (_selectedDistrict == null)
                      TextField(enabled: false, decoration: InputDecoration(labelText: 'Chọn huyện trước', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)))
                    else if (_loadingWards)
                      const Center(child: CircularProgressIndicator())
                    else
                      DropdownButtonFormField<Ward>(value: _selectedWard, decoration: InputDecoration(labelText: 'Phường/Xã', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)), items: _wards.map((w) => DropdownMenuItem(value: w, child: Text(w.name, style: const TextStyle(fontSize: 13)))).toList(), onChanged: (ward) { if (ward != null) setState(() => _selectedWard = ward); }),
                    const SizedBox(height: 12),
                    TextField(controller: _detailAddressCtrl, decoration: InputDecoration(labelText: 'Số nhà, tên đường', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)), maxLines: 2),
                    const SizedBox(height: 12),
                    TextField(controller: _noteCtrl, maxLines: 3, decoration: InputDecoration(labelText: 'Mô tả tình trạng', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12))),
                    const SizedBox(height: 12),
                    TextField(controller: _sourceUrlCtrl, decoration: InputDecoration(labelText: 'Nguồn tin/Ảnh hiện trường (URL)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)), keyboardType: TextInputType.url),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(initialValue: _sosType, decoration: InputDecoration(labelText: 'Loại SOS', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)), items: const [DropdownMenuItem(value: 'rescue', child: Text('Cần cứu hộ người')), DropdownMenuItem(value: 'vehicle', child: Text('Cần cứu hộ xe')), DropdownMenuItem(value: 'supplies', child: Text('Cần nhu yếu phẩm')), DropdownMenuItem(value: 'other', child: Text('Yêu cầu khác'))], onChanged: (value) { if (value != null) setState(() => _sosType = value); }),
                    const SizedBox(height: 12),
                    Row(children: [const Text('Số người cần hỗ trợ:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), const SizedBox(width: 10), IconButton(onPressed: () { if (_victims > 1) setState(() => _victims--); }, icon: const Icon(Icons.remove_circle_outline, size: 22), padding: EdgeInsets.zero), Text('$_victims', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), IconButton(onPressed: () => setState(() => _victims++), icon: const Icon(Icons.add_circle_outline, size: 22), padding: EdgeInsets.zero)]),
                    const SizedBox(height: 16),
                    SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _sending ? null : _submitSos, icon: _sending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send), label: Text(_sending ? 'Đang gửi...' : 'Gửi SOS ngay', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff2563eb), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
                    const SizedBox(height: 10),
                    SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: (_updating || _latestSosId == null) ? null : _updateLatestSos, icon: _updating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.edit_note), label: Text(_latestSosId == null ? 'Gửi SOS trước để cập nhật' : (_updating ? 'Đang cập nhật...' : 'Cập nhật thông tin SOS'), style: const TextStyle(fontSize: 13)), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
