import 'package:flutter/material.dart';

import '../design_system/app_design_tokens.dart';
import '../design_system/app_motion.dart';

enum LabConcept { routeBeacon, nightDispatch, fieldLedger }

enum LabSurface { dashboard, driverToday, driverTruck, components }

extension LabConceptQuery on LabConcept {
  String get query => switch (this) {
    LabConcept.routeBeacon => 'a',
    LabConcept.nightDispatch => 'b',
    LabConcept.fieldLedger => 'c',
  };
}

extension LabSurfaceQuery on LabSurface {
  String get query => switch (this) {
    LabSurface.dashboard => 'dashboard',
    LabSurface.driverToday => 'today',
    LabSurface.driverTruck => 'truck',
    LabSurface.components => 'components',
  };
}

@immutable
class DesignLabConfiguration {
  const DesignLabConfiguration({
    required this.concept,
    required this.surface,
    required this.locale,
    required this.showControls,
  });

  factory DesignLabConfiguration.fromUri(Uri uri) {
    final query = uri.queryParameters;
    final concept = switch (query['concept']?.toLowerCase()) {
      'b' || 'night' => LabConcept.nightDispatch,
      'c' || 'ledger' => LabConcept.fieldLedger,
      _ => LabConcept.routeBeacon,
    };
    final surface = switch (query['surface']?.toLowerCase()) {
      'today' => LabSurface.driverToday,
      'truck' => LabSurface.driverTruck,
      'components' => LabSurface.components,
      _ => LabSurface.dashboard,
    };
    final locale = query['locale'] == 'en'
        ? const Locale('en')
        : const Locale('ar');
    return DesignLabConfiguration(
      concept: concept,
      surface: surface,
      locale: locale,
      showControls: query['controls'] != '0',
    );
  }

  final LabConcept concept;
  final LabSurface surface;
  final Locale locale;
  final bool showControls;

  DesignLabConfiguration copyWith({
    LabConcept? concept,
    LabSurface? surface,
    Locale? locale,
    bool? showControls,
  }) => DesignLabConfiguration(
    concept: concept ?? this.concept,
    surface: surface ?? this.surface,
    locale: locale ?? this.locale,
    showControls: showControls ?? this.showControls,
  );
}

@immutable
class LabConceptPreset {
  const LabConceptPreset({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required this.rationaleEn,
    required this.rationaleAr,
    required this.adjectives,
    required this.canvas,
    required this.surface,
    required this.surfaceStrong,
    required this.ink,
    required this.muted,
    required this.border,
    required this.primary,
    required this.secondary,
    required this.signal,
    required this.danger,
    required this.success,
    required this.mapLand,
    required this.mapRoad,
    required this.radiusSmall,
    required this.radiusLarge,
    required this.navigationWidth,
    required this.dark,
    required this.motion,
  });

  final LabConcept id;
  final String nameEn;
  final String nameAr;
  final String rationaleEn;
  final String rationaleAr;
  final List<String> adjectives;
  final Color canvas;
  final Color surface;
  final Color surfaceStrong;
  final Color ink;
  final Color muted;
  final Color border;
  final Color primary;
  final Color secondary;
  final Color signal;
  final Color danger;
  final Color success;
  final Color mapLand;
  final Color mapRoad;
  final double radiusSmall;
  final double radiusLarge;
  final double navigationWidth;
  final bool dark;
  final AppMotionTokens motion;

  String name(Locale locale) => locale.languageCode == 'ar' ? nameAr : nameEn;
  String rationale(Locale locale) =>
      locale.languageCode == 'ar' ? rationaleAr : rationaleEn;

  AppDesignTokens get tokens => AppDesignTokens.commandCenter().copyWith(
    canvas: canvas,
    surfaceRaised: surface,
    border: border,
    textMuted: muted,
    success: success,
    warning: signal,
    danger: danger,
    information: secondary,
    selected: primary.withValues(alpha: dark ? .22 : .12),
    disabled: muted.withValues(alpha: .55),
    online: success,
    offline: muted,
    stale: signal,
    moving: secondary,
    stationary: muted,
    maintenance: primary,
    tripPlanned: secondary,
    tripActive: success,
    tripCompleted: primary,
    tripCancelled: danger,
    mapRoute: primary,
    mapTrail: secondary,
    radiusSmall: radiusSmall,
    radiusMedium: (radiusSmall + radiusLarge) / 2,
    radiusLarge: radiusLarge,
    compactBreakpoint: 600,
    expandedBreakpoint: 1024,
    maximumContentWidth: 1600,
  );

  ThemeData theme(Locale locale) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: dark ? Brightness.dark : Brightness.light,
          surface: surface,
          error: danger,
        ).copyWith(
          primary: primary,
          secondary: secondary,
          surface: surface,
          onSurface: ink,
          outline: border,
        );
    final base = ThemeData(
      colorScheme: scheme,
      brightness: dark ? Brightness.dark : Brightness.light,
      useMaterial3: true,
      scaffoldBackgroundColor: canvas,
      fontFamily: locale.languageCode == 'ar' ? 'NotoSansArabic' : 'NotoSans',
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: ink,
        displayColor: ink,
        fontFamily: locale.languageCode == 'ar' ? 'NotoSansArabic' : 'NotoSans',
      ),
      extensions: [tokens, motion],
      dividerColor: border,
      splashFactory: InkSparkle.splashFactory,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceStrong,
        hintStyle: TextStyle(color: muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide(color: primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: _readableOn(primary),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
        ),
      ),
    );
  }

  static Color _readableOn(Color color) =>
      color.computeLuminance() > .42 ? const Color(0xFF17201D) : Colors.white;

  static const routeBeacon = LabConceptPreset(
    id: LabConcept.routeBeacon,
    nameEn: 'Route Beacon',
    nameAr: 'منارة المسار',
    rationaleEn:
        'A warm command surface organized by a continuous route spine and decisive beacon moments.',
    rationaleAr:
        'سطح قيادة دافئ تنظمه سكة مسار متصلة وإشارات واضحة للحظات التشغيل المهمة.',
    adjectives: ['directional', 'grounded', 'warm', 'decisive', 'human'],
    canvas: Color(0xFFF3EDE2),
    surface: Color(0xFFFFFBF3),
    surfaceStrong: Color(0xFFE8DED0),
    ink: Color(0xFF29231F),
    muted: Color(0xFF71665D),
    border: Color(0xFFD8CABC),
    primary: Color(0xFFB7432A),
    secondary: Color(0xFF24756F),
    signal: Color(0xFFD39A32),
    danger: Color(0xFF9F2E2E),
    success: Color(0xFF2E7651),
    mapLand: Color(0xFFE5DACA),
    mapRoad: Color(0xFFF9F3E9),
    radiusSmall: 6,
    radiusLarge: 18,
    navigationWidth: 92,
    dark: false,
    motion: AppMotionTokens(
      fast: Duration(milliseconds: 160),
      standard: Duration(milliseconds: 240),
      emphasized: Duration(milliseconds: 320),
    ),
  );

  static const nightDispatch = LabConceptPreset(
    id: LabConcept.nightDispatch,
    nameEn: 'Night Dispatch',
    nameAr: 'غرفة الترحيل',
    rationaleEn:
        'A focused operations room where live movement glows against a quiet midnight grid.',
    rationaleAr:
        'غرفة عمليات مركزة تبرز فيها حركة الأسطول فوق شبكة ليلية هادئة.',
    adjectives: ['focused', 'technical', 'live', 'precise', 'confident'],
    canvas: Color(0xFF061821),
    surface: Color(0xFF0B2630),
    surfaceStrong: Color(0xFF103541),
    ink: Color(0xFFEAF7F4),
    muted: Color(0xFF8FAEB2),
    border: Color(0xFF214953),
    primary: Color(0xFF35D0C3),
    secondary: Color(0xFF71A7FF),
    signal: Color(0xFFFFB45C),
    danger: Color(0xFFF06772),
    success: Color(0xFF52D68B),
    mapLand: Color(0xFF0A202A),
    mapRoad: Color(0xFF173843),
    radiusSmall: 3,
    radiusLarge: 10,
    navigationWidth: 76,
    dark: true,
    motion: AppMotionTokens(
      fast: Duration(milliseconds: 140),
      standard: Duration(milliseconds: 200),
      emphasized: Duration(milliseconds: 280),
    ),
  );

  static const fieldLedger = LabConceptPreset(
    id: LabConcept.fieldLedger,
    nameEn: 'Field Ledger',
    nameAr: 'سجل الميدان',
    rationaleEn:
        'An editorial dispatch ledger that makes dense operational facts calm, scannable, and accountable.',
    rationaleAr:
        'سجل ترحيل تحريري يجعل تفاصيل التشغيل الكثيفة هادئة وسريعة القراءة وقابلة للتتبع.',
    adjectives: ['editorial', 'orderly', 'tactile', 'transparent', 'durable'],
    canvas: Color(0xFFF0EEE6),
    surface: Color(0xFFFBFAF5),
    surfaceStrong: Color(0xFFE7E4D9),
    ink: Color(0xFF1E2C27),
    muted: Color(0xFF657069),
    border: Color(0xFFC8C7BC),
    primary: Color(0xFF245B49),
    secondary: Color(0xFF476B87),
    signal: Color(0xFFC39A3C),
    danger: Color(0xFFB64A36),
    success: Color(0xFF397650),
    mapLand: Color(0xFFE4E2D7),
    mapRoad: Color(0xFFFAF8F0),
    radiusSmall: 0,
    radiusLarge: 4,
    navigationWidth: 216,
    dark: false,
    motion: AppMotionTokens(
      fast: Duration(milliseconds: 120),
      standard: Duration(milliseconds: 180),
      emphasized: Duration(milliseconds: 260),
    ),
  );

  static const all = [routeBeacon, nightDispatch, fieldLedger];

  static LabConceptPreset of(LabConcept concept) => switch (concept) {
    LabConcept.routeBeacon => routeBeacon,
    LabConcept.nightDispatch => nightDispatch,
    LabConcept.fieldLedger => fieldLedger,
  };
}

@immutable
class LabTruck {
  const LabTruck({
    required this.code,
    required this.plate,
    required this.status,
    required this.driver,
    required this.speed,
    required this.online,
    required this.x,
    required this.y,
  });

  final String code;
  final String plate;
  final String status;
  final String driver;
  final int speed;
  final bool online;
  final double x;
  final double y;
}

const labTrucks = [
  LabTruck(
    code: 'TRK-204',
    plate: 'ر س م ٤٨٢١',
    status: 'في الطريق',
    driver: 'سائق ٠١',
    speed: 72,
    online: true,
    x: .23,
    y: .36,
  ),
  LabTruck(
    code: 'TRK-118',
    plate: 'ن ق ل ٧٣١٠',
    status: 'عند الاستلام',
    driver: 'سائق ٠٢',
    speed: 0,
    online: true,
    x: .52,
    y: .62,
  ),
  LabTruck(
    code: 'TRK-071',
    plate: 'ط ر ق ٢٢٠٥',
    status: 'متاحة',
    driver: 'سائق ٠٣',
    speed: 0,
    online: true,
    x: .74,
    y: .28,
  ),
  LabTruck(
    code: 'TRK-330',
    plate: 'ل و ج ٩١٦٢',
    status: 'بحاجة لانتباه',
    driver: 'سائق ٠٤',
    speed: 0,
    online: false,
    x: .67,
    y: .76,
  ),
];
