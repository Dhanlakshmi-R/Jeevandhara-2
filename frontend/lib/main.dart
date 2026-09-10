import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const JeevandharaApp());
}

class JeevandharaApp extends StatelessWidget {
  const JeevandharaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jeevandhara',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
      ),
      home: const _AuthGate(),
    );
  }
}

/// Checks for a stored token on startup and routes straight to Home if
/// already logged in, otherwise shows the Login screen.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: ApiService().isLoggedIn(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return (snapshot.data ?? false) ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}
