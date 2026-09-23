typedef Json = Map<String, dynamic>;

final class Client {
  const Client({
    required this.id,
    required this.name,
    required this.isActive,
    this.contactPerson,
    this.phone,
    this.email,
    this.address,
    this.notes,
  });
  final String id;
  final String name;
  final bool isActive;
  final String? contactPerson, phone, email, address, notes;

  factory Client.fromJson(Json json) => Client(
    id: json['id'] as String,
    name: json['name'] as String,
    isActive: json['isActive'] as bool,
    contactPerson: json['contactPerson'] as String?,
    phone: json['phone'] as String?,
    email: json['email'] as String?,
    address: json['address'] as String?,
    notes: json['notes'] as String?,
  );
}
