using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace TransportManagement.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class Sprint33DispatchToPickup : Migration
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

            migrationBuilder.AddColumn<string>(
                name: "MovementPhase",
                table: "truck_positions",
                type: "character varying(30)",
                maxLength: 30,
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "RepositioningPlanId",
                table: "truck_positions",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "ArrivedPickupAt",
                table: "trips",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "trip_repositioning_plans",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    CompanyId = table.Column<Guid>(type: "uuid", nullable: false),
                    TripId = table.Column<Guid>(type: "uuid", nullable: false),
                    TruckId = table.Column<Guid>(type: "uuid", nullable: false),
                    OriginLatitude = table.Column<decimal>(type: "numeric(9,6)", precision: 9, scale: 6, nullable: false),
                    OriginLongitude = table.Column<decimal>(type: "numeric(9,6)", precision: 9, scale: 6, nullable: false),
                    DestinationLatitude = table.Column<decimal>(type: "numeric(9,6)", precision: 9, scale: 6, nullable: false),
                    DestinationLongitude = table.Column<decimal>(type: "numeric(9,6)", precision: 9, scale: 6, nullable: false),
                    SourceTruckPositionId = table.Column<Guid>(type: "uuid", nullable: true),
                    SourcePositionAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    Geometry = table.Column<string>(type: "jsonb", nullable: false),
                    GeometryFormat = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    GeometryVersion = table.Column<int>(type: "integer", nullable: false),
                    DistanceMeters = table.Column<decimal>(type: "numeric(14,2)", precision: 14, scale: 2, nullable: false),
                    EstimatedDurationSeconds = table.Column<int>(type: "integer", nullable: false),
                    ProviderName = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    RouteProfile = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    CalculatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    ProviderRouteId = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: true),
                    Status = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false),
                    DispatchedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    ArrivedPickupAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_trip_repositioning_plans", x => x.Id);
                    table.ForeignKey(
                        name: "FK_trip_repositioning_plans_companies_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "companies",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_trip_repositioning_plans_trips_TripId",
                        column: x => x.TripId,
                        principalTable: "trips",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_trip_repositioning_plans_truck_positions_SourceTruckPositio~",
                        column: x => x.SourceTruckPositionId,
                        principalTable: "truck_positions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_trip_repositioning_plans_trucks_TruckId",
                        column: x => x.TruckId,
                        principalTable: "trucks",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_truck_positions_RepositioningPlanId",
                table: "truck_positions",
                column: "RepositioningPlanId");

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

            migrationBuilder.CreateIndex(
                name: "IX_trip_repositioning_plans_CompanyId",
                table: "trip_repositioning_plans",
                column: "CompanyId");

            migrationBuilder.CreateIndex(
                name: "IX_trip_repositioning_plans_CompanyId_TripId_Status",
                table: "trip_repositioning_plans",
                columns: new[] { "CompanyId", "TripId", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_trip_repositioning_plans_CompanyId_TruckId_Status",
                table: "trip_repositioning_plans",
                columns: new[] { "CompanyId", "TruckId", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_trip_repositioning_plans_SourceTruckPositionId",
                table: "trip_repositioning_plans",
                column: "SourceTruckPositionId");

            migrationBuilder.CreateIndex(
                name: "IX_trip_repositioning_plans_TripId",
                table: "trip_repositioning_plans",
                column: "TripId");

            migrationBuilder.CreateIndex(
                name: "IX_trip_repositioning_plans_TruckId",
                table: "trip_repositioning_plans",
                column: "TruckId");

            migrationBuilder.AddForeignKey(
                name: "FK_truck_positions_trip_repositioning_plans_RepositioningPlanId",
                table: "truck_positions",
                column: "RepositioningPlanId",
                principalTable: "trip_repositioning_plans",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_truck_positions_trip_repositioning_plans_RepositioningPlanId",
                table: "truck_positions");

            migrationBuilder.DropTable(
                name: "trip_repositioning_plans");

            migrationBuilder.DropIndex(
                name: "IX_truck_positions_RepositioningPlanId",
                table: "truck_positions");

            migrationBuilder.DropIndex(
                name: "IX_trips_CompanyId_DriverId",
                table: "trips");

            migrationBuilder.DropIndex(
                name: "IX_trips_CompanyId_TruckId",
                table: "trips");

            migrationBuilder.DropColumn(
                name: "MovementPhase",
                table: "truck_positions");

            migrationBuilder.DropColumn(
                name: "RepositioningPlanId",
                table: "truck_positions");

            migrationBuilder.DropColumn(
                name: "ArrivedPickupAt",
                table: "trips");

            migrationBuilder.CreateIndex(
                name: "IX_trips_CompanyId_DriverId",
                table: "trips",
                columns: new[] { "CompanyId", "DriverId" },
                unique: true,
                filter: "\"DriverId\" IS NOT NULL AND \"Status\" IN ('Assigned', 'Started', 'InTransit', 'Delivered')");

            migrationBuilder.CreateIndex(
                name: "IX_trips_CompanyId_TruckId",
                table: "trips",
                columns: new[] { "CompanyId", "TruckId" },
                unique: true,
                filter: "\"TruckId\" IS NOT NULL AND \"Status\" IN ('Assigned', 'Started', 'InTransit', 'Delivered')");
        }
    }
}
