final class CurrentUser {
  const CurrentUser({
    required this.id,
    this.membershipId,
    this.companyId,
    this.companyName = '',
    required this.email,
    required this.displayName,
    required this.role,
    this.roles = const [],
    required this.preferredLocale,
    this.notificationSoundsEnabled = true,
    this.environmentName = 'Production',
    this.hasLocalPassword = true,
    this.requiresWorkspaceSelection = false,
    this.driverId,
    this.driverName,
  });

  final String id;
  final String? membershipId;
  final String? companyId;
  final String companyName;
  final String email;
  final String displayName;
  final String role;
  final List<String> roles;
  final String preferredLocale;
  final bool notificationSoundsEnabled;
  final String environmentName;
  final bool hasLocalPassword;
  final bool requiresWorkspaceSelection;
  final String? driverId;
  final String? driverName;

  String get operationalDisplayName =>
      hasRole('Driver') && driverName?.isNotEmpty == true
      ? driverName!
      : displayName;

  bool hasRole(String value) => roles.contains(value) || role == value;

  factory CurrentUser.fromJson(Map<String, dynamic> json) => CurrentUser(
    id: json['id'] as String,
    membershipId: json['membershipId'] as String?,
    companyId: json['companyId'] as String?,
    companyName: json['companyName'] as String? ?? '',
    email: json['email'] as String,
    displayName: json['displayName'] as String,
    role: json['role'] as String? ?? '',
    roles:
        (json['roles'] as List<dynamic>?)?.whereType<String>().toList() ??
        const [],
    preferredLocale: json['preferredLocale'] as String? ?? 'en',
    notificationSoundsEnabled:
        json['notificationSoundsEnabled'] as bool? ?? true,
    environmentName: json['environmentName'] as String? ?? 'Production',
    hasLocalPassword: json['hasLocalPassword'] as bool? ?? true,
    requiresWorkspaceSelection:
        json['requiresWorkspaceSelection'] as bool? ?? false,
    driverId: json['driverId'] as String?,
    driverName: json['driverName'] as String?,
  );
}

final class AuthSession {
  const AuthSession({required this.user});
  final CurrentUser user;
}

final class Workspace {
  const Workspace({
    required this.membershipId,
    required this.companyId,
    required this.companyName,
    required this.roles,
    required this.status,
  });

  final String membershipId, companyId, companyName, status;
  final List<String> roles;

  factory Workspace.fromJson(Map<String, dynamic> json) => Workspace(
    membershipId: json['membershipId'] as String,
    companyId: json['companyId'] as String,
    companyName: json['companyName'] as String,
    roles: (json['roles'] as List<dynamic>).whereType<String>().toList(),
    status: json['status'] as String,
  );
}
