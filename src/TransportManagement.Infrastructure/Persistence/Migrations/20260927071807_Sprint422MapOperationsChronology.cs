using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace TransportManagement.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class Sprint422MapOperationsChronology : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "company_map_preferences",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    CompanyId = table.Column<Guid>(type: "uuid", nullable: false),
                    CountryCode = table.Column<string>(type: "character varying(2)", maxLength: 2, nullable: false),
                    Label = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    South = table.Column<decimal>(type: "numeric(9,6)", precision: 9, scale: 6, nullable: false),
                    West = table.Column<decimal>(type: "numeric(9,6)", precision: 9, scale: 6, nullable: false),
                    North = table.Column<decimal>(type: "numeric(9,6)", precision: 9, scale: 6, nullable: false),
                    East = table.Column<decimal>(type: "numeric(9,6)", precision: 9, scale: 6, nullable: false),
                    CenterLatitude = table.Column<decimal>(type: "numeric(9,6)", precision: 9, scale: 6, nullable: true),
                    CenterLongitude = table.Column<decimal>(type: "numeric(9,6)", precision: 9, scale: 6, nullable: true),
                    PreferredZoom = table.Column<decimal>(type: "numeric(5,2)", precision: 5, scale: 2, nullable: true),
                    UpdatedByUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_company_map_preferences", x => x.Id);
                    table.ForeignKey(
                        name: "FK_company_map_preferences_companies_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "companies",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_company_map_preferences_users_UpdatedByUserId",
                        column: x => x.UpdatedByUserId,
                        principalTable: "users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "truck_current_positions",
                columns: table => new
                {
                    TruckId = table.Column<Guid>(type: "uuid", nullable: false),
                    CompanyId = table.Column<Guid>(type: "uuid", nullable: false),
                    PositionId = table.Column<Guid>(type: "uuid", nullable: false),
                    RecordedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    TrackingRunId = table.Column<Guid>(type: "uuid", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_truck_current_positions", x => x.TruckId);
                    table.ForeignKey(
                        name: "FK_truck_current_positions_companies_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "companies",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_truck_current_positions_truck_positions_PositionId",
                        column: x => x.PositionId,
                        principalTable: "truck_positions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_truck_current_positions_trucks_TruckId",
                        column: x => x.TruckId,
                        principalTable: "trucks",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_company_map_preferences_CompanyId",
                table: "company_map_preferences",
                column: "CompanyId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_company_map_preferences_UpdatedByUserId",
                table: "company_map_preferences",
                column: "UpdatedByUserId");

            migrationBuilder.CreateIndex(
                name: "IX_truck_current_positions_CompanyId",
                table: "truck_current_positions",
                column: "CompanyId");

            migrationBuilder.CreateIndex(
                name: "IX_truck_current_positions_PositionId",
                table: "truck_current_positions",
                column: "PositionId",
                unique: true);

            // History is immutable. Establish a current projection only from the
            // deterministic newest row (timestamp, then packet id) for each truck.
            migrationBuilder.Sql(
                """
                INSERT INTO truck_current_positions
                    ("TruckId", "CompanyId", "PositionId", "RecordedAt",
                     "TrackingRunId", "CreatedAt", "UpdatedAt")
                SELECT ranked."TruckId", ranked."CompanyId", ranked."Id",
                       ranked."RecordedAt", ranked."TrackingRunId",
                       ranked."RecordedAt", ranked."RecordedAt"
                FROM (
                    SELECT position.*,
                           ROW_NUMBER() OVER (
                               PARTITION BY position."CompanyId", position."TruckId"
                               ORDER BY position."RecordedAt" DESC, position."Id" DESC) AS rank
                    FROM truck_positions AS position
                ) AS ranked
                WHERE ranked.rank = 1;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "company_map_preferences");

            migrationBuilder.DropTable(
                name: "truck_current_positions");
        }
    }
}
