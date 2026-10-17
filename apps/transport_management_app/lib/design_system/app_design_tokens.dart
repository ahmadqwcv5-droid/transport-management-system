import 'package:flutter/material.dart';

@immutable
class AppDesignTokens extends ThemeExtension<AppDesignTokens> {
  const AppDesignTokens({
    required this.canvas,
    required this.surfaceRaised,
    required this.border,
    required this.textMuted,
    required this.success,
    required this.warning,
    required this.danger,
    required this.information,
    required this.selected,
    required this.disabled,
    required this.online,
    required this.offline,
    required this.stale,
    required this.moving,
    required this.stationary,
    required this.maintenance,
    required this.tripPlanned,
    required this.tripActive,
    required this.tripCompleted,
    required this.tripCancelled,
    required this.mapRoute,
    required this.mapTrail,
    required this.space1,
    required this.space2,
    required this.space3,
    required this.space4,
    required this.space5,
    required this.space6,
    required this.radiusSmall,
    required this.radiusMedium,
    required this.radiusLarge,
    required this.elevationLow,
    required this.elevationMedium,
    required this.controlHeight,
    required this.minimumTouchTarget,
    required this.compactBreakpoint,
    required this.expandedBreakpoint,
    required this.maximumContentWidth,
  });

  factory AppDesignTokens.commandCenter() => const AppDesignTokens(
    canvas: Color(0xFFF4F7FA),
    surfaceRaised: Color(0xFFFFFFFF),
    border: Color(0xFFD8E1EA),
    textMuted: Color(0xFF52606D),
    success: Color(0xFF16794A),
    warning: Color(0xFF9A6700),
    danger: Color(0xFFB42318),
    information: Color(0xFF175CD3),
    selected: Color(0xFFDCEBFF),
    disabled: Color(0xFF98A2B3),
    online: Color(0xFF16875B),
    offline: Color(0xFF667085),
    stale: Color(0xFFB54708),
    moving: Color(0xFF0B70C9),
    stationary: Color(0xFF475467),
    maintenance: Color(0xFF7A5AF8),
    tripPlanned: Color(0xFF2E90FA),
    tripActive: Color(0xFF12B76A),
    tripCompleted: Color(0xFF027A48),
    tripCancelled: Color(0xFFD92D20),
    mapRoute: Color(0xFF175CD3),
    mapTrail: Color(0xFF12B76A),
    space1: 4,
    space2: 8,
    space3: 12,
    space4: 16,
    space5: 24,
    space6: 32,
    radiusSmall: 8,
    radiusMedium: 12,
    radiusLarge: 18,
    elevationLow: 1,
    elevationMedium: 4,
    controlHeight: 48,
    minimumTouchTarget: 48,
    compactBreakpoint: 600,
    expandedBreakpoint: 1024,
    maximumContentWidth: 1440,
  );

  final Color canvas;
  final Color surfaceRaised;
  final Color border;
  final Color textMuted;
  final Color success;
  final Color warning;
  final Color danger;
  final Color information;
  final Color selected;
  final Color disabled;
  final Color online;
  final Color offline;
  final Color stale;
  final Color moving;
  final Color stationary;
  final Color maintenance;
  final Color tripPlanned;
  final Color tripActive;
  final Color tripCompleted;
  final Color tripCancelled;
  final Color mapRoute;
  final Color mapTrail;
  final double space1;
  final double space2;
  final double space3;
  final double space4;
  final double space5;
  final double space6;
  final double radiusSmall;
  final double radiusMedium;
  final double radiusLarge;
  final double elevationLow;
  final double elevationMedium;
  final double controlHeight;
  final double minimumTouchTarget;
  final double compactBreakpoint;
  final double expandedBreakpoint;
  final double maximumContentWidth;

  @override
  AppDesignTokens copyWith({
    Color? canvas,
    Color? surfaceRaised,
    Color? border,
    Color? textMuted,
    Color? success,
    Color? warning,
    Color? danger,
    Color? information,
    Color? selected,
    Color? disabled,
    Color? online,
    Color? offline,
    Color? stale,
    Color? moving,
    Color? stationary,
    Color? maintenance,
    Color? tripPlanned,
    Color? tripActive,
    Color? tripCompleted,
    Color? tripCancelled,
    Color? mapRoute,
    Color? mapTrail,
    double? space1,
    double? space2,
    double? space3,
    double? space4,
    double? space5,
    double? space6,
    double? radiusSmall,
    double? radiusMedium,
    double? radiusLarge,
    double? elevationLow,
    double? elevationMedium,
    double? controlHeight,
    double? minimumTouchTarget,
    double? compactBreakpoint,
    double? expandedBreakpoint,
    double? maximumContentWidth,
  }) => AppDesignTokens(
    canvas: canvas ?? this.canvas,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    border: border ?? this.border,
    textMuted: textMuted ?? this.textMuted,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
    information: information ?? this.information,
    selected: selected ?? this.selected,
    disabled: disabled ?? this.disabled,
    online: online ?? this.online,
    offline: offline ?? this.offline,
    stale: stale ?? this.stale,
    moving: moving ?? this.moving,
    stationary: stationary ?? this.stationary,
    maintenance: maintenance ?? this.maintenance,
    tripPlanned: tripPlanned ?? this.tripPlanned,
    tripActive: tripActive ?? this.tripActive,
    tripCompleted: tripCompleted ?? this.tripCompleted,
    tripCancelled: tripCancelled ?? this.tripCancelled,
    mapRoute: mapRoute ?? this.mapRoute,
    mapTrail: mapTrail ?? this.mapTrail,
    space1: space1 ?? this.space1,
    space2: space2 ?? this.space2,
    space3: space3 ?? this.space3,
    space4: space4 ?? this.space4,
    space5: space5 ?? this.space5,
    space6: space6 ?? this.space6,
    radiusSmall: radiusSmall ?? this.radiusSmall,
    radiusMedium: radiusMedium ?? this.radiusMedium,
    radiusLarge: radiusLarge ?? this.radiusLarge,
    elevationLow: elevationLow ?? this.elevationLow,
    elevationMedium: elevationMedium ?? this.elevationMedium,
    controlHeight: controlHeight ?? this.controlHeight,
    minimumTouchTarget: minimumTouchTarget ?? this.minimumTouchTarget,
    compactBreakpoint: compactBreakpoint ?? this.compactBreakpoint,
    expandedBreakpoint: expandedBreakpoint ?? this.expandedBreakpoint,
    maximumContentWidth: maximumContentWidth ?? this.maximumContentWidth,
  );

  @override
  AppDesignTokens lerp(covariant AppDesignTokens? other, double t) {
    if (other == null) return this;
    Color color(Color a, Color b) => Color.lerp(a, b, t)!;
    double number(double a, double b) => a + (b - a) * t;
    return AppDesignTokens(
      canvas: color(canvas, other.canvas),
      surfaceRaised: color(surfaceRaised, other.surfaceRaised),
      border: color(border, other.border),
      textMuted: color(textMuted, other.textMuted),
      success: color(success, other.success),
      warning: color(warning, other.warning),
      danger: color(danger, other.danger),
      information: color(information, other.information),
      selected: color(selected, other.selected),
      disabled: color(disabled, other.disabled),
      online: color(online, other.online),
      offline: color(offline, other.offline),
      stale: color(stale, other.stale),
      moving: color(moving, other.moving),
      stationary: color(stationary, other.stationary),
      maintenance: color(maintenance, other.maintenance),
      tripPlanned: color(tripPlanned, other.tripPlanned),
      tripActive: color(tripActive, other.tripActive),
      tripCompleted: color(tripCompleted, other.tripCompleted),
      tripCancelled: color(tripCancelled, other.tripCancelled),
      mapRoute: color(mapRoute, other.mapRoute),
      mapTrail: color(mapTrail, other.mapTrail),
      space1: number(space1, other.space1),
      space2: number(space2, other.space2),
      space3: number(space3, other.space3),
      space4: number(space4, other.space4),
      space5: number(space5, other.space5),
      space6: number(space6, other.space6),
      radiusSmall: number(radiusSmall, other.radiusSmall),
      radiusMedium: number(radiusMedium, other.radiusMedium),
      radiusLarge: number(radiusLarge, other.radiusLarge),
      elevationLow: number(elevationLow, other.elevationLow),
      elevationMedium: number(elevationMedium, other.elevationMedium),
      controlHeight: number(controlHeight, other.controlHeight),
      minimumTouchTarget: number(minimumTouchTarget, other.minimumTouchTarget),
      compactBreakpoint: number(compactBreakpoint, other.compactBreakpoint),
      expandedBreakpoint: number(expandedBreakpoint, other.expandedBreakpoint),
      maximumContentWidth: number(
        maximumContentWidth,
        other.maximumContentWidth,
      ),
    );
  }
}

extension AppDesignContext on BuildContext {
  AppDesignTokens get tokens =>
      Theme.of(this).extension<AppDesignTokens>() ??
      AppDesignTokens.commandCenter();
}
