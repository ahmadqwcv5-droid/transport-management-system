using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace TransportManagement.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class Sprint412DriverOperationsTracking : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "driver_truck_sessions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    CompanyId = table.Column<Guid>(type: "uuid", nullable: false),
                    DriverId = table.Column<Guid>(type: "uuid", nullable: false),
                    TruckId = table.Column<Guid>(type: "uuid", nullable: false),
                    StartedFromTripId = table.Column<Guid>(type: "uuid", nullable: false),
                    LastTripId = table.Column<Guid>(type: "uuid", nullable: false),
                    StartedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    EndedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    EndReason = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    Version = table.Column<long>(type: "bigint", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_driver_truck_sessions", x => x.Id);
                    table.ForeignKey(
                        name: "FK_driver_truck_sessions_companies_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "companies",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_driver_truck_sessions_drivers_DriverId",
                        column: x => x.DriverId,
                        principalTable: "drivers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_driver_truck_sessions_trips_LastTripId",
                        column: x => x.LastTripId,
                        principalTable: "trips",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_driver_truck_sessions_trips_StartedFromTripId",
                        column: x => x.StartedFromTripId,
                        principalTable: "trips",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_driver_truck_sessions_trucks_TruckId",
                        column: x => x.TruckId,
                        principalTable: "trucks",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_driver_truck_sessions_CompanyId_DriverId",
                table: "driver_truck_sessions",
                columns: new[] { "CompanyId", "DriverId" },
                unique: true,
                filter: "\"EndedAt\" IS NULL");

            migrationBuilder.CreateIndex(
                name: "IX_driver_truck_sessions_CompanyId_TruckId",
                table: "driver_truck_sessions",
                columns: new[] { "CompanyId", "TruckId" },
                unique: true,
                filter: "\"EndedAt\" IS NULL");

            migrationBuilder.CreateIndex(
                name: "IX_driver_truck_sessions_DriverId",
                table: "driver_truck_sessions",
                column: "DriverId");

            migrationBuilder.CreateIndex(
                name: "IX_driver_truck_sessions_LastTripId",
                table: "driver_truck_sessions",
                column: "LastTripId");

            migrationBuilder.CreateIndex(
                name: "IX_driver_truck_sessions_StartedFromTripId",
                table: "driver_truck_sessions",
                column: "StartedFromTripId");

            migrationBuilder.CreateIndex(
                name: "IX_driver_truck_sessions_TruckId",
                table: "driver_truck_sessions",
                column: "TruckId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "driver_truck_sessions");
        }
    }
}
