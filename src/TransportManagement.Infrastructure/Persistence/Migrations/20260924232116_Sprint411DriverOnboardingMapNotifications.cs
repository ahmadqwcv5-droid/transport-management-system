using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace TransportManagement.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class Sprint411DriverOnboardingMapNotifications : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "NotificationSoundsEnabled",
                table: "users",
                type: "boolean",
                nullable: false,
                defaultValue: true);

            migrationBuilder.CreateTable(
                name: "company_user_events",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    CompanyId = table.Column<Guid>(type: "uuid", nullable: false),
                    SubjectUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    ActorUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    EventCode = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: false),
                    Metadata = table.Column<string>(type: "jsonb", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_company_user_events", x => x.Id);
                    table.ForeignKey(
                        name: "FK_company_user_events_companies_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "companies",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_company_user_events_users_ActorUserId",
                        column: x => x.ActorUserId,
                        principalTable: "users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_company_user_events_users_SubjectUserId",
                        column: x => x.SubjectUserId,
                        principalTable: "users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_company_user_events_ActorUserId",
                table: "company_user_events",
                column: "ActorUserId");

            migrationBuilder.CreateIndex(
                name: "IX_company_user_events_CompanyId_SubjectUserId_CreatedAt",
                table: "company_user_events",
                columns: new[] { "CompanyId", "SubjectUserId", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_company_user_events_SubjectUserId",
                table: "company_user_events",
                column: "SubjectUserId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "company_user_events");

            migrationBuilder.DropColumn(
                name: "NotificationSoundsEnabled",
                table: "users");
        }
    }
}
