import 'package:flutter/material.dart';
import 'package:marketplacedesign/home.dart';
import 'package:marketplacedesign/my_store.dart';
import 'package:marketplacedesign/product-store.dart';
import 'package:marketplacedesign/profile.dart';
import 'package:marketplacedesign/api_service.dart';

class BottomNav extends StatelessWidget {
  const BottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String? _token;
  bool _loadingToken = true;

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    _pages = [
      const HomePage(),
      const Center(child: CircularProgressIndicator()),
      const MyStorePage(),
      const ProfilePage(),
    ];

    _initToken();
  }

  Future<void> _initToken() async {
    try {
      final token = await ApiService().getToken();
      setState(() {
        _token = token;
        _loadingToken = false;

        _pages = [
          const HomePage(),
          if (token == null || token.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Silakan login untuk melihat produk toko',
                    textAlign: TextAlign.center),
              ),
            )
          else
            TokoProdukPage(token: token),
          const MyStorePage(),
          const ProfilePage(),
        ];
      });
    } catch (e) {
      setState(() {
        _loadingToken = false;
        _pages = [
          const HomePage(),
          Center(child: Text('Gagal ambil token: $e')),
          const MyStorePage(),
          const ProfilePage(),
        ];
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = _pages[_selectedIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: body,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.black,
          border: Border(
            top: BorderSide(color: Colors.white24, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.black,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white54,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined, size: 26),
              activeIcon: Icon(Icons.home, size: 28),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_bag_outlined, size: 26),
              activeIcon: Icon(Icons.shopping_bag, size: 28),
              label: 'Product',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.storefront_outlined, size: 26),
              activeIcon: Icon(Icons.storefront, size: 28),
              label: 'My Store',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline, size: 26),
              activeIcon: Icon(Icons.person, size: 28),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
