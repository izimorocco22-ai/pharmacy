import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/location_service.dart';
import '../../../core/localization/app_localizations.dart';
import '../../home/screens/home_screen.dart';
import '../../orders/screens/orders_screen.dart';
import '../../profile/screens/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    OrdersScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Ask for location permission once on launch (the system dialog). We do
    // NOT start tracking or change online status here — tracking begins only
    // when the rider explicitly goes online from the home screen. No in-app
    // banner is shown; the system permission prompt is enough.
    LocationService.requestPermission();
  }

  @override
  void dispose() {
    LocationService.stopTracking(); // just cancel timer, don't mark offline
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: AppTheme.textSecondary,
        backgroundColor: AppTheme.surface,
        elevation: 8,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.delivery_dining_outlined),
            activeIcon: const Icon(Icons.delivery_dining),
            label: l10n.translate('deliveries'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.receipt_long_outlined),
            activeIcon: const Icon(Icons.receipt_long),
            label: l10n.translate('status'), // or active
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            activeIcon: const Icon(Icons.person),
            label: l10n.translate('profile'),
          ),
        ],
      ),
    );
  }
}
