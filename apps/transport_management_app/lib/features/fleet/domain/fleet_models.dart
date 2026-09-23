typedef Json = Map<String, dynamic>;

final class Truck {
  const Truck({
    required this.id,
    required this.plateNumber,
    required this.status,
    required this.isActive,
    this.make,
    this.model,
    this.year,
    this.notes,
  });
  final String id;
  final String plateNumber, status;
  final bool isActive;
  final String? make, model, notes;
  final int? year;

  factory Truck.fromJson(Json json) => Truck(
    id: json['id'] as String,
    plateNumber: json['plateNumber'] as String,
    status: json['status'] as String,
    isActive: json['isActive'] as bool,
    make: json['make'] as String?,
    model: json['model'] as String?,
    year: json['year'] as int?,
    notes: json['notes'] as String?,
  );
}

final class Driver {
  const Driver({
    required this.id,
    required this.fullName,
    required this.licenseNumber,
    required this.status,
    required this.isActive,
    this.phone,
    this.licenseExpiryDate,
    this.notes,
  });
  final String id;
  final String fullName, licenseNumber, status;
  final bool isActive;
  final String? phone, licenseExpiryDate, notes;

  factory Driver.fromJson(Json json) => Driver(
    id: json['id'] as String,
    fullName: json['fullName'] as String,
    licenseNumber: json['licenseNumber'] as String,
    status: json['status'] as String,
    isActive: json['isActive'] as bool,
    phone: json['phone'] as String?,
    licenseExpiryDate: json['licenseExpiryDate'] as String?,
    notes: json['notes'] as String?,
  );
}
