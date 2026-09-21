using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace TransportManagement.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class Sprint322TripAwareTracking : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "RoutePlanId",
                table: "truck_positions",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "TrackingRunId",
                table: "truck_positions",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "TripId",
                table: "truck_positions",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_truck_positions_CompanyId_TripId_RecordedAt",
                table: "truck_positions",
                columns: new[] { "CompanyId", "TripId", "RecordedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_truck_positions_RoutePlanId",
                table: "truck_positions",
                column: "RoutePlanId");

            migrationBuilder.CreateIndex(
                name: "IX_truck_positions_TripId",
                table: "truck_positions",
                column: "TripId");

            migrationBuilder.AddForeignKey(
                name: "FK_truck_positions_trip_route_plans_RoutePlanId",
                table: "truck_positions",
                column: "RoutePlanId",
                principalTable: "trip_route_plans",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_truck_positions_trips_TripId",
                table: "truck_positions",
                column: "TripId",
                principalTable: "trips",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_truck_positions_trip_route_plans_RoutePlanId",
                table: "truck_positions");

            migrationBuilder.DropForeignKey(
                name: "FK_truck_positions_trips_TripId",
                table: "truck_positions");

            migrationBuilder.DropIndex(
                name: "IX_truck_positions_CompanyId_TripId_RecordedAt",
                table: "truck_positions");

            migrationBuilder.DropIndex(
                name: "IX_truck_positions_RoutePlanId",
                table: "truck_positions");

            migrationBuilder.DropIndex(
                name: "IX_truck_positions_TripId",
                table: "truck_positions");

            migrationBuilder.DropColumn(
                name: "RoutePlanId",
                table: "truck_positions");

            migrationBuilder.DropColumn(
                name: "TrackingRunId",
                table: "truck_positions");

            migrationBuilder.DropColumn(
                name: "TripId",
                table: "truck_positions");
        }
    }
}
