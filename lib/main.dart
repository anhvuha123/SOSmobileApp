import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/report_screen.dart';
import 'screens/login_screen.dart';
import 'screens/sos.dart';
import 'screens/rescuer_screen.dart';
import 'services/firebase_service.dart';
import 'themes/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.init();
  runApp(const AppMobileSOS());
}

class AppMobileSOS extends StatefulWidget {
  const AppMobileSOS({super.key});

  @override
  State<AppMobileSOS> createState() => _AppMobileSOSState();
}

class _AppMobileSOSState extends State<AppMobileSOS> {
  String? _initialRoute;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final role = prefs.getString('auth_role');

    String route = '/login';
    if (token != null && token.isNotEmpty) {
      route = switch (role) {
        'rescuer' => RescuerScreen.routeName,
        'admin' => HomeScreen.routeName,
        _ => SosScreen.routeName,
      };
    }

    setState(() {
      _initialRoute = route;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_initialRoute == null) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Emergency Reporting',
      theme: AppTheme.lightTheme,
      home: switch (_initialRoute) {
        '/login' => const LoginScreen(),
        '/home' => const HomeScreen(),
        '/rescuer' => const RescuerScreen(),
        '/sos' => const SosScreen(),
        _ => const LoginScreen(),
      },
      routes: {
        '/login': (context) => const LoginScreen(),
        '/report': (context) => const ReportScreen(),
        HomeScreen.routeName: (context) => const HomeScreen(),
        SosScreen.routeName: (context) => const SosScreen(),
        RescuerScreen.routeName: (context) => const RescuerScreen(),
      },
    );
  }
}
