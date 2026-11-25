import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_crypto/View/navBar.dart';
import 'package:my_crypto/View/welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _minimumSplashDuration = Duration(milliseconds: 600);
  static const _authTimeoutDuration = Duration(seconds: 4);
  late final DateTime _startedAt;
  StreamSubscription<User?>? _authSubscription;
  Timer? _authTimeoutTimer;
  bool _navigationStarted = false;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _authTimeoutTimer = Timer(
      _authTimeoutDuration,
      () => _finishSplash(null),
    );

    try {
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
            _onAuthStateChanged,
            onError: (_) => _finishSplash(null),
          );
    } catch (_) {
      _finishSplash(null);
    }
  }

  Future<void> _onAuthStateChanged(User? user) => _finishSplash(user);

  Future<void> _finishSplash(User? user) async {
    if (_navigationStarted) return;
    _navigationStarted = true;
    _authTimeoutTimer?.cancel();
    await _authSubscription?.cancel();

    final elapsed = DateTime.now().difference(_startedAt);
    final remaining = _minimumSplashDuration - elapsed;
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);
    if (!mounted) return;

    final destination = user == null ? const WelcomeScreen() : const NavBar();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => destination),
      (_) => false,
    );
  }

  @override
  void dispose() {
    _authTimeoutTimer?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.primaryContainer,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox.shrink(),
              Column(
                children: [
                  Text(
                    'Trade Crypto',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Created by',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Image.asset(
                        'assets/image/sam.png',
                        height: 36,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Image.asset(
                    'assets/image/loading1.gif',
                    height: 16,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
