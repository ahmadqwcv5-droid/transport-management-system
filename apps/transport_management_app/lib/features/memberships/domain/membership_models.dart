typedef Json = Map<String, dynamic>;

final class Invitation {
  const Invitation({
    required this.id,
    required this.email,
    required this.roles,
    required this.status,
    required this.expiresAt,
    this.driverId,
    this.driverName,
    this.acceptancePath,
  });

  final String id, email, status;
  final List<String> roles;
  final DateTime expiresAt;
  final String? driverId, driverName, acceptancePath;

  factory Invitation.fromJson(Json json) => Invitation(
    id: json['id'] as String,
    email: json['email'] as String,
    roles: (json['roles'] as List<dynamic>).whereType<String>().toList(),
    status: json['status'] as String,
    expiresAt: DateTime.parse(json['expiresAt'] as String),
    driverId: json['driverId'] as String?,
    driverName: json['driverName'] as String?,
    acceptancePath: json['acceptancePath'] as String?,
  );
}

final class ConnectionRequest {
  const ConnectionRequest({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.accountId,
    required this.accountEmail,
    required this.accountName,
    required this.requestedRoles,
    required this.status,
    required this.createdAt,
    this.driverId,
    this.resolutionReason,
    this.resolvedAt,
  });

  final String id, companyId, companyName, accountId, accountEmail;
  final String accountName, status;
  final List<String> requestedRoles;
  final DateTime createdAt;
  final String? driverId, resolutionReason;
  final DateTime? resolvedAt;

  factory ConnectionRequest.fromJson(Json json) => ConnectionRequest(
    id: json['id'] as String,
    companyId: json['companyId'] as String,
    companyName: json['companyName'] as String,
    accountId: json['accountId'] as String,
    accountEmail: json['accountEmail'] as String,
    accountName: json['accountName'] as String,
    requestedRoles: (json['requestedRoles'] as List<dynamic>)
        .whereType<String>()
        .toList(),
    status: json['status'] as String,
    driverId: json['driverId'] as String?,
    resolutionReason: json['resolutionReason'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    resolvedAt: json['resolvedAt'] == null
        ? null
        : DateTime.parse(json['resolvedAt'] as String),
  );
}

final class CompanyCode {
  const CompanyCode({
    required this.code,
    required this.hint,
    required this.version,
  });
  final String code, hint;
  final int version;
  factory CompanyCode.fromJson(Json json) => CompanyCode(
    code: json['code'] as String,
    hint: json['hint'] as String,
    version: json['version'] as int,
  );
}

final class CompanySummary {
  const CompanySummary({required this.companyName, required this.codeHint});
  final String companyName, codeHint;
  factory CompanySummary.fromJson(Json json) => CompanySummary(
    companyName: json['companyName'] as String,
    codeHint: json['codeHint'] as String,
  );
}

final class TruckQrCredential {
  const TruckQrCredential({
    required this.truckId,
    required this.plateNumber,
    required this.code,
    required this.codeHint,
    required this.qrPayload,
    required this.generatedAt,
    this.fleetCode,
  });
  final String truckId, plateNumber, code, codeHint, qrPayload;
  final String? fleetCode;
  final DateTime generatedAt;
  factory TruckQrCredential.fromJson(Json json) => TruckQrCredential(
    truckId: json['truckId'] as String,
    plateNumber: json['plateNumber'] as String,
    fleetCode: json['fleetCode'] as String?,
    code: json['code'] as String,
    codeHint: json['codeHint'] as String,
    qrPayload: json['qrPayload'] as String,
    generatedAt: DateTime.parse(json['generatedAt'] as String),
  );
}

final class TruckQrPreview {
  const TruckQrPreview({
    required this.truckId,
    required this.plateNumber,
    required this.truckStatus,
    required this.requiresHandover,
    this.fleetCode,
    this.photoThumbnailUrl,
    this.currentDriverId,
    this.currentDriverName,
    this.tripId,
    this.tripNumber,
    this.tripStatus,
    this.positionRecordedAt,
  });
  final String truckId, plateNumber, truckStatus;
  final bool requiresHandover;
  final String? fleetCode, photoThumbnailUrl, currentDriverId;
  final String? currentDriverName, tripId, tripNumber, tripStatus;
  final DateTime? positionRecordedAt;
  factory TruckQrPreview.fromJson(Json json) => TruckQrPreview(
    truckId: json['truckId'] as String,
    plateNumber: json['plateNumber'] as String,
    truckStatus: json['truckStatus'] as String,
    requiresHandover: json['requiresHandover'] as bool,
    fleetCode: json['fleetCode'] as String?,
    photoThumbnailUrl: json['photoThumbnailUrl'] as String?,
    currentDriverId: json['currentDriverId'] as String?,
    currentDriverName: json['currentDriverName'] as String?,
    tripId: json['tripId'] as String?,
    tripNumber: json['tripNumber'] as String?,
    tripStatus: json['tripStatus'] as String?,
    positionRecordedAt: json['positionRecordedAt'] == null
        ? null
        : DateTime.parse(json['positionRecordedAt'] as String),
  );
}

final class TruckSwitchResult {
  const TruckSwitchResult({
    required this.state,
    required this.truckId,
    required this.driverId,
    this.sessionId,
    this.handoverRequestId,
    this.tripId,
  });
  final String state, truckId, driverId;
  final String? sessionId, handoverRequestId, tripId;
  factory TruckSwitchResult.fromJson(Json json) => TruckSwitchResult(
    state: json['state'] as String,
    truckId: json['truckId'] as String,
    driverId: json['driverId'] as String,
    sessionId: json['sessionId'] as String?,
    handoverRequestId: json['handoverRequestId'] as String?,
    tripId: json['tripId'] as String?,
  );
}

final class Handover {
  const Handover({
    required this.id,
    required this.tripId,
    required this.tripNumber,
    required this.truckId,
    required this.plateNumber,
    required this.currentDriverName,
    required this.requestingDriverName,
    required this.tripStatus,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.reason,
    this.resolutionReason,
    this.resolvedAt,
  });
  final String id, tripId, tripNumber, truckId, plateNumber;
  final String currentDriverName, requestingDriverName, tripStatus, status;
  final String? reason, resolutionReason;
  final DateTime createdAt, expiresAt;
  final DateTime? resolvedAt;
  factory Handover.fromJson(Json json) => Handover(
    id: json['id'] as String,
    tripId: json['tripId'] as String,
    tripNumber: json['tripNumber'] as String,
    truckId: json['truckId'] as String,
    plateNumber: json['plateNumber'] as String,
    currentDriverName: json['currentDriverName'] as String,
    requestingDriverName: json['requestingDriverName'] as String,
    tripStatus: json['tripStatus'] as String,
    status: json['status'] as String,
    reason: json['reason'] as String?,
    resolutionReason: json['resolutionReason'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    expiresAt: DateTime.parse(json['expiresAt'] as String),
    resolvedAt: json['resolvedAt'] == null
        ? null
        : DateTime.parse(json['resolvedAt'] as String),
  );
}

final class SignInMethod {
  const SignInMethod({
    required this.provider,
    required this.label,
    required this.canUnlink,
    this.email,
  });

  final String provider, label;
  final bool canUnlink;
  final String? email;

  factory SignInMethod.fromJson(Json json) => SignInMethod(
    provider: json['provider'] as String,
    label: json['label'] as String,
    email: json['email'] as String?,
    canUnlink: json['canUnlink'] as bool,
  );
}
