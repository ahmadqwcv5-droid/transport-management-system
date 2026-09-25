typedef Json = Map<String, dynamic>;

final class CompanyUser {
  const CompanyUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.isActive,
    required this.notificationSoundsEnabled,
    this.driverId,
    this.driverName,
  });

  final String id, email, displayName, role;
  final bool isActive, notificationSoundsEnabled;
  final String? driverId, driverName;

  factory CompanyUser.fromJson(Json json) => CompanyUser(
    id: json['id'] as String,
    email: json['email'] as String,
    displayName: json['displayName'] as String,
    role: json['role'] as String,
    isActive: json['isActive'] as bool,
    notificationSoundsEnabled:
        json['notificationSoundsEnabled'] as bool? ?? true,
    driverId: json['driverId'] as String?,
    driverName: json['driverName'] as String?,
  );
}

final class TemporaryCredential {
  const TemporaryCredential({required this.user, required this.password});
  final CompanyUser user;
  final String password;

  factory TemporaryCredential.fromJson(Json json) => TemporaryCredential(
    user: CompanyUser.fromJson(json['user'] as Json),
    password: json['temporaryPassword'] as String,
  );
}
