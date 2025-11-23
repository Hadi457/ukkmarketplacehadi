import 'package:flutter/material.dart';
import 'package:marketplacedesign/bottomnav.dart';
import 'package:marketplacedesign/login.dart';
import 'package:marketplacedesign/register.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp()); // jalankan aplikasi
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      routes: {
        '/login': (context) => const LoginPage(), // routing ke login
        '/register': (context) => const RegisterPage(), // routing ke register
      },
      onGenerateRoute: (settings) {
        // handle route dynamic, khusus halaman home
        if (settings.name == '/home') {
          return MaterialPageRoute(
            builder: (context) => const BottomNav(),
          );
        }
        // fallback ke login
        return MaterialPageRoute(
          builder: (context) => const LoginPage(),
        );
      },
      title: 'Marketplace Demo',
      theme: ThemeData(
        primarySwatch: Colors.teal, // tema utama
      ),
      home: const LaunchPage(), // halaman awal
    );
  }
}

// halaman pertama saat aplikasi dibuka
class LaunchPage extends StatefulWidget {
  const LaunchPage({super.key});

  @override
  State<LaunchPage> createState() => _LaunchPageState();
}

class _LaunchPageState extends State<LaunchPage> {
  bool _loading = true; // loading awal
  bool _loggedIn = false; // status login

  @override
  void initState() {
    super.initState();
    _checkToken(); // cek token di storage
  }

  Future<void> _checkToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('api_token'); // ambil token

    await Future.delayed(const Duration(milliseconds: 400)); // delay kecil biar smooth

    setState(() {
      _loggedIn = token != null && token.isNotEmpty; // cek apakah sudah login
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator())); // tampilkan loading
    }

    if (_loggedIn) {
      // jika sudah login, langsung redirect ke home setelah frame build selesai
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/home');
      });
      return const Scaffold(); // kosong sementara redirect
    }

    // jika belum login, tampilkan halaman login
    return const LoginPage();
  }
}