using System.ComponentModel.DataAnnotations;
using TransportManagement.Application.Clients;
using TransportManagement.Domain.Fleet;

namespace TransportManagement.Application.Fleet;

public sealed record TruckRequest(
    [param: Required, MaxLength(30)] string PlateNumber,
    [param: MaxLength(100)] string? Make,
    [param: MaxLength(100)] string? Model,
    [param: Range(1900, 2100)] int? Year,
    [param: MaxLength(2000)] string? Notes,
    [param: MaxLength(50)] string? FleetCode = null,
    [param: MaxLength(50)] string? Vin = null,
    TruckType? Type = null,
    [param: Range(0, 1000000)] decimal? PayloadCapacity = null,
    PayloadUnit PayloadUnit = PayloadUnit.Kilograms,
    TruckFuelType? FuelType = null,
    [param: Range(0, 100000000)] decimal? OdometerKilometers = null,
    Guid? DefaultDriverId = null);

public sealed record TruckStatusRequest(TruckStatus Status);
public sealed record OdometerCorrectionRequest(
    [param: Range(0, 100000000)] decimal Kilometers,
    [param: Required, MaxLength(500)] string Reason);

public sealed record TruckResponse(
    Guid Id,
    string PlateNumber,
    string? Make,
    string? Model,
    int? Year,
    TruckStatus Status,
    string? Notes,
    bool IsActive,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt,
    string? FleetCode = null,
    string? Vin = null,
    TruckType? Type = null,
    decimal? PayloadCapacity = null,
    PayloadUnit PayloadUnit = PayloadUnit.Kilograms,
    TruckFuelType? FuelType = null,
    decimal? OdometerKilometers = null,
    Guid? DefaultDriverId = null,
    string? DefaultDriverName = null,
    TruckStatus BaseStatus = TruckStatus.Available,
    string OperationalState = "Available",
    Guid? CurrentTripId = null,
    string? CurrentTripNumber = null,
    Guid? CurrentDriverId = null,
    bool CanBeAssigned = true,
    string IneligibilityReasonCode = "AVAILABLE");

public sealed record LatestTruckPositionResponse(
    decimal Latitude, decimal Longitude, decimal Speed, decimal Heading,
    DateTimeOffset RecordedAt, bool IsOnline, string LocationState);

public sealed record TruckDetailsResponse(
    TruckResponse Truck, LatestTruckPositionResponse? LatestPosition,
    IReadOnlyList<ResourceTripSummaryResponse> Trips,
    IReadOnlyList<OperationsEventResponse> Events);
