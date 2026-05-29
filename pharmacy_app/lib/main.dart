import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/prescription_provider.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/auth/screens/pending_approval_screen.dart';
import 'features/auth/screens/rejected_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/requests/screens/prescription_detail_screen.dart';
import 'features/requests/screens/quote_builder_screen.dart';
import 'features/orders/order_detail_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PrescriptionProvider()),
      ],
      child: MaterialApp(
        title: 'Ordo Pharmacy Store',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) {
            final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
            return RegisterScreen(prefillData: args);
          },
          '/home': (context) => const HomeScreen(),
          '/pending-approval': (context) => const PendingApprovalScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/rejected') {
            final note = settings.arguments as String? ?? '';
            return MaterialPageRoute(
              builder: (_) => RejectedScreen(adminNote: note),
            );
          }
          if (settings.name == '/prescription-detail') {
            return MaterialPageRoute(
              builder: (_) => PrescriptionDetailScreen(prescription: settings.arguments),
            );
          }
          if (settings.name == '/quote-builder') {
            return MaterialPageRoute(
              builder: (_) => QuoteBuilderScreen(prescription: settings.arguments),
            );
          }
          if (settings.name == '/order-detail') {
            return MaterialPageRoute(
              builder: (_) => OrderDetailScreen(order: settings.arguments),
            );
          }
          return null;
        },
      ),
    );
  }
}
