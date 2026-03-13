import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/emergency_report.dart';
import '../services/firebase_service.dart';

class ReportScreen extends StatefulWidget {
  static const String routeName = '/report';
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _peopleController = TextEditingController();
  String _level = 'low';
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _peopleController.dispose();
    super.dispose();
  }

  Future<bool> _submit() async {
    if (!_formKey.currentState!.validate()) return false;

    setState(() => _submitting = true);

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final report = EmergencyReport(
        id: '',
        title: _titleController.text.trim(),
        subtitle: _subtitleController.text.trim(),
        people: int.tryParse(_peopleController.text) ?? 1,
        lat: position.latitude,
        lng: position.longitude,
        level: _level,
        time: Timestamp.now(),
      );

      await FirebaseService.addReport(report);
      return true;
    } catch (_) {
      return false;
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Vui lòng bật quyền định vị trong cài đặt.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Báo cáo tình hình')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Tiêu đề', border: OutlineInputBorder()),
                validator: (value) => value == null || value.trim().isEmpty ? 'Vui lòng nhập tiêu đề' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _subtitleController,
                decoration: const InputDecoration(labelText: 'Mô tả', border: OutlineInputBorder()),
                minLines: 3,
                maxLines: 5,
                validator: (value) => value == null || value.trim().isEmpty ? 'Vui lòng nhập mô tả' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _peopleController,
                decoration: const InputDecoration(labelText: 'Số người', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (value) {
                  final v = int.tryParse(value ?? '');
                  if (v == null || v <= 0) return 'Nhập số người hợp lệ';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _level,
                decoration: const InputDecoration(labelText: 'Mức độ nguy hiểm', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Thấp')),
                  DropdownMenuItem(value: 'medium', child: Text('Trung bình')),
                  DropdownMenuItem(value: 'high', child: Text('Cao')),
                ],
                onChanged: (value) {
                  setState(() {
                    _level = value ?? 'low';
                  });
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitting
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(context);
                        try {
                          await _checkLocationPermission();
                          final succeeded = await _submit();
                          if (!mounted) return;
                          if (succeeded) {
                            messenger.showSnackBar(const SnackBar(content: Text('Báo cáo đã gửi thành công')));
                            navigator.pop();
                          } else {
                            messenger.showSnackBar(const SnackBar(content: Text('Lỗi gửi báo cáo')));
                          }
                        } catch (e) {
                          if (!mounted) return;
                          messenger.showSnackBar(SnackBar(content: Text('Lỗi quyền định vị: $e')));
                        }
                      },
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _submitting ? const CircularProgressIndicator() : const Text('Gửi báo cáo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
