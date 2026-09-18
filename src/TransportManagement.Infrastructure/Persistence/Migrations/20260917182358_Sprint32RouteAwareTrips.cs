using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace TransportManagement.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class Sprint32RouteAwareTrips : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "trip_route_plans",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    CompanyId = table.Column<Guid>(type: "uuid", nullable: false),
                    TripId = table.Column<Guid>(type: "uuid", nullable: false),
                    Geometry = table.Column<string>(type: "jsonb", nullable: false),
                    GeometryFormat = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    GeometryVersion = table.Column<int>(type: "integer", nullable: false),
                    DistanceMeters = table.Column<decimal>(type: "numeric(14,2)", precision: 14, scale: 2, nullable: false),
                    EstimatedDurationSeconds = table.Column<int>(type: "integer", nullable: false),
                    ProviderName = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    RouteProfile = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    CalculatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    StopsFingerprint = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    ProviderRouteId = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: true),
                    Warnings = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_trip_route_plans", x => x.Id);
                    table.ForeignKey(
                        name: "FK_trip_route_plans_companies_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "companies",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_trip_route_plans_trips_TripId",
                        column: x => x.TripId,
                        principalTable: "trips",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "trip_stops",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    CompanyId = table.Column<Guid>(type: "uuid", nullable: false),
                    TripId = table.Column<Guid>(type: "uuid", nullable: false),
                    Sequence = table.Column<int>(type: "integer", nullable: false),
                    Type = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false),
                    Name = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: false),
                    Address = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    Latitude = table.Column<decimal>(type: "numeric(9,6)", precision: 9, scale: 6, nullable: true),
                    Longitude = table.Column<decimal>(type: "numeric(9,6)", precision: 9, scale: 6, nullable: true),
                    PlannedArrivalAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    PlannedServiceDurationMinutes = table.Column<int>(type: "integer", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_trip_stops", x => x.Id);
                    table.ForeignKey(
                        name: "FK_trip_stops_companies_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "companies",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_trip_stops_trips_TripId",
                        column: x => x.TripId,
                        principalTable: "trips",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            // Preserve legacy labels without inventing geographic coordinates.
            // Drafts can be upgraded through the route planner; existing trips
            // in later states remain readable with RequiresLocationSelection.
            migrationBuilder.Sql(
                """
                INSERT INTO trip_stops
                    ("Id", "CompanyId", "TripId", "Sequence", "Type", "Name",
                     "Address", "Latitude", "Longitude", "PlannedArrivalAt",
                     "PlannedServiceDurationMinutes", "CreatedAt", "UpdatedAt")
                SELECT md5("Id"::text || ':pickup')::uuid, "CompanyId", "Id", 0,
                       'Pickup', "Origin", NULL, NULL, NULL, NULL, NULL,
                       "CreatedAt", "UpdatedAt"
                FROM trips;

                INSERT INTO trip_stops
                    ("Id", "CompanyId", "TripId", "Sequence", "Type", "Name",
                     "Address", "Latitude", "Longitude", "PlannedArrivalAt",
                     "PlannedServiceDurationMinutes", "CreatedAt", "UpdatedAt")
                SELECT md5("Id"::text || ':delivery')::uuid, "CompanyId", "Id", 1,
                       'Delivery', "Destination", NULL, NULL, NULL, NULL, NULL,
                       "CreatedAt", "UpdatedAt"
                FROM trips;
                """);

            migrationBuilder.CreateIndex(
                name: "IX_trip_route_plans_CompanyId",
                table: "trip_route_plans",
                column: "CompanyId");

            migrationBuilder.CreateIndex(
                name: "IX_trip_route_plans_TripId",
                table: "trip_route_plans",
                column: "TripId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_trip_stops_CompanyId",
                table: "trip_stops",
                column: "CompanyId");

            migrationBuilder.CreateIndex(
                name: "IX_trip_stops_CompanyId_TripId_Sequence",
                table: "trip_stops",
                columns: new[] { "CompanyId", "TripId", "Sequence" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_trip_stops_TripId",
                table: "trip_stops",
                column: "TripId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "trip_route_plans");

            migrationBuilder.DropTable(
                name: "trip_stops");
        }
    }
}
