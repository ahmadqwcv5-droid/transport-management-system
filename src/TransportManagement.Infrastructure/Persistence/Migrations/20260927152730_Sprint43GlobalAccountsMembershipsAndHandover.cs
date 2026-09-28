using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace TransportManagement.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class Sprint43GlobalAccountsMembershipsAndHandover : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
                CREATE TEMP TABLE "__sprint43_legacy_users" ON COMMIT DROP AS
                SELECT "Id", "CompanyId", "Role", "IsActive", "CreatedAt", "UpdatedAt"
                FROM "users";

                DO $$ BEGIN
                    IF EXISTS (SELECT 1 FROM "users" GROUP BY lower("Email") HAVING count(*) > 1)
                    THEN RAISE EXCEPTION 'Sprint 4.3 blocked: duplicate normalized account emails exist.';
                    END IF;
                END $$;
                """);
            migrationBuilder.DropForeignKey(
                name: "FK_refresh_tokens_users_UserId",
                table: "refresh_tokens");

            migrationBuilder.DropForeignKey(
                name: "FK_users_companies_CompanyId",
                table: "users");

            migrationBuilder.DropIndex(
                name: "IX_users_CompanyId",
                table: "users");

            migrationBuilder.DropIndex(
                name: "IX_drivers_UserId",
                table: "drivers");

            migrationBuilder.DropColumn(
                name: "CompanyId",
                table: "users");

            migrationBuilder.DropColumn(
                name: "Role",
                table: "users");

            migrationBuilder.RenameColumn(
                name: "UserId",
                table: "refresh_tokens",
                newName: "AccountId");

            migrationBuilder.RenameIndex(
                name: "IX_refresh_tokens_UserId_ExpiresAt",
                table: "refresh_tokens",
                newName: "IX_refresh_tokens_AccountId_ExpiresAt");

            migrationBuilder.AlterColumn<string>(
                name: "PasswordHash",
                table: "users",
                type: "character varying(200)",
                maxLength: 200,
                nullable: true,
                oldClrType: typeof(string),
                oldType: "character varying(200)",
                oldMaxLength: 200);

            migrationBuilder.AlterColumn<Guid>(
                name: "CompanyId",
                table: "refresh_tokens",
                type: "uuid",
                nullable: true,
                oldClrType: typeof(Guid),
                oldType: "uuid");

            migrationBuilder.AddColumn<Guid>(
                name: "MembershipId",
                table: "refresh_tokens",
                type: "uuid",
                nullable: true);

            migrationBuilder.AlterColumn<Guid>(
                name: "StartedFromTripId",
                table: "driver_truck_sessions",
                type: "uuid",
                nullable: true,
                oldClrType: typeof(Guid),
                oldType: "uuid");

            migrationBuilder.AlterColumn<Guid>(
                name: "LastTripId",
                table: "driver_truck_sessions",
                type: "uuid",
                nullable: true,
                oldClrType: typeof(Guid),
                oldType: "uuid");

            migrationBuilder.AddColumn<Guid>(
                name: "ApprovedByAccountId",
                table: "driver_truck_sessions",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "InitiatedByAccountId",
                table: "driver_truck_sessions",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Source",
                table: "driver_truck_sessions",
                type: "character varying(40)",
                maxLength: 40,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "ConnectionCodeHash",
                table: "companies",
                type: "character varying(64)",
                maxLength: 64,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ConnectionCodeHint",
                table: "companies",
                type: "character varying(12)",
                maxLength: 12,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "ConnectionCodeVersion",
                table: "companies",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.CreateTable(
                name: "company_connection_requests",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    CompanyId = table.Column<Guid>(type: "uuid", nullable: false),
                    AccountId = table.Column<Guid>(type: "uuid", nullable: false),
                    RequestedRolesJson = table.Column<string>(type: "jsonb", nullable: false),
                    Status = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    DriverId = table.Column<Guid>(type: "uuid", nullable: true),
                    ResolvedByAccountId = table.Column<Guid>(type: "uuid", nullable: true),
                    ResolvedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    ResolutionReason = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_company_connection_requests", x => x.Id);
                    table.ForeignKey(
                        name: "FK_company_connection_requests_companies_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "companies",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_company_connection_requests_drivers_DriverId",
                        column: x => x.DriverId,
                        principalTable: "drivers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_company_connection_requests_users_AccountId",
                        column: x => x.AccountId,
                        principalTable: "users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_company_connection_requests_users_ResolvedByAccountId",
                        column: x => x.ResolvedByAccountId,
                        principalTable: "users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "company_invitations",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    CompanyId = table.Column<Guid>(type: "uuid", nullable: false),
                    Email = table.Column<string>(type: "character varying(320)", maxLength: 320, nullable: false),
                    RolesJson = table.Column<string>(type: "jsonb", nullable: false),
                    DriverId = table.Column<Guid>(type: "uuid", nullable: true),
                    TokenHash = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    ExpiresAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    InviterAccountId = table.Column<Guid>(type: "uuid", nullable: false),
                    Status = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    AcceptedByAccountId = table.Column<Guid>(type: "uuid", nullable: true),
                    ResolvedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_company_invitations", x => x.Id);
                    table.ForeignKey(
                        name: "FK_company_invitations_companies_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "companies",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_company_invitations_drivers_DriverId",
                        column: x => x.DriverId,
                        principalTable: "drivers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_company_invitations_users_AcceptedByAccountId",
                        column: x => x.AcceptedByAccountId,
                        principalTable: "users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_company_invitations_users_InviterAccountId",
                        column: x => x.InviterAccountId,
                        principalTable: "users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "company_memberships",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    CompanyId = table.Column<Guid>(type: "uuid", nullable: false),
                    AccountId = table.Column<Guid>(type: "uuid", nullable: false),
                    Status = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    InvitedByAccountId = table.Column<Guid>(type: "uuid", nullable: true),
                    JoinedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    SuspendedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    RevokedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    LeftAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    Version = table.Column<long>(type: "bigint", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_company_memberships", x => x.Id);
                    table.ForeignKey(
                        name: "FK_company_memberships_companies_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "companies",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_company_memberships_users_AccountId",
                        column: x => x.AccountId,
                        principalTable: "users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_company_memberships_users_InvitedByAccountId",
                        column: x => x.InvitedByAccountId,
                        principalTable: "users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "external_logins",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    AccountId = table.Column<Guid>(type: "uuid", nullable: false),
                    Provider = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    ProviderSubject = table.Column<string>(type: "character varying(255)", maxLength: 255, nullable: false),
                    EmailSnapshot = table.Column<string>(type: "character varying(320)", maxLength: 320, nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_external_logins", x => x.Id);
                    table.ForeignKey(
                        name: "FK_external_logins_users_AccountId",
                        column: x => x.AccountId,
                        principalTable: "users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "identity_audit_events",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    CompanyId = table.Column<Guid>(type: "uuid", nullable: false),
                    AccountId = table.Column<Guid>(type: "uuid", nullable: true),
                    ActorAccountId = table.Column<Guid>(type: "uuid", nullable: true),
                    EventCode = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: false),
                    DataJson = table.Column<string>(type: "jsonb", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_identity_audit_events", x => x.Id);
                    table.ForeignKey(
                        name: "FK_identity_audit_events_companies_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "companies",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_identity_audit_events_users_AccountId",
                        column: x => x.AccountId,
                        principalTable: "users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_identity_audit_events_users_ActorAccountId",
                        column: x => x.ActorAccountId,
                        principalTable: "users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "trip_handover_requests",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    CompanyId = table.Column<Guid>(type: "uuid", nullable: false),
                    TripId = table.Column<Guid>(type: "uuid", nullable: false),
                    TruckId = table.Column<Guid>(type: "uuid", nullable: false),
                    CurrentDriverId = table.Column<Guid>(type: "uuid", nullable: false),
                    RequestingDriverId = table.Column<Guid>(type: "uuid", nullable: false),
                    ExpectedTripVersion = table.Column<long>(type: "bigint", nullable: false),
                    ExpiresAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    RequestedByAccountId = table.Column<Guid>(type: "uuid", nullable: false),
                    Reason = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    Status = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    ResolvedByAccountId = table.Column<Guid>(type: "uuid", nullable: true),
                    ResolutionReason = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    ResolvedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_trip_handover_requests", x => x.Id);
                    table.ForeignKey(
                        name: "FK_trip_handover_requests_companies_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "companies",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_trip_handover_requests_drivers_CurrentDriverId",
                        column: x => x.CurrentDriverId,
                        principalTable: "drivers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_trip_handover_requests_drivers_RequestingDriverId",
                        column: x => x.RequestingDriverId,
                        principalTable: "drivers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_trip_handover_requests_trips_TripId",
                        column: x => x.TripId,
                        principalTable: "trips",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_trip_handover_requests_trucks_TruckId",
                        column: x => x.TruckId,
                        principalTable: "trucks",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_trip_handover_requests_users_RequestedByAccountId",
                        column: x => x.RequestedByAccountId,
                        principalTable: "users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_trip_handover_requests_users_ResolvedByAccountId",
                        column: x => x.ResolvedByAccountId,
                        principalTable: "users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "truck_qr_credentials",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    CompanyId = table.Column<Guid>(type: "uuid", nullable: false),
                    TruckId = table.Column<Guid>(type: "uuid", nullable: false),
                    TokenHash = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    CodeHint = table.Column<string>(type: "character varying(12)", maxLength: 12, nullable: false),
                    GeneratedByAccountId = table.Column<Guid>(type: "uuid", nullable: false),
                    GeneratedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    RevokedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    RevokedByAccountId = table.Column<Guid>(type: "uuid", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_truck_qr_credentials", x => x.Id);
                    table.ForeignKey(
                        name: "FK_truck_qr_credentials_companies_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "companies",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_truck_qr_credentials_trucks_TruckId",
                        column: x => x.TruckId,
                        principalTable: "trucks",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_truck_qr_credentials_users_GeneratedByAccountId",
                        column: x => x.GeneratedByAccountId,
                        principalTable: "users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_truck_qr_credentials_users_RevokedByAccountId",
                        column: x => x.RevokedByAccountId,
                        principalTable: "users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "company_membership_roles",
                columns: table => new
                {
                    MembershipId = table.Column<Guid>(type: "uuid", nullable: false),
                    Role = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    CompanyId = table.Column<Guid>(type: "uuid", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_company_membership_roles", x => new { x.MembershipId, x.Role });
                    table.ForeignKey(
                        name: "FK_company_membership_roles_companies_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "companies",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_company_membership_roles_company_memberships_MembershipId",
                        column: x => x.MembershipId,
                        principalTable: "company_memberships",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "trip_driver_participations",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    CompanyId = table.Column<Guid>(type: "uuid", nullable: false),
                    TripId = table.Column<Guid>(type: "uuid", nullable: false),
                    DriverId = table.Column<Guid>(type: "uuid", nullable: false),
                    StartedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    EndedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    Source = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    StartedPhase = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false),
                    EndedPhase = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: true),
                    StartedPositionId = table.Column<Guid>(type: "uuid", nullable: true),
                    EndedPositionId = table.Column<Guid>(type: "uuid", nullable: true),
                    AssignedByAccountId = table.Column<Guid>(type: "uuid", nullable: true),
                    ApprovedByAccountId = table.Column<Guid>(type: "uuid", nullable: true),
                    HandoverRequestId = table.Column<Guid>(type: "uuid", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_trip_driver_participations", x => x.Id);
                    table.ForeignKey(
                        name: "FK_trip_driver_participations_companies_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "companies",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_trip_driver_participations_drivers_DriverId",
                        column: x => x.DriverId,
                        principalTable: "drivers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_trip_driver_participations_trip_handover_requests_HandoverR~",
                        column: x => x.HandoverRequestId,
                        principalTable: "trip_handover_requests",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_trip_driver_participations_trips_TripId",
                        column: x => x.TripId,
                        principalTable: "trips",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_trip_driver_participations_users_ApprovedByAccountId",
                        column: x => x.ApprovedByAccountId,
                        principalTable: "users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_trip_driver_participations_users_AssignedByAccountId",
                        column: x => x.AssignedByAccountId,
                        principalTable: "users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.Sql("""
                INSERT INTO "company_memberships"
                    ("Id", "CompanyId", "AccountId", "Status", "InvitedByAccountId",
                     "JoinedAt", "SuspendedAt", "RevokedAt", "LeftAt", "Version",
                     "CreatedAt", "UpdatedAt")
                SELECT "Id", "CompanyId", "Id",
                    CASE WHEN "IsActive" THEN 'Active' ELSE 'Suspended' END,
                    NULL,
                    CASE WHEN "IsActive" THEN "CreatedAt" ELSE NULL END,
                    CASE WHEN "IsActive" THEN NULL ELSE "UpdatedAt" END,
                    NULL, NULL, 1, "CreatedAt", "UpdatedAt"
                FROM "__sprint43_legacy_users";

                INSERT INTO "company_membership_roles" ("MembershipId", "Role", "CompanyId")
                SELECT "Id", "Role", "CompanyId"
                FROM "__sprint43_legacy_users";

                UPDATE "refresh_tokens" AS token
                SET "MembershipId" = legacy."Id"
                FROM "__sprint43_legacy_users" AS legacy
                WHERE token."AccountId" = legacy."Id"
                  AND token."CompanyId" = legacy."CompanyId";

                UPDATE "driver_truck_sessions"
                SET "Source" = 'TripAssignment'
                WHERE "Source" = '';

                INSERT INTO "trip_driver_participations"
                    ("Id", "CompanyId", "TripId", "DriverId", "StartedAt", "EndedAt",
                     "Source", "StartedPhase", "EndedPhase", "StartedPositionId",
                     "EndedPositionId", "AssignedByAccountId", "ApprovedByAccountId",
                     "HandoverRequestId", "CreatedAt", "UpdatedAt")
                SELECT trip."Id", trip."CompanyId", trip."Id", trip."DriverId",
                    trip."CreatedAt",
                    CASE WHEN trip."Status" IN ('Delivered', 'Completed', 'Cancelled')
                         THEN trip."UpdatedAt" ELSE NULL END,
                    'LegacyAssignment', 'Assigned',
                    CASE WHEN trip."Status" IN ('Delivered', 'Completed', 'Cancelled')
                         THEN trip."Status" ELSE NULL END,
                    NULL, NULL, NULL, NULL, NULL, trip."CreatedAt", trip."UpdatedAt"
                FROM "trips" AS trip
                WHERE trip."DriverId" IS NOT NULL;
                """);

            migrationBuilder.CreateIndex(
                name: "IX_refresh_tokens_MembershipId",
                table: "refresh_tokens",
                column: "MembershipId");

            migrationBuilder.CreateIndex(
                name: "IX_drivers_CompanyId_UserId",
                table: "drivers",
                columns: new[] { "CompanyId", "UserId" },
                unique: true,
                filter: "\"UserId\" IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_drivers_UserId",
                table: "drivers",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_driver_truck_sessions_ApprovedByAccountId",
                table: "driver_truck_sessions",
                column: "ApprovedByAccountId");

            migrationBuilder.CreateIndex(
                name: "IX_driver_truck_sessions_InitiatedByAccountId",
                table: "driver_truck_sessions",
                column: "InitiatedByAccountId");

            migrationBuilder.CreateIndex(
                name: "IX_companies_ConnectionCodeHash",
                table: "companies",
                column: "ConnectionCodeHash",
                unique: true,
                filter: "\"ConnectionCodeHash\" IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_company_connection_requests_AccountId",
                table: "company_connection_requests",
                column: "AccountId");

            migrationBuilder.CreateIndex(
                name: "IX_company_connection_requests_CompanyId_AccountId",
                table: "company_connection_requests",
                columns: new[] { "CompanyId", "AccountId" },
                unique: true,
                filter: "\"Status\" = 'Pending'");

            migrationBuilder.CreateIndex(
                name: "IX_company_connection_requests_CompanyId_AccountId_Status",
                table: "company_connection_requests",
                columns: new[] { "CompanyId", "AccountId", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_company_connection_requests_DriverId",
                table: "company_connection_requests",
                column: "DriverId");

            migrationBuilder.CreateIndex(
                name: "IX_company_connection_requests_ResolvedByAccountId",
                table: "company_connection_requests",
                column: "ResolvedByAccountId");

            migrationBuilder.CreateIndex(
                name: "IX_company_invitations_AcceptedByAccountId",
                table: "company_invitations",
                column: "AcceptedByAccountId");

            migrationBuilder.CreateIndex(
                name: "IX_company_invitations_CompanyId_Email_Status",
                table: "company_invitations",
                columns: new[] { "CompanyId", "Email", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_company_invitations_DriverId",
                table: "company_invitations",
                column: "DriverId");

            migrationBuilder.CreateIndex(
                name: "IX_company_invitations_InviterAccountId",
                table: "company_invitations",
                column: "InviterAccountId");

            migrationBuilder.CreateIndex(
                name: "IX_company_invitations_TokenHash",
                table: "company_invitations",
                column: "TokenHash",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_company_membership_roles_CompanyId",
                table: "company_membership_roles",
                column: "CompanyId");

            migrationBuilder.CreateIndex(
                name: "IX_company_memberships_AccountId_Status",
                table: "company_memberships",
                columns: new[] { "AccountId", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_company_memberships_CompanyId_AccountId",
                table: "company_memberships",
                columns: new[] { "CompanyId", "AccountId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_company_memberships_InvitedByAccountId",
                table: "company_memberships",
                column: "InvitedByAccountId");

            migrationBuilder.CreateIndex(
                name: "IX_external_logins_AccountId_Provider",
                table: "external_logins",
                columns: new[] { "AccountId", "Provider" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_external_logins_Provider_ProviderSubject",
                table: "external_logins",
                columns: new[] { "Provider", "ProviderSubject" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_identity_audit_events_AccountId",
                table: "identity_audit_events",
                column: "AccountId");

            migrationBuilder.CreateIndex(
                name: "IX_identity_audit_events_ActorAccountId",
                table: "identity_audit_events",
                column: "ActorAccountId");

            migrationBuilder.CreateIndex(
                name: "IX_identity_audit_events_CompanyId_CreatedAt",
                table: "identity_audit_events",
                columns: new[] { "CompanyId", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_trip_driver_participations_ApprovedByAccountId",
                table: "trip_driver_participations",
                column: "ApprovedByAccountId");

            migrationBuilder.CreateIndex(
                name: "IX_trip_driver_participations_AssignedByAccountId",
                table: "trip_driver_participations",
                column: "AssignedByAccountId");

            migrationBuilder.CreateIndex(
                name: "IX_trip_driver_participations_CompanyId_TripId",
                table: "trip_driver_participations",
                columns: new[] { "CompanyId", "TripId" },
                unique: true,
                filter: "\"EndedAt\" IS NULL");

            migrationBuilder.CreateIndex(
                name: "IX_trip_driver_participations_CompanyId_TripId_StartedAt",
                table: "trip_driver_participations",
                columns: new[] { "CompanyId", "TripId", "StartedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_trip_driver_participations_DriverId",
                table: "trip_driver_participations",
                column: "DriverId");

            migrationBuilder.CreateIndex(
                name: "IX_trip_driver_participations_HandoverRequestId",
                table: "trip_driver_participations",
                column: "HandoverRequestId");

            migrationBuilder.CreateIndex(
                name: "IX_trip_driver_participations_TripId",
                table: "trip_driver_participations",
                column: "TripId");

            migrationBuilder.CreateIndex(
                name: "IX_trip_handover_requests_CompanyId_TripId",
                table: "trip_handover_requests",
                columns: new[] { "CompanyId", "TripId" },
                unique: true,
                filter: "\"Status\" = 'Pending'");

            migrationBuilder.CreateIndex(
                name: "IX_trip_handover_requests_CompanyId_TripId_Status",
                table: "trip_handover_requests",
                columns: new[] { "CompanyId", "TripId", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_trip_handover_requests_CurrentDriverId",
                table: "trip_handover_requests",
                column: "CurrentDriverId");

            migrationBuilder.CreateIndex(
                name: "IX_trip_handover_requests_RequestedByAccountId",
                table: "trip_handover_requests",
                column: "RequestedByAccountId");

            migrationBuilder.CreateIndex(
                name: "IX_trip_handover_requests_RequestingDriverId",
                table: "trip_handover_requests",
                column: "RequestingDriverId");

            migrationBuilder.CreateIndex(
                name: "IX_trip_handover_requests_ResolvedByAccountId",
                table: "trip_handover_requests",
                column: "ResolvedByAccountId");

            migrationBuilder.CreateIndex(
                name: "IX_trip_handover_requests_TripId",
                table: "trip_handover_requests",
                column: "TripId");

            migrationBuilder.CreateIndex(
                name: "IX_trip_handover_requests_TruckId",
                table: "trip_handover_requests",
                column: "TruckId");

            migrationBuilder.CreateIndex(
                name: "IX_truck_qr_credentials_CompanyId_TruckId",
                table: "truck_qr_credentials",
                columns: new[] { "CompanyId", "TruckId" },
                unique: true,
                filter: "\"RevokedAt\" IS NULL");

            migrationBuilder.CreateIndex(
                name: "IX_truck_qr_credentials_GeneratedByAccountId",
                table: "truck_qr_credentials",
                column: "GeneratedByAccountId");

            migrationBuilder.CreateIndex(
                name: "IX_truck_qr_credentials_RevokedByAccountId",
                table: "truck_qr_credentials",
                column: "RevokedByAccountId");

            migrationBuilder.CreateIndex(
                name: "IX_truck_qr_credentials_TokenHash",
                table: "truck_qr_credentials",
                column: "TokenHash",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_truck_qr_credentials_TruckId",
                table: "truck_qr_credentials",
                column: "TruckId");

            migrationBuilder.AddForeignKey(
                name: "FK_driver_truck_sessions_users_ApprovedByAccountId",
                table: "driver_truck_sessions",
                column: "ApprovedByAccountId",
                principalTable: "users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_driver_truck_sessions_users_InitiatedByAccountId",
                table: "driver_truck_sessions",
                column: "InitiatedByAccountId",
                principalTable: "users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_refresh_tokens_company_memberships_MembershipId",
                table: "refresh_tokens",
                column: "MembershipId",
                principalTable: "company_memberships",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_refresh_tokens_users_AccountId",
                table: "refresh_tokens",
                column: "AccountId",
                principalTable: "users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
                DO $$ BEGIN
                    IF EXISTS (
                        SELECT 1 FROM "users" AS account
                        WHERE (SELECT count(*) FROM "company_memberships" AS membership
                               WHERE membership."AccountId" = account."Id") <> 1)
                       OR EXISTS (
                        SELECT 1 FROM "company_memberships" AS membership
                        WHERE (SELECT count(*) FROM "company_membership_roles" AS membership_role
                               WHERE membership_role."MembershipId" = membership."Id") <> 1)
                       OR EXISTS (SELECT 1 FROM "users" WHERE "PasswordHash" IS NULL)
                       OR EXISTS (SELECT 1 FROM "refresh_tokens" WHERE "CompanyId" IS NULL)
                       OR EXISTS (SELECT 1 FROM "driver_truck_sessions"
                                  WHERE "StartedFromTripId" IS NULL OR "LastTripId" IS NULL)
                    THEN
                        RAISE EXCEPTION 'Sprint 4.3 rollback refused: global/multi-membership or trip-optional data cannot be losslessly collapsed.';
                    END IF;
                END $$;

                CREATE TEMP TABLE "__sprint43_collapse" ON COMMIT DROP AS
                SELECT membership."AccountId", membership."CompanyId", membership_role."Role"
                FROM "company_memberships" AS membership
                JOIN "company_membership_roles" AS membership_role
                  ON membership_role."MembershipId" = membership."Id";
                """);

            migrationBuilder.DropForeignKey(
                name: "FK_driver_truck_sessions_users_ApprovedByAccountId",
                table: "driver_truck_sessions");

            migrationBuilder.DropForeignKey(
                name: "FK_driver_truck_sessions_users_InitiatedByAccountId",
                table: "driver_truck_sessions");

            migrationBuilder.DropForeignKey(
                name: "FK_refresh_tokens_company_memberships_MembershipId",
                table: "refresh_tokens");

            migrationBuilder.DropForeignKey(
                name: "FK_refresh_tokens_users_AccountId",
                table: "refresh_tokens");

            migrationBuilder.DropTable(
                name: "company_connection_requests");

            migrationBuilder.DropTable(
                name: "company_invitations");

            migrationBuilder.DropTable(
                name: "company_membership_roles");

            migrationBuilder.DropTable(
                name: "external_logins");

            migrationBuilder.DropTable(
                name: "identity_audit_events");

            migrationBuilder.DropTable(
                name: "trip_driver_participations");

            migrationBuilder.DropTable(
                name: "truck_qr_credentials");

            migrationBuilder.DropTable(
                name: "company_memberships");

            migrationBuilder.DropTable(
                name: "trip_handover_requests");

            migrationBuilder.DropIndex(
                name: "IX_refresh_tokens_MembershipId",
                table: "refresh_tokens");

            migrationBuilder.DropIndex(
                name: "IX_drivers_CompanyId_UserId",
                table: "drivers");

            migrationBuilder.DropIndex(
                name: "IX_drivers_UserId",
                table: "drivers");

            migrationBuilder.DropIndex(
                name: "IX_driver_truck_sessions_ApprovedByAccountId",
                table: "driver_truck_sessions");

            migrationBuilder.DropIndex(
                name: "IX_driver_truck_sessions_InitiatedByAccountId",
                table: "driver_truck_sessions");

            migrationBuilder.DropIndex(
                name: "IX_companies_ConnectionCodeHash",
                table: "companies");

            migrationBuilder.DropColumn(
                name: "MembershipId",
                table: "refresh_tokens");

            migrationBuilder.DropColumn(
                name: "ApprovedByAccountId",
                table: "driver_truck_sessions");

            migrationBuilder.DropColumn(
                name: "InitiatedByAccountId",
                table: "driver_truck_sessions");

            migrationBuilder.DropColumn(
                name: "Source",
                table: "driver_truck_sessions");

            migrationBuilder.DropColumn(
                name: "ConnectionCodeHash",
                table: "companies");

            migrationBuilder.DropColumn(
                name: "ConnectionCodeHint",
                table: "companies");

            migrationBuilder.DropColumn(
                name: "ConnectionCodeVersion",
                table: "companies");

            migrationBuilder.RenameColumn(
                name: "AccountId",
                table: "refresh_tokens",
                newName: "UserId");

            migrationBuilder.RenameIndex(
                name: "IX_refresh_tokens_AccountId_ExpiresAt",
                table: "refresh_tokens",
                newName: "IX_refresh_tokens_UserId_ExpiresAt");

            migrationBuilder.AlterColumn<string>(
                name: "PasswordHash",
                table: "users",
                type: "character varying(200)",
                maxLength: 200,
                nullable: false,
                defaultValue: "",
                oldClrType: typeof(string),
                oldType: "character varying(200)",
                oldMaxLength: 200,
                oldNullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "CompanyId",
                table: "users",
                type: "uuid",
                nullable: false,
                defaultValue: new Guid("00000000-0000-0000-0000-000000000000"));

            migrationBuilder.AddColumn<string>(
                name: "Role",
                table: "users",
                type: "character varying(50)",
                maxLength: 50,
                nullable: false,
                defaultValue: "");

            migrationBuilder.Sql("""
                UPDATE "users" AS account
                SET "CompanyId" = collapsed."CompanyId",
                    "Role" = collapsed."Role"
                FROM "__sprint43_collapse" AS collapsed
                WHERE account."Id" = collapsed."AccountId";

                UPDATE "refresh_tokens" AS token
                SET "CompanyId" = collapsed."CompanyId"
                FROM "__sprint43_collapse" AS collapsed
                WHERE token."UserId" = collapsed."AccountId";
                """);


            migrationBuilder.AlterColumn<Guid>(
                name: "CompanyId",
                table: "refresh_tokens",
                type: "uuid",
                nullable: false,
                defaultValue: new Guid("00000000-0000-0000-0000-000000000000"),
                oldClrType: typeof(Guid),
                oldType: "uuid",
                oldNullable: true);

            migrationBuilder.AlterColumn<Guid>(
                name: "StartedFromTripId",
                table: "driver_truck_sessions",
                type: "uuid",
                nullable: false,
                defaultValue: new Guid("00000000-0000-0000-0000-000000000000"),
                oldClrType: typeof(Guid),
                oldType: "uuid",
                oldNullable: true);

            migrationBuilder.AlterColumn<Guid>(
                name: "LastTripId",
                table: "driver_truck_sessions",
                type: "uuid",
                nullable: false,
                defaultValue: new Guid("00000000-0000-0000-0000-000000000000"),
                oldClrType: typeof(Guid),
                oldType: "uuid",
                oldNullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_users_CompanyId",
                table: "users",
                column: "CompanyId");

            migrationBuilder.CreateIndex(
                name: "IX_drivers_UserId",
                table: "drivers",
                column: "UserId",
                unique: true,
                filter: "\"UserId\" IS NOT NULL");

            migrationBuilder.AddForeignKey(
                name: "FK_refresh_tokens_users_UserId",
                table: "refresh_tokens",
                column: "UserId",
                principalTable: "users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_users_companies_CompanyId",
                table: "users",
                column: "CompanyId",
                principalTable: "companies",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }
    }
}
