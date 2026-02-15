import 'package:flutter/material.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, // Ubah jadi putih bersih agar lebih elegan
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06), // Shadow lembut di bagian atas
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      // SafeArea ditambahkan agar UI tidak bertabrakan dengan garis navigasi di bawah layar HP modern
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: onTap,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent, // Background transparent agar ikut Container
            elevation: 0,
            selectedItemColor: const Color(0xFF2A9D8F), // Warna Teal/Hijau modern (sesuai tema kartu)
            unselectedItemColor: Colors.grey.shade400, // Abu-abu yang lebih soft
            showUnselectedLabels: true,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.normal,
              fontSize: 11,
            ),
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(Icons.home_rounded), label: 'Home'), // Pakai icon _rounded
              BottomNavigationBarItem(
                  icon: Icon(Icons.search_rounded), label: 'Search'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.chat_bubble_outline_rounded), label: 'Bot'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.bookmark_border_rounded), label: 'Save'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline_rounded), label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}