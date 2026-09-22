using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace TransportManagement.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class Sprint34TripOperations : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<decimal>(
                name: "Price",
                table: "trips",
                type: "numeric(18,2)",
                precision: 18,
                scale: 2,
                nullable: true,
                oldClrType: typeof(decimal),
                oldType: "numeric(18,2)",
                oldPrecision: 18,
                oldScale: 2);

            migrationBuilder.AlterColumn<DateTimeOffset>(
                name: "PlannedStartAt",
                table: "trips",
                type: "timestamp with time zone",
                nullable: true,
                oldClrType: typeof(DateTimeOffset),
                oldType: "timestamp with time zone");

            migrationBuilder.AlterColumn<string>(
                name: "Origin",
                table: "trips",
                type: "character varying(300)",
                maxLength: 300,
                nullable: true,
                oldClrType: typeof(string),
                oldType: "character varying(300)",
                oldMaxLength: 300);

            migrationBuilder.AlterColumn<string>(
                name: "Destination",
                table: "trips",
                type: "character varying(300)",
                maxLength: 300,
                nullable: true,
                oldClrType: typeof(string),
                oldType: "character varying(300)",
                oldMaxLength: 300);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "ArchivedAt",
                table: "trips",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "ArchivedByUserId",
                table: "trips",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "CancellationReason",
                table: "trips",
                type: "character varying(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "CancelledAt",
                table: "trips",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "CancelledByUserId",
                table: "trips",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "TripNumber",
                table: "trips",
                type: "character varying(20)",
                maxLength: 20,
                nullable: true);

            migrationBuilder.AddColumn<long>(
                name: "Version",
                table: "trips",
                type: "bigint",
                nullable: false,
                defaultValue: 1L);

            migrationBuilder.CreateTable(
                name: "trip_events",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    CompanyId = table.Column<Guid>(type: "uuid", nullable: false),
                    TripId = table.Column<Guid>(type: "uuid", nullable: false),
                    EventType = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: false),
                    OccurredAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    ActorUserId = table.Column<Guid>(type: "uuid", nullable: true),
                    Source = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    Metadata = table.Column<string>(type: "jsonb", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_trip_events", x => x.Id);
                    table.ForeignKey(
                        name: "FK_trip_events_companies_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "companies",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_trip_events_trips_TripId",
                        column: x => x.TripId,
                        principalTable: "trips",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_trip_events_users_ActorUserId",
                        column: x => x.ActorUserId,
                        principalTable: "users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "trip_number_counters",
                columns: table => new
                {
                    CompanyId = table.Column<Guid>(type: "uuid", nullable: false),
                    Year = table.Column<int>(type: "integer", nullable: false),
                    LastValue = table.Column<long>(type: "bigint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_trip_number_counters", x => new { x.CompanyId, x.Year });
                    table.ForeignKey(
                        name: "FK_trip_number_counters_companies_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "companies",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.Sql("""
                WITH ranked AS (
                    SELECT "Id", "CompanyId",
                           EXTRACT(YEAR FROM "CreatedAt" AT TIME ZONE 'UTC')::integer AS trip_year,
                           ROW_NUMBER() OVER (
                               PARTITION BY "CompanyId", EXTRACT(YEAR FROM "CreatedAt" AT TIME ZONE 'UTC')
                               ORDER BY "CreatedAt", "Id") AS sequence_value
                    FROM trips
                )
                UPDATE trips AS trip
                SET "TripNumber" = 'TRP-' || ranked.trip_year::text || '-' ||
                    LPAD(ranked.sequence_value::text, 6, '0'),
                    "Version" = 1
                FROM ranked
                WHERE trip."Id" = ranked."Id";

                INSERT INTO trip_number_counters ("CompanyId", "Year", "LastValue")
                SELECT "CompanyId",
                       EXTRACT(YEAR FROM "CreatedAt" AT TIME ZONE 'UTC')::integer,
                       COUNT(*)::bigint
                FROM trips
                GROUP BY "CompanyId", EXTRACT(YEAR FROM "CreatedAt" AT TIME ZONE 'UTC');

                INSERT INTO trip_events
                    ("Id", "CompanyId", "TripId", "EventType", "OccurredAt",
                     "ActorUserId", "Source", "Metadata", "CreatedAt", "UpdatedAt")
                SELECT md5("Id"::text || ':Sprint34ImportedBaseline')::uuid,
                       "CompanyId", "Id", 'ImportedBaseline', "CreatedAt", NULL,
                       'Migration', jsonb_build_object('knownStatus', "Status"),
                       NOW(), NOW()
                FROM trips;
                """);

            migrationBuilder.AlterColumn<string>(
                name: "TripNumber",
                table: "trips",
                type: "character varying(20)",
                maxLength: 20,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(20)",
                oldMaxLength: 20,
                oldNullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_trips_CompanyId_TripNumber",
                table: "trips",
                columns: new[] { "CompanyId", "TripNumber" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_trip_events_ActorUserId",
                table: "trip_events",
                column: "ActorUserId");

            migrationBuilder.CreateIndex(
                name: "IX_trip_events_CompanyId_TripId_OccurredAt",
                table: "trip_events",
                columns: new[] { "CompanyId", "TripId", "OccurredAt" });

            migrationBuilder.CreateIndex(
                name: "IX_trip_events_TripId",
                table: "trip_events",
                column: "TripId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "trip_events");

            migrationBuilder.DropTable(
                name: "trip_number_counters");

            migrationBuilder.DropIndex(
                name: "IX_trips_CompanyId_TripNumber",
                table: "trips");

            migrationBuilder.DropColumn(
                name: "ArchivedAt",
                table: "trips");

            migrationBuilder.DropColumn(
                name: "ArchivedByUserId",
                table: "trips");

            migrationBuilder.DropColumn(
                name: "CancellationReason",
                table: "trips");

            migrationBuilder.DropColumn(
                name: "CancelledAt",
                table: "trips");

            migrationBuilder.DropColumn(
                name: "CancelledByUserId",
                table: "trips");

            migrationBuilder.DropColumn(
                name: "TripNumber",
                table: "trips");

            migrationBuilder.DropColumn(
                name: "Version",
                table: "trips");

            migrationBuilder.AlterColumn<decimal>(
                name: "Price",
                table: "trips",
                type: "numeric(18,2)",
                precision: 18,
                scale: 2,
                nullable: false,
                defaultValue: 0m,
                oldClrType: typeof(decimal),
                oldType: "numeric(18,2)",
                oldPrecision: 18,
                oldScale: 2,
                oldNullable: true);

            migrationBuilder.AlterColumn<DateTimeOffset>(
                name: "PlannedStartAt",
                table: "trips",
                type: "timestamp with time zone",
                nullable: false,
                defaultValue: new DateTimeOffset(new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)),
                oldClrType: typeof(DateTimeOffset),
                oldType: "timestamp with time zone",
                oldNullable: true);

            migrationBuilder.AlterColumn<string>(
                name: "Origin",
                table: "trips",
                type: "character varying(300)",
                maxLength: 300,
                nullable: false,
                defaultValue: "",
                oldClrType: typeof(string),
                oldType: "character varying(300)",
                oldMaxLength: 300,
                oldNullable: true);

            migrationBuilder.AlterColumn<string>(
                name: "Destination",
                table: "trips",
                type: "character varying(300)",
                maxLength: 300,
                nullable: false,
                defaultValue: "",
                oldClrType: typeof(string),
                oldType: "character varying(300)",
                oldMaxLength: 300,
                oldNullable: true);
        }
    }
}
