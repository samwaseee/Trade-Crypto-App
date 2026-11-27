import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:my_crypto/View/splash_screen.dart';
import 'package:my_crypto/View/app_route_observer.dart';
import 'package:my_crypto/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';

const String _appCheckDebugToken =
    String.fromEnvironment('APP_CHECK_DEBUG_TOKEN');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // Firebase AI Logic requires App Check (enforced since Nov 2, 2026).
  // Debug providers are used in debug builds; register the debug token printed
  // in the logs under Firebase console > App Check > Apps > Manage debug tokens.
  await FirebaseAppCheck.instance.activate(
    providerAndroid: kDebugMode
        ? AndroidDebugProvider(
            debugToken: _appCheckDebugToken.isNotEmpty
                ? _appCheckDebugToken
                : null,
          )
        : AndroidPlayIntegrityProvider(),
    providerApple: kDebugMode
        ? AppleDebugProvider(
            debugToken: _appCheckDebugToken.isNotEmpty
                ? _appCheckDebugToken
                : null,
          )
        : AppleAppAttestWithDeviceCheckFallbackProvider(),
  );
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
      navigatorObservers: [appRouteObserver],
      home: const SplashScreen(),
    );
  }
}
