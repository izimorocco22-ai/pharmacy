import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'core/localization/app_localizations.dart';
import 'providers/auth_provider.dart';
import 'providers/delivery_provider.dart';
import 'providers/language_provider.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/auth/screens/pending_approval_screen.dart';
import 'features/auth/screens/rejected_screen.dart';
import 'features/main/screens/main_screen.dart';
import 'features/deliveries/screens/delivery_detail_screen.dart';
import 'features/deliveries/screens/navigation_screen.dart';

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
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DeliveryProvider()),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          return MaterialApp(
            title: 'Ordo Rider',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            locale: languageProvider.locale,
            supportedLocales: const [
              Locale('en'),
              Locale('fr'),
              Locale('ar'),
            ],
            localizationsDelegates: const [
              AppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            initialRoute: '/',
            routes: {
          '/': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const MainScreen(),
          '/pending-approval': (context) => const PendingApprovalScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/rejected') {
            final note = (settings.arguments as String?) ?? '';
            return MaterialPageRoute(
              builder: (_) => RejectedScreen(adminNote: note),
            );
          }
          if (settings.name == '/register') {
            final prefill = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (_) => RegisterScreen(prefill: prefill),
            );
          }
          if (settings.name == '/delivery-detail') {
            final delivery = settings.arguments;
            return MaterialPageRoute(
              builder: (context) => DeliveryDetailScreen(delivery: delivery),
            );
          }
          if (settings.name == '/navigation') {
            final delivery = settings.arguments as Map<String, dynamic>?;
            if (delivery == null) return null;
            return MaterialPageRoute(
              builder: (context) => NavigationScreen(delivery: delivery),
            );
          }
          return null;
        },
      );
    },
  ),
);
  }
}
