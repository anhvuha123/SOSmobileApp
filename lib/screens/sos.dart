import 'package:flutter/material.dart';

class SosScreen extends StatelessWidget {
  static const String routeName = '/sos';
  const SosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cầu cứu khẩn cấp')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ứng dụng đang chuẩn bị gửi tín hiệu SOS', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SOS đã gửi')));
              },
              child: const Text('Gửi SOS'),
            ),
          ],
        ),
      ),
    );
  }
}
