final class CurrentUser {
  const CurrentUser({
    required this.id,
    required this.companyId,
    required this.email,
    required this.displayName,
    required this.role,
    required this.preferredLocale,
  });

  final String id;
  final String companyId;
  final String email;
  final String displayName;
  final String role;
  final String preferredLocale;

  factory CurrentUser.fromJson(Map<String, dynamic> json) => CurrentUser(
    id: json['id'] as String,
    companyId: json['companyId'] as String,
    email: json['email'] as String,
    displayName: json['displayName'] as String,
    role: json['role'] as String,
    preferredLocale: json['preferredLocale'] as String? ?? 'en',
  );
}

final class AuthSession {
  const AuthSession({required this.user});
  final CurrentUser user;
}
