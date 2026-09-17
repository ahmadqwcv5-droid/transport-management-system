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

final class Trip {
  const Trip({
    required this.id,
    required this.clientId,
    required this.origin,
    required this.destination,
    required this.cargoDescription,
    required this.plannedStartAt,
    required this.price,
    required this.status,
    required this.allowedActions,
    this.truckId,
    this.driverId,
    this.actualStartAt,
    this.deliveredAt,
    this.completedAt,
    this.notes,
  });
  final String id,
      clientId,
      origin,
      destination,
      cargoDescription,
      plannedStartAt,
      status;
  final String? truckId,
      driverId,
      actualStartAt,
      deliveredAt,
      completedAt,
      notes;
  final num price;
  final List<String> allowedActions;
  factory Trip.fromJson(Json json) => Trip(
    id: json['id'] as String,
    clientId: json['clientId'] as String,
    truckId: json['truckId'] as String?,
    driverId: json['driverId'] as String?,
    origin: json['origin'] as String,
    destination: json['destination'] as String,
    cargoDescription: json['cargoDescription'] as String,
    plannedStartAt: json['plannedStartAt'] as String,
    actualStartAt: json['actualStartAt'] as String?,
    deliveredAt: json['deliveredAt'] as String?,
    completedAt: json['completedAt'] as String?,
    price: json['price'] as num,
    notes: json['notes'] as String?,
    status: json['status'] as String,
    allowedActions: (json['allowedActions'] as List<dynamic>).cast<String>(),
  );
}

final class OperationsData {
  const OperationsData({
    required this.clients,
    required this.trucks,
    required this.drivers,
    required this.trips,
  });
  final List<Client> clients;
  final List<Truck> trucks;
  final List<Driver> drivers;
  final List<Trip> trips;
}
