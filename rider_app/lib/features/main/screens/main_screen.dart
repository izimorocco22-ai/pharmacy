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

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _locationDenied = false;

  final List<Widget> _screens = const [
    HomeScreen(),
    OrdersScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    LocationService.stopTracking(); // just cancel timer, don't mark offline
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initLocation();
    }
    // Do NOT mark offline on pause — rider stays online between screens
  }

  Future<void> _initLocation() async {
    final granted = await LocationService.requestPermission();
    if (!mounted) return;
    if (granted) {
      setState(() => _locationDenied = false);
      LocationService.startTracking();
    } else {
      setState(() => _locationDenied = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Column(
        children: [
          if (_locationDenied)
            Material(
              color: AppTheme.warning,
              child: InkWell(
                onTap: _initLocation,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.location_off, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Location permission required to receive nearby orders. Tap to enable.', // Could localize later
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
        ],
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
