import 'package:flutter/material.dart';
import 'package:rajlaxmi_myhub_app/shared_prefs_service.dart';
import 'home_screen.dart';
import 'screens/register_screen.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rajlaxmi MyHub',
      home: FutureBuilder(
        future: SharedPrefsService.isUserLoggedIn(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // If user is logged in, go directly to HomeScreen
          if (snapshot.data == true) {
            return FutureBuilder(
              future: SharedPrefsService.getUserData(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                final userData = userSnapshot.data ?? {};
                return HomeScreen(
                  authToken: userData['authToken'] ?? '',
                  name: userData['name'] ?? 'User',
                  email: userData['email'] ?? '',
                );
              },
            );
          } else {
            // If not logged in, show LoginScreen
            return const LoginScreen();
          }
        },
      ),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
      },
    );
  }
}