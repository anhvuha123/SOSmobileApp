import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/report_screen.dart';
import 'services/firebase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.init();
  runApp(const AppMobileSOS());
}

class AppMobileSOS extends StatelessWidget {
  const AppMobileSOS({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Emergency Reporting',
      theme: ThemeData(primarySwatch: Colors.deepOrange, useMaterial3: true),
      initialRoute: HomeScreen.routeName,
      routes: {
        HomeScreen.routeName: (context) => const HomeScreen(),
        ReportScreen.routeName: (context) => const ReportScreen(),
      },
    );
  }
}
