import 'package:flutter/material.dart';
import 'package:marketplacedesign/bottomnav.dart';
import 'package:marketplacedesign/login.dart';
import 'package:marketplacedesign/register.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/home') {
          return MaterialPageRoute(
            builder: (context) => const BottomNav(),
          );
        }

        // fallback jika route tidak dikenali
        return MaterialPageRoute(
          builder: (context) => const LoginPage(),
        );
      },
      title: 'Marketplace Demo',
      theme: ThemeData(
        primarySwatch: Colors.teal,
      ),
      home: const LaunchPage(),
    );
  }
}

class LaunchPage extends StatefulWidget {
  const LaunchPage({super.key});

  @override
  State<LaunchPage> createState() => _LaunchPageState();
}

class _LaunchPageState extends State<LaunchPage> {
  bool _loading = true;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkToken();
  }

  Future<void> _checkToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('api_token');
    await Future.delayed(const Duration(milliseconds: 400));
    setState(() {
      _loggedIn = token != null && token.isNotEmpty;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_loggedIn) {
      // arahkan ke '/home' setelah build selesai
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // pastikan tidak memanggil berkali-kali (hanya replace sekali)
        Navigator.pushReplacementNamed(context, '/home');
      });
      // sementara tampilkan scaffold kosong (akan segera digantikan oleh route)
      return const Scaffold();
    }

    return const LoginPage();
  }
}
