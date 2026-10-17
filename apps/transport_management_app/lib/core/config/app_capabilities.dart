enum AppProductProfile { development, demo, pilot, production }

class AppCapabilitySet {
  const AppCapabilitySet({
    required this.profile,
    required this.simulatorUi,
    required this.diagnosticEvidence,
    required this.requiresRealTracking,
  });

  factory AppCapabilitySet.resolve(
    String value, {
    bool simulatorRequested = false,
  }) {
    final profile = AppProductProfile.values.firstWhere(
      (item) => item.name == value.trim().toLowerCase(),
      orElse: () => AppProductProfile.production,
    );
    final restricted =
        profile == AppProductProfile.pilot ||
        profile == AppProductProfile.production;
    return AppCapabilitySet(
      profile: profile,
      simulatorUi: !restricted && simulatorRequested,
      diagnosticEvidence: profile == AppProductProfile.development,
      requiresRealTracking: restricted,
    );
  }

  final AppProductProfile profile;
  final bool simulatorUi;
  final bool diagnosticEvidence;
  final bool requiresRealTracking;
}

abstract final class AppCapabilities {
  static const profile = String.fromEnvironment(
    'APP_PROFILE',
    defaultValue: 'development',
  );

  static const simulatorRequested = bool.fromEnvironment(
    'ENABLE_SIMULATOR_CONTROLS',
    defaultValue: false,
  );

  static const simulatorUi =
      profile != 'pilot' && profile != 'production' && simulatorRequested;
  static const diagnosticEvidence = profile == 'development';
  static const requiresRealTracking =
      profile == 'pilot' || profile == 'production';
}
