import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_design_tokens.dart';
import 'app_motion.dart';

@immutable
class AppDesignPreset {
  const AppDesignPreset({
    required this.name,
    required this.seedColor,
    required this.tokens,
    this.motion = const AppMotionTokens(),
  });

  factory AppDesignPreset.commandCenter() => AppDesignPreset(
    name: 'command-center',
    seedColor: const Color(0xFF155EEF),
    tokens: AppDesignTokens.commandCenter(),
  );

  final String name;
  final Color seedColor;
  final AppDesignTokens tokens;
  final AppMotionTokens motion;

  ThemeData theme(Locale locale) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
      surface: tokens.surfaceRaised,
      error: tokens.danger,
    );
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
    );
    final typography = base.textTheme.apply(
      fontFamily: locale.languageCode == 'ar' ? 'NotoSansArabic' : 'NotoSans',
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    return base.copyWith(
      scaffoldBackgroundColor: tokens.canvas,
      textTheme: typography.copyWith(
        headlineMedium: typography.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: locale.languageCode == 'ar' ? 0 : -.5,
        ),
        headlineSmall: typography.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        titleLarge: typography.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        titleMedium: typography.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      extensions: [tokens, motion],
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: tokens.elevationLow,
        backgroundColor: tokens.surfaceRaised,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: tokens.elevationLow,
        color: tokens.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMedium),
          side: BorderSide(color: tokens.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surfaceRaised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusSmall),
          borderSide: BorderSide(color: tokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusSmall),
          borderSide: BorderSide(color: tokens.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size(0, tokens.controlHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radiusSmall),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(0, tokens.controlHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radiusSmall),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: Size.square(tokens.minimumTouchTarget),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: tokens.surfaceRaised,
        indicatorColor: tokens.selected,
        minWidth: 76,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: tokens.surfaceRaised,
        indicatorColor: tokens.selected,
        height: 72,
      ),
      dividerTheme: DividerThemeData(color: tokens.border, thickness: 1),
      chipTheme: base.chipTheme.copyWith(
        side: BorderSide(color: tokens.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusLarge),
        ),
      ),
    );
  }
}

final appDesignPresetProvider = Provider<AppDesignPreset>(
  (_) => AppDesignPreset.commandCenter(),
);
