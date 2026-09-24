using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace TransportManagement.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class Sprint41LiveFleetDriverWorkflow : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_trips_CompanyId_DriverId",
                table: "trips");

            migrationBuilder.DropIndex(
                name: "IX_trips_CompanyId_TruckId",
                table: "trips");

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "ArrivedDeliveryAt",
                table: "trips",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "UserId",
                table: "drivers",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "operation_notifications",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    CompanyId = table.Column<Guid>(type: "uuid", nullable: false),
                    Type = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: false),
                    Severity = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    TripId = table.Column<Guid>(type: "uuid", nullable: true),
                    TruckId = table.Column<Guid>(type: "uuid", nullable: true),
                    DriverId = table.Column<Guid>(type: "uuid", nullable: true),
                    EventKey = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    DataJson = table.Column<string>(type: "jsonb", nullable: true),
                    ReadAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    ReadByUserId = table.Column<Guid>(type: "uuid", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_operation_notifications", x => x.Id);
                    table.ForeignKey(
                        name: "FK_operation_notifications_companies_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "companies",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_operation_notifications_drivers_DriverId",
                        column: x => x.DriverId,
                        principalTable: "drivers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_operation_notifications_trips_TripId",
                        column: x => x.TripId,
                        principalTable: "trips",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_operation_notifications_trucks_TruckId",
                        column: x => x.TruckId,
                        principalTable: "trucks",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_operation_notifications_users_ReadByUserId",
                        column: x => x.ReadByUserId,
                        principalTable: "users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "trip_geofence_observations",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    CompanyId = table.Column<Guid>(type: "uuid", nullable: false),
                    TripId = table.Column<Guid>(type: "uuid", nullable: false),
                    Stage = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    RouteIdentity = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    FirstQualifyingAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    LastSampleAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    ConsecutiveSamples = table.Column<int>(type: "integer", nullable: false),
                    IsInside = table.Column<bool>(type: "boolean", nullable: false),
                    ConfirmedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    Version = table.Column<long>(type: "bigint", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_trip_geofence_observations", x => x.Id);
                    table.ForeignKey(
                        name: "FK_trip_geofence_observations_companies_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "companies",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_trip_geofence_observations_trips_TripId",
                        column: x => x.TripId,
                        principalTable: "trips",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "truck_photos",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    CompanyId = table.Column<Guid>(type: "uuid", nullable: false),
                    TruckId = table.Column<Guid>(type: "uuid", nullable: false),
                    StorageKey = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    ContentType = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    OriginalByteSize = table.Column<long>(type: "bigint", nullable: false),
                    ThumbnailByteSize = table.Column<long>(type: "bigint", nullable: false),
                    Width = table.Column<int>(type: "integer", nullable: false),
                    Height = table.Column<int>(type: "integer", nullable: false),
                    Version = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    UploadedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UploadedByUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_truck_photos", x => x.Id);
                    table.ForeignKey(
                        name: "FK_truck_photos_companies_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "companies",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_truck_photos_trucks_TruckId",
                        column: x => x.TruckId,
                        principalTable: "trucks",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_truck_photos_users_UploadedByUserId",
                        column: x => x.UploadedByUserId,
                        principalTable: "users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_trips_CompanyId_DriverId",
                table: "trips",
                columns: new[] { "CompanyId", "DriverId" },
                unique: true,
                filter: "\"DriverId\" IS NOT NULL AND \"Status\" IN ('Assigned', 'EnRouteToPickup', 'AtPickup', 'Started', 'InTransit', 'AtDelivery', 'Delivered')");

            migrationBuilder.CreateIndex(
                name: "IX_trips_CompanyId_TruckId",
                table: "trips",
                columns: new[] { "CompanyId", "TruckId" },
                unique: true,
                filter: "\"TruckId\" IS NOT NULL AND \"Status\" IN ('Assigned', 'EnRouteToPickup', 'AtPickup', 'Started', 'InTransit', 'AtDelivery', 'Delivered')");

            migrationBuilder.CreateIndex(
                name: "IX_drivers_UserId",
                table: "drivers",
                column: "UserId",
                unique: true,
                filter: "\"UserId\" IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_operation_notifications_CompanyId_CreatedAt",
                table: "operation_notifications",
                columns: new[] { "CompanyId", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_operation_notifications_CompanyId_EventKey",
                table: "operation_notifications",
                columns: new[] { "CompanyId", "EventKey" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_operation_notifications_DriverId",
                table: "operation_notifications",
                column: "DriverId");

            migrationBuilder.CreateIndex(
                name: "IX_operation_notifications_ReadByUserId",
                table: "operation_notifications",
                column: "ReadByUserId");

            migrationBuilder.CreateIndex(
                name: "IX_operation_notifications_TripId",
                table: "operation_notifications",
                column: "TripId");

            migrationBuilder.CreateIndex(
                name: "IX_operation_notifications_TruckId",
                table: "operation_notifications",
                column: "TruckId");

            migrationBuilder.CreateIndex(
                name: "IX_trip_geofence_observations_CompanyId_TripId_Stage_RouteIden~",
                table: "trip_geofence_observations",
                columns: new[] { "CompanyId", "TripId", "Stage", "RouteIdentity" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_trip_geofence_observations_TripId",
                table: "trip_geofence_observations",
                column: "TripId");

            migrationBuilder.CreateIndex(
                name: "IX_truck_photos_CompanyId_TruckId",
                table: "truck_photos",
                columns: new[] { "CompanyId", "TruckId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_truck_photos_StorageKey",
                table: "truck_photos",
                column: "StorageKey",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_truck_photos_TruckId",
                table: "truck_photos",
                column: "TruckId");

            migrationBuilder.CreateIndex(
                name: "IX_truck_photos_UploadedByUserId",
                table: "truck_photos",
                column: "UploadedByUserId");

            migrationBuilder.AddForeignKey(
                name: "FK_drivers_users_UserId",
                table: "drivers",
                column: "UserId",
                principalTable: "users",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_drivers_users_UserId",
                table: "drivers");

            migrationBuilder.DropTable(
                name: "operation_notifications");

            migrationBuilder.DropTable(
                name: "trip_geofence_observations");

            migrationBuilder.DropTable(
                name: "truck_photos");

            migrationBuilder.DropIndex(
                name: "IX_trips_CompanyId_DriverId",
                table: "trips");

            migrationBuilder.DropIndex(
                name: "IX_trips_CompanyId_TruckId",
                table: "trips");

            migrationBuilder.DropIndex(
                name: "IX_drivers_UserId",
                table: "drivers");

            migrationBuilder.DropColumn(
                name: "ArrivedDeliveryAt",
                table: "trips");

            migrationBuilder.DropColumn(
                name: "UserId",
                table: "drivers");

            migrationBuilder.CreateIndex(
                name: "IX_trips_CompanyId_DriverId",
                table: "trips",
                columns: new[] { "CompanyId", "DriverId" },
                unique: true,
                filter: "\"DriverId\" IS NOT NULL AND \"Status\" IN ('Assigned', 'EnRouteToPickup', 'AtPickup', 'Started', 'InTransit', 'Delivered')");

            migrationBuilder.CreateIndex(
                name: "IX_trips_CompanyId_TruckId",
                table: "trips",
                columns: new[] { "CompanyId", "TruckId" },
                unique: true,
                filter: "\"TruckId\" IS NOT NULL AND \"Status\" IN ('Assigned', 'EnRouteToPickup', 'AtPickup', 'Started', 'InTransit', 'Delivered')");
        }
    }
}
