final class CurrentUser {
  const CurrentUser({
    required this.id,
    required this.companyId,
    this.companyName = '',
    required this.email,
    required this.displayName,
    required this.role,
    required this.preferredLocale,
    this.notificationSoundsEnabled = true,
    this.environmentName = 'Production',
    this.driverId,
    this.driverName,
  });

  final String id;
  final String companyId;
  final String companyName;
  final String email;
  final String displayName;
  final String role;
  final String preferredLocale;
  final bool notificationSoundsEnabled;
  final String environmentName;
  final String? driverId;
  final String? driverName;

  String get operationalDisplayName =>
      role == 'Driver' && driverName?.isNotEmpty == true
      ? driverName!
      : displayName;

  factory CurrentUser.fromJson(Map<String, dynamic> json) => CurrentUser(
    id: json['id'] as String,
    companyId: json['companyId'] as String,
    companyName: json['companyName'] as String? ?? '',
    email: json['email'] as String,
    displayName: json['displayName'] as String,
    role: json['role'] as String,
    preferredLocale: json['preferredLocale'] as String? ?? 'en',
    notificationSoundsEnabled:
        json['notificationSoundsEnabled'] as bool? ?? true,
    environmentName: json['environmentName'] as String? ?? 'Production',
    driverId: json['driverId'] as String?,
    driverName: json['driverName'] as String?,
  );
}

final class AuthSession {
  const AuthSession({required this.user});
  final CurrentUser user;
}
