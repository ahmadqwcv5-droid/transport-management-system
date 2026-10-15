namespace TransportManagement.Domain.Trips;

/// Canonical contract for every notification type that current application
/// services may emit. Adding a new type requires matching .NET/Flutter fixture
/// coverage and localized presentation before it can be persisted.
public static class OperationNotificationTypes
{
    public static IReadOnlySet<string> All { get; } = new HashSet<string>(
        StringComparer.Ordinal)
    {
        "TripAssignedToDriver",
        "TruckArrivedAtPickup",
        "TruckArrivedAtDelivery",
        "DriverConfirmedDeparture",
        "DriverConfirmedDelivery",
        "TruckBecameOffline",
        "TruckPositionBecameStale",
        "CompanyInvitationCreated",
        "CompanyInvitationAccepted",
        "CompanyInvitationDeclined",
        "CompanyInvitationRevoked",
        "CompanyInvitationExpired",
        "CompanyConnectionRequested",
        "CompanyConnectionApproved",
        "CompanyConnectionRejected",
        "CompanyConnectionCancelled",
        "MembershipActive",
        "MembershipReactivated",
        "MembershipSuspended",
        "MembershipRevoked",
        "MembershipRolesUpdated",
        "DriverLinked",
        "DriverUnlinked",
        "TruckQrGenerated",
        "TruckQrRegenerated",
        "TruckSessionStarted",
        "TruckSessionEnded",
        "TruckSessionSwitched",
        "TruckDefaultDriverChanged",
        "DriverHandoverRequested",
        "DriverHandoverPending",
        "DriverHandoverApproved",
        "DriverHandoverRejected",
        "ExternalLoginLinked",
        "ExternalLoginUnlinked",
        "PasswordChanged"
    };
}
