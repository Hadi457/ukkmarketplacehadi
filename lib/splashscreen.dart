import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:marketplacedesign/api_service.dart';
import 'package:marketplacedesign/bottomnav.dart';
import 'package:marketplacedesign/login.dart';
import 'package:marketplacedesign/home.dart';

class SplashScreen extends StatefulWidget {
  /// optional: path ke file logo lokal (development)
  final String? localLogoPath;
  final Duration duration;

  const SplashScreen({super.key, this.localLogoPath, this.duration = const Duration(seconds: 2)});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;
  final ApiService _api = ApiService();

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutBack));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animController, curve: Curves.easeIn));

    // start animation and then navigate after widget.duration
    _animController.forward();
    _startDelayAndNavigate();
  }

  Future<void> _startDelayAndNavigate() async {
    // Tunggu durasi splash + sedikit buffer
    await Future.delayed(widget.duration + const Duration(milliseconds: 400));

    // cek token (ApiService.getToken harus ada di projectmu)
    String? token;
    try {
      token = await _api.getToken();
    } catch (_) {
      token = null;
    }

    // navigasi (ganti route sesuai struktur app kamu)
    if (!mounted) return;
    if (token != null && token.isNotEmpty) {
      // sudah login -> Home
      Navigator.pushReplacement(context, PageRouteBuilder(
        pageBuilder: (_, __, ___) => const BottomNav(),
        transitionsBuilder: (_, a, __, child) {
          return FadeTransition(opacity: a, child: child);
        },
      ));
    } else {
      // belum login -> Login
      Navigator.pushReplacement(context, PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginPage(),
        transitionsBuilder: (_, a, __, child) {
          return FadeTransition(opacity: a, child: child);
        },
      ));
    }
  }

  Widget _buildLogo() {
    final path = widget.localLogoPath;

    // Jika user memakai path logo lokal → tetap pakai file
    if (path != null && File(path).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.file(File(path), width: 110, height: 110, fit: BoxFit.cover),
      );
    }

    // Fallback: gunakan icon sebagai logo
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: const Center(
        child: Icon(
          Icons.store,        // 🔥 ganti icon di sini
          size: 64,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // logo container
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: _buildLogo(),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Marketplace',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text('Menyiapkan aplikasi...', style: TextStyle(color: Colors.white54)),
                  const SizedBox(height: 18),
                  // subtle progress indicator
                  const SizedBox(
                    width: 46,
                    height: 8,
                    child: LinearProgressIndicator(
                      color: Colors.white,
                      backgroundColor: Colors.white10,
                      minHeight: 8,
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
