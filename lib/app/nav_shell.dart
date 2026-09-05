import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shell dengan bottom navigation. Setiap tab ada stack navigasi sendiri
/// (StatefulShellRoute.indexedStack).
class NavShell extends StatelessWidget {
  const NavShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _onTap(int index) {
    shell.goBranch(
      index,
      // Tekan tab semasa sekali lagi → balik ke akar tab itu.
      initialLocation: index == shell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: _onTap,
        // Urutan MESTI sepadan dengan urutan `branches` dalam
        // router.dart - goBranch memilih mengikut indeks, bukan nama.
        // Diuji oleh test/app/nav_shell_test.dart.
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Utama',
          ),
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign),
            label: 'Hebahan',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Aktiviti',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Notifikasi',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
