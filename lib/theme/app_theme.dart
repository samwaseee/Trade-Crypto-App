import 'package:material_ui/material_ui.dart';

@immutable
class TradingColors extends ThemeExtension<TradingColors> {
  final Color gain;
  final Color onGain;
  final Color loss;
  final Color onLoss;
  final Color warning;

  const TradingColors({
    required this.gain,
    required this.onGain,
    required this.loss,
    required this.onLoss,
    required this.warning,
  });

  static const light = TradingColors(
    gain: Color(0xFF43A047),
    onGain: Colors.black87,
    loss: Color(0xFFE53935),
    onLoss: Colors.white,
    warning: Color(0xFFEF6C00),
  );

  static const dark = TradingColors(
    gain: Color(0xFF43A047),
    onGain: Colors.black87,
    loss: Color(0xFFE53935),
    onLoss: Colors.white,
    warning: Color(0xFFEF6C00),
  );

  @override
  TradingColors copyWith({
    Color? gain,
    Color? onGain,
    Color? loss,
    Color? onLoss,
    Color? warning,
  }) {
    return TradingColors(
      gain: gain ?? this.gain,
      onGain: onGain ?? this.onGain,
      loss: loss ?? this.loss,
      onLoss: onLoss ?? this.onLoss,
      warning: warning ?? this.warning,
    );
  }

  @override
  TradingColors lerp(ThemeExtension<TradingColors>? other, double t) {
    if (other is! TradingColors) return this;
    return TradingColors(
      gain: Color.lerp(gain, other.gain, t)!,
      onGain: Color.lerp(onGain, other.onGain, t)!,
      loss: Color.lerp(loss, other.loss, t)!,
      onLoss: Color.lerp(onLoss, other.onLoss, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}

class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xffFBC700),
      brightness: Brightness.light,
    );
    return _buildTheme(colorScheme);
  }

  static ThemeData get dark {
    final l = ColorScheme.fromSeed(seedColor: const Color(0xffFBC700), brightness: Brightness.light);
    final scheme = l.copyWith(
      brightness: Brightness.dark,
      surface: const Color(0xFF121212),
      surfaceDim: const Color(0xFF121212),
      surfaceBright: const Color(0xFF2C2C2C),
      surfaceContainerLowest: const Color(0xFF0D0D0D),
      surfaceContainerLow: const Color(0xFF1A1A1A),
      surfaceContainer: const Color(0xFF1E1E1E),
      surfaceContainerHigh: const Color(0xFF252525),
      surfaceContainerHighest: const Color(0xFF2E2E2E),
      onSurface: const Color(0xFFE6E6E6),
      onSurfaceVariant: const Color(0xFFB0B0B0),
      outline: const Color(0xFF8A8A8A),
      outlineVariant: const Color(0xFF444444),
      inverseSurface: const Color(0xFFE6E6E6),
      onInverseSurface: const Color(0xFF1E1E1E),
      surfaceTint: Colors.transparent,
    );
    return _buildTheme(scheme);
  }

  static ThemeData _buildTheme(ColorScheme colorScheme) {
    final tradingColors = colorScheme.brightness == Brightness.light
        ? TradingColors.light
        : TradingColors.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      extensions: [tradingColors],
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          minimumSize: const Size.fromHeight(52),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: colorScheme.primary.withValues(alpha: 0.3),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: colorScheme.primary,
        dividerColor: Colors.transparent,
        labelColor: colorScheme.onSurface,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
      ),
    );
  }
}
