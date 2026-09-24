using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace TransportManagement.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class Sprint4CustomerFleetOperations : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "DefaultDriverId",
                table: "trucks",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "FleetCode",
                table: "trucks",
                type: "character varying(50)",
                maxLength: 50,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "FuelType",
                table: "trucks",
                type: "character varying(30)",
                maxLength: 30,
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "OdometerKilometers",
                table: "trucks",
                type: "numeric(14,1)",
                precision: 14,
                scale: 1,
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "PayloadCapacity",
                table: "trucks",
                type: "numeric(12,2)",
                precision: 12,
                scale: 2,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "PayloadUnit",
                table: "trucks",
                type: "character varying(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "Kilograms");

            migrationBuilder.AddColumn<string>(
                name: "Type",
                table: "trucks",
                type: "character varying(30)",
                maxLength: 30,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Vin",
                table: "trucks",
                type: "character varying(50)",
                maxLength: 50,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "LegalName",
                table: "clients",
                type: "character varying(200)",
                maxLength: 200,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "LifecycleStatus",
                table: "clients",
                type: "character varying(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "Active");

            migrationBuilder.Sql("""
                UPDATE clients
                SET "LifecycleStatus" = CASE WHEN "IsActive" THEN 'Active' ELSE 'Archived' END;
                UPDATE trucks SET "Status" = 'Available' WHERE "Status" = 'OnTrip';
                """);

            migrationBuilder.DropColumn(
                name: "IsActive",
                table: "trucks");

            migrationBuilder.DropColumn(
                name: "IsActive",
                table: "clients");

            migrationBuilder.CreateTable(
                name: "client_contacts",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    CompanyId = table.Column<Guid>(type: "uuid", nullable: false),
                    ClientId = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    JobTitle = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: true),
                    Phone = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    WhatsApp = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    Email = table.Column<string>(type: "character varying(320)", maxLength: 320, nullable: true),
                    IsPrimary = table.Column<bool>(type: "boolean", nullable: false),
                    Notes = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_client_contacts", x => x.Id);
                    table.ForeignKey(
                        name: "FK_client_contacts_clients_ClientId",
                        column: x => x.ClientId,
                        principalTable: "clients",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_client_contacts_companies_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "companies",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "client_events",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    CompanyId = table.Column<Guid>(type: "uuid", nullable: false),
                    ClientId = table.Column<Guid>(type: "uuid", nullable: false),
                    ActorUserId = table.Column<Guid>(type: "uuid", nullable: true),
                    EventCode = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: false),
                    Metadata = table.Column<string>(type: "jsonb", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_client_events", x => x.Id);
                    table.ForeignKey(
                        name: "FK_client_events_clients_ClientId",
                        column: x => x.ClientId,
                        principalTable: "clients",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_client_events_companies_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "companies",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_client_events_users_ActorUserId",
                        column: x => x.ActorUserId,
                        principalTable: "users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "client_sites",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    CompanyId = table.Column<Guid>(type: "uuid", nullable: false),
                    ClientId = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    Type = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false),
                    Address = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    Latitude = table.Column<decimal>(type: "numeric(9,6)", precision: 9, scale: 6, nullable: false),
                    Longitude = table.Column<decimal>(type: "numeric(9,6)", precision: 9, scale: 6, nullable: false),
                    ContactName = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    ContactPhone = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    Instructions = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_client_sites", x => x.Id);
                    table.ForeignKey(
                        name: "FK_client_sites_clients_ClientId",
                        column: x => x.ClientId,
                        principalTable: "clients",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_client_sites_companies_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "companies",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "truck_events",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    CompanyId = table.Column<Guid>(type: "uuid", nullable: false),
                    TruckId = table.Column<Guid>(type: "uuid", nullable: false),
                    ActorUserId = table.Column<Guid>(type: "uuid", nullable: true),
                    EventCode = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: false),
                    Metadata = table.Column<string>(type: "jsonb", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_truck_events", x => x.Id);
                    table.ForeignKey(
                        name: "FK_truck_events_companies_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "companies",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_truck_events_trucks_TruckId",
                        column: x => x.TruckId,
                        principalTable: "trucks",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_truck_events_users_ActorUserId",
                        column: x => x.ActorUserId,
                        principalTable: "users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_trucks_CompanyId_FleetCode",
                table: "trucks",
                columns: new[] { "CompanyId", "FleetCode" },
                unique: true,
                filter: "\"FleetCode\" IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_trucks_CompanyId_Vin",
                table: "trucks",
                columns: new[] { "CompanyId", "Vin" },
                unique: true,
                filter: "\"Vin\" IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_trucks_DefaultDriverId",
                table: "trucks",
                column: "DefaultDriverId");

            migrationBuilder.CreateIndex(
                name: "IX_client_contacts_ClientId",
                table: "client_contacts",
                column: "ClientId");

            migrationBuilder.CreateIndex(
                name: "IX_client_contacts_CompanyId_ClientId",
                table: "client_contacts",
                columns: new[] { "CompanyId", "ClientId" });

            migrationBuilder.CreateIndex(
                name: "IX_client_contacts_CompanyId_ClientId_IsPrimary",
                table: "client_contacts",
                columns: new[] { "CompanyId", "ClientId", "IsPrimary" },
                unique: true,
                filter: "\"IsPrimary\" = TRUE");

            migrationBuilder.CreateIndex(
                name: "IX_client_events_ActorUserId",
                table: "client_events",
                column: "ActorUserId");

            migrationBuilder.CreateIndex(
                name: "IX_client_events_ClientId",
                table: "client_events",
                column: "ClientId");

            migrationBuilder.CreateIndex(
                name: "IX_client_events_CompanyId_ClientId_CreatedAt",
                table: "client_events",
                columns: new[] { "CompanyId", "ClientId", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_client_sites_ClientId",
                table: "client_sites",
                column: "ClientId");

            migrationBuilder.CreateIndex(
                name: "IX_client_sites_CompanyId_ClientId_IsActive",
                table: "client_sites",
                columns: new[] { "CompanyId", "ClientId", "IsActive" });

            migrationBuilder.CreateIndex(
                name: "IX_truck_events_ActorUserId",
                table: "truck_events",
                column: "ActorUserId");

            migrationBuilder.CreateIndex(
                name: "IX_truck_events_CompanyId_TruckId_CreatedAt",
                table: "truck_events",
                columns: new[] { "CompanyId", "TruckId", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_truck_events_TruckId",
                table: "truck_events",
                column: "TruckId");

            migrationBuilder.AddForeignKey(
                name: "FK_trucks_drivers_DefaultDriverId",
                table: "trucks",
                column: "DefaultDriverId",
                principalTable: "drivers",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_trucks_drivers_DefaultDriverId",
                table: "trucks");

            migrationBuilder.DropTable(
                name: "client_contacts");

            migrationBuilder.DropTable(
                name: "client_events");

            migrationBuilder.DropTable(
                name: "client_sites");

            migrationBuilder.DropTable(
                name: "truck_events");

            migrationBuilder.DropIndex(
                name: "IX_trucks_CompanyId_FleetCode",
                table: "trucks");

            migrationBuilder.DropIndex(
                name: "IX_trucks_CompanyId_Vin",
                table: "trucks");

            migrationBuilder.DropIndex(
                name: "IX_trucks_DefaultDriverId",
                table: "trucks");

            migrationBuilder.AddColumn<bool>(
                name: "IsActive",
                table: "trucks",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "IsActive",
                table: "clients",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.Sql("""
                UPDATE clients SET "IsActive" = "LifecycleStatus" = 'Active';
                UPDATE trucks SET "IsActive" = "Status" <> 'Archived';
                UPDATE trucks SET "Status" = 'Available' WHERE "Status" = 'Archived';
                """);

            migrationBuilder.DropColumn(
                name: "DefaultDriverId",
                table: "trucks");

            migrationBuilder.DropColumn(
                name: "FleetCode",
                table: "trucks");

            migrationBuilder.DropColumn(
                name: "FuelType",
                table: "trucks");

            migrationBuilder.DropColumn(
                name: "OdometerKilometers",
                table: "trucks");

            migrationBuilder.DropColumn(
                name: "PayloadCapacity",
                table: "trucks");

            migrationBuilder.DropColumn(
                name: "PayloadUnit",
                table: "trucks");

            migrationBuilder.DropColumn(
                name: "Type",
                table: "trucks");

            migrationBuilder.DropColumn(
                name: "Vin",
                table: "trucks");

            migrationBuilder.DropColumn(
                name: "LegalName",
                table: "clients");

            migrationBuilder.DropColumn(
                name: "LifecycleStatus",
                table: "clients");

        }
    }
}
