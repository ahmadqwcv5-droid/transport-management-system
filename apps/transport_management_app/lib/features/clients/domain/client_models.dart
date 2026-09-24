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
    this.legalName,
    this.lifecycleStatus = 'Active',
    this.activeSiteCount = 0,
    this.activeTripCount = 0,
  });
  final String id;
  final String name;
  final bool isActive;
  final String? contactPerson, phone, email, address, notes, legalName;
  final String lifecycleStatus;
  final int activeSiteCount, activeTripCount;

  factory Client.fromJson(Json json) => Client(
    id: json['id'] as String,
    name: json['name'] as String,
    isActive: json['isActive'] as bool,
    contactPerson: json['contactPerson'] as String?,
    phone: json['phone'] as String?,
    email: json['email'] as String?,
    address: json['address'] as String?,
    notes: json['notes'] as String?,
    legalName: json['legalName'] as String?,
    lifecycleStatus:
        json['lifecycleStatus'] as String? ??
        ((json['isActive'] as bool? ?? true) ? 'Active' : 'Archived'),
    activeSiteCount: json['activeSiteCount'] as int? ?? 0,
    activeTripCount: json['activeTripCount'] as int? ?? 0,
  );
}

final class ClientContact {
  const ClientContact({
    required this.id,
    required this.name,
    required this.isPrimary,
    this.jobTitle,
    this.phone,
    this.whatsApp,
    this.email,
    this.notes,
  });
  final String id, name;
  final bool isPrimary;
  final String? jobTitle, phone, whatsApp, email, notes;
  factory ClientContact.fromJson(Json json) => ClientContact(
    id: json['id'] as String,
    name: json['name'] as String,
    isPrimary: json['isPrimary'] as bool,
    jobTitle: json['jobTitle'] as String?,
    phone: json['phone'] as String?,
    whatsApp: json['whatsApp'] as String?,
    email: json['email'] as String?,
    notes: json['notes'] as String?,
  );
}

final class ClientSite {
  const ClientSite({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.isActive,
    this.address,
    this.contactName,
    this.contactPhone,
    this.instructions,
  });
  final String id, name, type;
  final double latitude, longitude;
  final bool isActive;
  final String? address, contactName, contactPhone, instructions;
  factory ClientSite.fromJson(Json json) => ClientSite(
    id: json['id'] as String,
    name: json['name'] as String,
    type: json['type'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    isActive: json['isActive'] as bool,
    address: json['address'] as String?,
    contactName: json['contactName'] as String?,
    contactPhone: json['contactPhone'] as String?,
    instructions: json['instructions'] as String?,
  );
}

final class OperationsEvent {
  const OperationsEvent({
    required this.id,
    required this.eventCode,
    required this.occurredAt,
    this.metadata,
  });
  final String id, eventCode, occurredAt;
  final String? metadata;
  factory OperationsEvent.fromJson(Json json) => OperationsEvent(
    id: json['id'] as String,
    eventCode: json['eventCode'] as String,
    occurredAt: json['occurredAt'] as String,
    metadata: json['metadata'] as String?,
  );
}

final class ResourceTripSummary {
  const ResourceTripSummary({
    required this.id,
    required this.tripNumber,
    required this.status,
    required this.plannedStartAt,
    this.origin,
    this.destination,
    this.truckId,
    this.truckPlate,
    this.driverId,
    this.driverName,
  });
  final String id, tripNumber, status, plannedStartAt;
  final String? origin, destination, truckId, truckPlate, driverId, driverName;
  factory ResourceTripSummary.fromJson(Json json) => ResourceTripSummary(
    id: json['id'] as String,
    tripNumber: json['tripNumber'] as String,
    status: json['status'] as String,
    plannedStartAt: json['plannedStartAt'] as String,
    origin: json['origin'] as String?,
    destination: json['destination'] as String?,
    truckId: json['truckId'] as String?,
    truckPlate: json['truckPlate'] as String?,
    driverId: json['driverId'] as String?,
    driverName: json['driverName'] as String?,
  );
}

final class ClientDetails {
  const ClientDetails({
    required this.client,
    required this.contacts,
    required this.sites,
    required this.trips,
    required this.events,
    required this.plannedTripCount,
    required this.activeTripCount,
    required this.completedTripCount,
    required this.cancelledTripCount,
  });
  final Client client;
  final List<ClientContact> contacts;
  final List<ClientSite> sites;
  final List<ResourceTripSummary> trips;
  final List<OperationsEvent> events;
  final int plannedTripCount,
      activeTripCount,
      completedTripCount,
      cancelledTripCount;
  factory ClientDetails.fromJson(Json json) => ClientDetails(
    client: Client.fromJson(json['client'] as Json),
    contacts: (json['contacts'] as List<dynamic>)
        .cast<Json>()
        .map(ClientContact.fromJson)
        .toList(),
    sites: (json['sites'] as List<dynamic>)
        .cast<Json>()
        .map(ClientSite.fromJson)
        .toList(),
    trips: (json['trips'] as List<dynamic>)
        .cast<Json>()
        .map(ResourceTripSummary.fromJson)
        .toList(),
    events: (json['events'] as List<dynamic>)
        .cast<Json>()
        .map(OperationsEvent.fromJson)
        .toList(),
    plannedTripCount: json['plannedTripCount'] as int,
    activeTripCount: json['activeTripCount'] as int,
    completedTripCount: json['completedTripCount'] as int,
    cancelledTripCount: json['cancelledTripCount'] as int,
  );
}
