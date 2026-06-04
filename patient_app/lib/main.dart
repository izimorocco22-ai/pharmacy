import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'core/localization/app_localizations.dart';
import 'models/quote_model.dart';
import 'providers/auth_provider.dart';
import 'providers/prescription_provider.dart';
import 'providers/order_provider.dart';
import 'providers/language_provider.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/signup_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/prescription/screens/upload_prescription_screen.dart';
import 'features/prescription/screens/address_selection_screen.dart';
import 'features/orders/screens/quote_details_screen.dart';
import 'features/orders/screens/payment_selection_screen.dart';
import 'features/orders/screens/order_tracking_screen.dart';
import 'features/orders/screens/order_history_screen.dart';
import 'features/orders/screens/my_quotes_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/profile/screens/edit_profile_screen.dart';
import 'features/profile/screens/saved_addresses_screen.dart';
import 'features/profile/screens/payment_methods_screen.dart';
import 'features/profile/screens/notifications_screen.dart';
import 'features/profile/screens/help_support_screen.dart';
import 'features/profile/screens/about_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  
  // Initialize Firebase (optional - comment out if not using)
  // await Firebase.initializeApp();
  
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
        ChangeNotifierProvider(create: (_) => PrescriptionProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          return MaterialApp(
            title: 'OrdoGo Medicine app',
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
          '/signup': (context) => const SignupScreen(),
          '/home': (context) => const HomeScreen(),
          '/upload-prescription': (context) => const UploadPrescriptionScreen(),
          '/address-selection': (context) => const AddressSelectionScreen(),
          '/payment-selection': (context) => const PaymentSelectionScreen(),
          '/order-history': (context) => const OrderHistoryScreen(),
          '/my-quotes': (context) => const MyQuotesScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/edit-profile': (context) => const EditProfileScreen(),
          '/saved-addresses': (context) => const SavedAddressesScreen(),
          '/payment-methods': (context) => const PaymentMethodsScreen(),
          '/notifications': (context) => const NotificationsScreen(),
          '/help-support': (context) => const HelpSupportScreen(),
          '/about': (context) => const AboutScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/quote-details') {
            final quote = settings.arguments as Quote?;
            if (quote != null) {
              return MaterialPageRoute(
                builder: (context) => QuoteDetailsScreen(quote: quote),
              );
            }
          }
          if (settings.name == '/order-tracking') {
            final orderId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (context) => OrderTrackingScreen(orderId: orderId),
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
