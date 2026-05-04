import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:appmobilesos/services/api_config.dart';

class LoginScreen extends StatefulWidget {
  static const String routeName = '/login';

  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String _demoEmail = 'demo@gmail.com';
  static const String _demoPassword = '@Demo123';

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<bool> _tryTemporaryDemoLogin() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    final password = _passwordCtrl.text.trim();

    if (email != _demoEmail || password != _demoPassword) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', 'demo-local-token');
    await prefs.setString('auth_username', _demoEmail);
    await prefs.setString('auth_role', 'admin');
    await prefs.setString('auth_userid', 'demo-local-user');
    await prefs.setBool('demo_mode', true);

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/report');
    }

    return true;
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    if (await _tryTemporaryDemoLogin()) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final body = await _loginWithFallbacks();
      final token = body['token']?.toString() ?? body['accessToken']?.toString();
      if (token == null || token.isEmpty) {
        throw Exception('Login thành công nhưng không nhận token');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      await prefs.setBool('demo_mode', false);
      await prefs.setString(
        'auth_username',
        body['username']?.toString() ??
            body['email']?.toString() ??
            _emailCtrl.text.trim(),
      );
      await prefs.setString('auth_role', body['role']?.toString() ?? '');
      await prefs.setString('auth_userid', body['userId']?.toString() ?? '');

      if (mounted) {
        final role = body['role']?.toString() ?? '';
        final route = switch (role) {
          'rescuer' => '/rescuer',
          'admin' => '/report',
          _ => '/home',
        };
        Navigator.of(context).pushReplacementNamed(route);
      }
    } on SocketException {
      setState(() {
        _error = 'Không kết nối được tới backend. Kiểm tra lại API_BASE_URL hoặc địa chỉ server.';
      });
    } catch (e) {
      final message = e.toString();
      setState(() {
        _error = message.contains('ClientException')
            ? 'Không gọi được API đăng nhập. Kiểm tra server đang chạy và địa chỉ backend.'
            : message;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _loginWithFallbacks() async {
    Object? lastError;
    for (final baseUrl in ApiConfig.loginBaseUrlCandidates()) {
      try {
        final uri = Uri.parse('$baseUrl/login');
        final resp = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': _emailCtrl.text.trim().toLowerCase(),
            'password': _passwordCtrl.text.trim(),
          }),
        );

        if (resp.statusCode != 200) {
          throw Exception('Login thất bại ${resp.statusCode}: ${resp.body}');
        }

        final decoded = jsonDecode(resp.body);
        if (decoded is! Map<String, dynamic>) {
          throw Exception('Phản hồi đăng nhập không hợp lệ');
        }
        return decoded;
      } catch (e) {
        lastError = e;
      }
    }

    throw Exception('Không kết nối được tới backend đăng nhập. Lỗi cuối: $lastError');
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo & Title
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_rounded, color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Cứu hộ',
                    style: text.headlineLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Đăng nhập với tài khoản của bạn',
                    style: text.bodyMedium?.copyWith(color: color.onSurface.withOpacity(0.6)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),

                  // Email Field
                  TextField(
                    controller: _emailCtrl,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),

                  // Password Field
                  TextField(
                    controller: _passwordCtrl,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    obscureText: true,
                  ),

                  // Error Message
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.error.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: color.error, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error ?? '', style: TextStyle(color: color.error, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      child: _isLoading
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Đăng nhập', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Demo Buttons Row
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _emailCtrl.text = _demoEmail;
                            _passwordCtrl.text = _demoPassword;
                          },
                          child: const Text('Điền demo'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _isLoading ? null : () => _tryTemporaryDemoLogin(),
                          child: const Text('Demo ngay'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Info Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: color.onSurface.withOpacity(0.6)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Demo: $_demoEmail / $_demoPassword',
                            style: text.bodySmall?.copyWith(color: color.onSurface.withOpacity(0.6)),
                          ),
                        ),
                      ],
                    ),
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
