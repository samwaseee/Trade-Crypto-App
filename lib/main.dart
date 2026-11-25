import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:my_crypto/View/splash_screen.dart';
import 'package:my_crypto/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  try {
    await FirebaseAppCheck.instance
        .activate(
          providerAndroid: kDebugMode
              ? const AndroidDebugProvider()
              : const AndroidPlayIntegrityProvider(),
        )
        .timeout(const Duration(seconds: 5));
  } catch (error) {
    debugPrint('Firebase App Check activation failed: $error');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
    );
  }
}
