import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transport_management_app/features/auth/domain/auth_session.dart';
import 'package:transport_management_app/features/dashboard/domain/active_operation.dart';
import 'package:transport_management_app/features/dashboard/presentation/active_operation_card.dart';
import 'package:transport_management_app/features/live_operations/domain/live_operations_models.dart';
import 'package:transport_management_app/features/live_operations/presentation/notification_snapshot_text.dart';

void main() {
  test(
    'Driver account uses linked operational identity with safe fallback',
    () {
      const linked = CurrentUser(
        id: 'u1',
        companyId: 'c1',
        email: 'driver@example.test',
        displayName: 'Account Name',
        role: 'Driver',
        preferredLocale: 'en',
        driverName: 'Operational Driver',
      );
      const fallback = CurrentUser(
        id: 'u2',
        companyId: 'c1',
        email: 'driver2@example.test',
        displayName: 'Fallback Account',
        role: 'Driver',
        preferredLocale: 'en',
      );

      expect(linked.operationalDisplayName, 'Operational Driver');
      expect(fallback.operationalDisplayName, 'Fallback Account');
    },
  );

  testWidgets('waiting operation never fabricates progress', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ActiveOperationCard(operation: _operation())),
      ),
    );

    expect(find.text('Waiting for delivery confirmation'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Action: delivery confirmation'), findsOneWidget);
  });

  testWidgets('moving operation shows server-owned progress', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActiveOperationCard(
            operation: _operation(
              phase: 'ToDelivery',
              attention: 'NONE',
              progress: 42.5,
              remaining: 12500,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.textContaining('43%'), findsOneWidget);
    expect(find.textContaining('12.5 km remaining'), findsOneWidget);
  });

  testWidgets('notification snapshot renders stable operational context', (
    tester,
  ) async {
    late String detail;
    final notification = OperationNotification(
      id: 'n1',
      type: 'TruckArrivedAtDelivery',
      severity: 'Info',
      createdAt: DateTime.utc(2026).toIso8601String(),
      dataJson: jsonEncode({
        'TripNumber': 'TRIP-42',
        'PlateNumber': '06 ABC 42',
        'FleetCode': 'F-42',
        'driverName': 'Ada Driver',
        'stopName': 'Ankara Depot',
        'stopAddress': 'Depot Street',
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            detail = notificationSnapshotDetail(context, notification);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(detail, contains('TRIP-42 · 06 ABC 42 · F-42'));
    expect(detail, contains('Driver: Ada Driver'));
    expect(detail, contains('Stop: Ankara Depot'));
    expect(detail, contains('Depot Street'));
  });
}

ActiveOperation _operation({
  String phase = 'AwaitingDeliveryConfirmation',
  String attention = 'AWAITING_DELIVERY_CONFIRMATION',
  double? progress,
  double? remaining,
}) => ActiveOperation(
  tripId: 'trip-1',
  tripNumber: 'TRIP-1',
  clientId: 'client-1',
  clientName: 'Client',
  truckPlateNumber: '06 ABC 01',
  driverName: 'Driver',
  status: phase == 'ToDelivery' ? 'InTransit' : 'AtDelivery',
  operationalPhase: phase,
  nextMilestone: 'DeliveryConfirmation',
  nextStopName: 'Depot',
  progressPercent: progress,
  remainingDistanceMeters: remaining,
  trackingHealth: 'Current',
  attentionCode: attention,
  attentionPriority: attention == 'NONE' ? 10 : 4,
);
