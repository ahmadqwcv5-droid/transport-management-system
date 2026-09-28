import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_selector/file_selector.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../l10n/l10n_extensions.dart';
import '../../../clients/domain/client_models.dart';
import '../../../operations/presentation/mutation_refresh_coordinator.dart';
import '../../../operations/presentation/operations_controller.dart';
import '../../../operations/presentation/operations_view.dart';
import '../../domain/fleet_models.dart';
import 'trucks_screen.dart';
import '../../../../shared/widgets/truck_avatar.dart';
import '../../../memberships/domain/membership_models.dart';
import '../../../memberships/presentation/membership_providers.dart';

class TruckDetailsScreen extends ConsumerWidget {
  const TruckDetailsScreen({required this.truckId, super.key});
  final String truckId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(truckDetailsProvider(truckId))
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(context.l10n.genericError)),
        data: (details) => RefreshIndicator(
          onRefresh: () => ref
              .read(mutationRefreshCoordinatorProvider)
              .refresh(truckId: truckId),
          child: ListView(
            key: const Key('truck-details'),
            padding: const EdgeInsets.all(16),
            children: [
              _Header(details.truck),
              const SizedBox(height: 12),
              _Profile(details.truck),
              if (canManageOperations(ref)) ...[
                const SizedBox(height: 12),
                _QrCredentialCard(details.truck),
              ],
              const SizedBox(height: 12),
              _Position(details.latestPosition),
              const SizedBox(height: 12),
              _Trips(details.trips),
              const SizedBox(height: 12),
              _Events(details.events),
            ],
          ),
        ),
      );
}

class _Header extends ConsumerWidget {
  const _Header(this.truck);
  final Truck truck;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Row(
    children: [
      TruckAvatar(
        photoUrl: truck.photoThumbnailUrl,
        photoVersion: truck.photoVersion,
        radius: 36,
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              truck.plateNumber,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  label: Text(
                    '${context.l10n.baseStatus}: ${localizedStatus(context.l10n, truck.baseStatus)}',
                  ),
                ),
                Chip(
                  label: Text(
                    '${context.l10n.operationalState}: ${localizedStatus(context.l10n, truck.operationalState)}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      if (canManageOperations(ref))
        IconButton(
          key: const Key('upload-truck-photo'),
          icon: const Icon(Icons.add_a_photo_outlined),
          tooltip: context.l10n.uploadTruckPhoto,
          onPressed: () => _uploadPhoto(context, ref),
        ),
      if (canManageOperations(ref) && truck.photoVersion != null)
        IconButton(
          key: const Key('remove-truck-photo'),
          icon: const Icon(Icons.no_photography_outlined),
          tooltip: context.l10n.removeTruckPhoto,
          onPressed: () => _removePhoto(context, ref),
        ),
      if (canManageOperations(ref))
        IconButton(
          key: const Key('edit-truck-details'),
          icon: const Icon(Icons.edit_outlined),
          tooltip: context.l10n.edit,
          onPressed: () async {
            final data = await showDialog<Map<String, dynamic>>(
              context: context,
              builder: (_) => TruckFormDialog(
                truck: truck,
                drivers:
                    ref.read(operationsControllerProvider).value?.drivers ??
                    const [],
              ),
            );
            if (data == null) return;
            final ok = await ref
                .read(mutationRefreshCoordinatorProvider)
                .mutate(
                  () => ref
                      .read(operationsRepositoryProvider)
                      .saveTruck(data, truck.id),
                  truckId: truck.id,
                );
            if (context.mounted) showResult(context, ok);
          },
        ),
      if (canManageOperations(ref))
        PopupMenuButton<String>(
          key: const Key('truck-status-menu'),
          onSelected: (status) async {
            if (status == 'CorrectOdometer') {
              final kilometers = TextEditingController(
                text: truck.odometerKilometers?.toString(),
              );
              final reason = TextEditingController();
              final correction = await showDialog<(num, String)>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: Text(context.l10n.correctOdometer),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: kilometers,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: context.l10n.odometer,
                        ),
                      ),
                      TextField(
                        controller: reason,
                        decoration: InputDecoration(
                          labelText: context.l10n.correctionReason,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(context.l10n.cancel),
                    ),
                    FilledButton(
                      onPressed: () {
                        final value = num.tryParse(kilometers.text);
                        if (value == null ||
                            value < 0 ||
                            reason.text.trim().isEmpty) {
                          return;
                        }
                        Navigator.pop(dialogContext, (
                          value,
                          reason.text.trim(),
                        ));
                      },
                      child: Text(context.l10n.confirm),
                    ),
                  ],
                ),
              );
              if (correction == null) return;
              final ok = await ref
                  .read(mutationRefreshCoordinatorProvider)
                  .mutate(
                    () => ref
                        .read(operationsRepositoryProvider)
                        .correctTruckOdometer(
                          truck.id,
                          correction.$1,
                          correction.$2,
                        ),
                    truckId: truck.id,
                  );
              if (context.mounted) showResult(context, ok);
              return;
            }
            if (status == 'Delete') {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: Text(context.l10n.delete),
                  content: Text(context.l10n.deleteTruckWarning),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: Text(context.l10n.cancel),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: Text(context.l10n.confirm),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
            }
            final ok = await ref
                .read(mutationRefreshCoordinatorProvider)
                .mutate(
                  () => status == 'Delete'
                      ? ref
                            .read(operationsRepositoryProvider)
                            .deleteResource('trucks', truck.id)
                      : ref
                            .read(operationsRepositoryProvider)
                            .setFleetStatus('trucks', truck.id, status),
                  truckId: status == 'Delete' ? null : truck.id,
                );
            if (context.mounted) {
              showResult(context, ok);
              if (ok && status == 'Delete') context.go('/trucks');
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'CorrectOdometer',
              child: Text(context.l10n.correctOdometer),
            ),
            if (truck.baseStatus != 'Available')
              PopupMenuItem(
                value: 'Available',
                child: Text(context.l10n.setAvailable),
              ),
            if (truck.baseStatus != 'Maintenance')
              PopupMenuItem(
                value: 'Maintenance',
                child: Text(context.l10n.setMaintenance),
              ),
            if (truck.baseStatus != 'OutOfService')
              PopupMenuItem(
                value: 'OutOfService',
                child: Text(context.l10n.outOfService),
              ),
            if (truck.baseStatus != 'Archived')
              PopupMenuItem(
                value: 'Archived',
                child: Text(context.l10n.archive),
              ),
            if (truck.baseStatus == 'Archived')
              PopupMenuItem(value: 'Delete', child: Text(context.l10n.delete)),
          ],
        ),
    ],
  );

  Future<void> _uploadPhoto(BuildContext context, WidgetRef ref) async {
    const typeGroup = XTypeGroup(
      label: 'images',
      extensions: ['jpg', 'jpeg', 'png', 'webp'],
      mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
      webWildCards: ['image/jpeg', 'image/png', 'image/webp'],
    );
    final file = await openFile(acceptedTypeGroups: const [typeGroup]);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final ok = await ref
        .read(mutationRefreshCoordinatorProvider)
        .mutate(
          () => ref
              .read(operationsRepositoryProvider)
              .uploadTruckPhoto(truck.id, bytes, file.name),
          truckId: truck.id,
        );
    if (context.mounted) showResult(context, ok);
  }

  Future<void> _removePhoto(BuildContext context, WidgetRef ref) async {
    final ok = await ref
        .read(mutationRefreshCoordinatorProvider)
        .mutate(
          () =>
              ref.read(operationsRepositoryProvider).removeTruckPhoto(truck.id),
          truckId: truck.id,
        );
    if (context.mounted) showResult(context, ok);
  }
}

class _Profile extends StatelessWidget {
  const _Profile(this.truck);
  final Truck truck;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.details,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          _line(context.l10n.fleetCode, truck.fleetCode),
          _line(context.l10n.vin, truck.vin),
          _line(context.l10n.make, truck.make),
          _line(context.l10n.model, truck.model),
          _line(context.l10n.year, truck.year?.toString()),
          _line(
            context.l10n.truckType,
            truck.type == null
                ? null
                : localizedStatus(context.l10n, truck.type!),
          ),
          _line(
            context.l10n.payloadCapacity,
            truck.payloadCapacity == null
                ? null
                : '${truck.payloadCapacity} ${localizedStatus(context.l10n, truck.payloadUnit)}',
          ),
          _line(
            context.l10n.fuelType,
            truck.fuelType == null
                ? null
                : localizedStatus(context.l10n, truck.fuelType!),
          ),
          _line(context.l10n.odometer, truck.odometerKilometers?.toString()),
          _line(context.l10n.defaultDriver, truck.defaultDriverName),
          _line(context.l10n.currentTrip, truck.currentTripNumber),
          _line(context.l10n.notes, truck.notes),
        ],
      ),
    ),
  );
}

class _Position extends StatelessWidget {
  const _Position(this.position);
  final LatestTruckPosition? position;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.latestPosition,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (position == null)
            Text(context.l10n.noPosition)
          else ...[
            Semantics(
              label: context.l10n.latestPosition,
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, size: 36),
                      Text(
                        '${position!.latitude.toStringAsFixed(5)}, ${position!.longitude.toStringAsFixed(5)}',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${localizedStatus(context.l10n, position!.locationState)} • ${position!.recordedAt}',
            ),
          ],
        ],
      ),
    ),
  );
}

class _Trips extends StatelessWidget {
  const _Trips(this.items);
  final List<ResourceTripSummary> items;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.trips,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          ...items.map(
            (trip) => ListTile(
              title: Text(trip.tripNumber),
              subtitle: Text(
                [
                  '${trip.origin ?? '—'} → ${trip.destination ?? '—'}',
                  trip.driverName,
                ].whereType<String>().join(' • '),
              ),
              trailing: Text(localizedStatus(context.l10n, trip.status)),
              onTap: () => context.go('/trips/${trip.id}'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Events extends StatelessWidget {
  const _Events(this.items);
  final List<OperationsEvent> items;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.activity,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (items.isEmpty) Text(context.l10n.noActivity),
          ...items.map(
            (event) => ListTile(
              leading: const Icon(Icons.history),
              title: Text(
                localizedOperationsEvent(context.l10n, event.eventCode),
              ),
              subtitle: Text(event.occurredAt),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _line(String label, String? value) => Padding(
  padding: const EdgeInsets.only(top: 8),
  child: Text('$label: ${value ?? '—'}'),
);

class _QrCredentialCard extends ConsumerStatefulWidget {
  const _QrCredentialCard(this.truck);
  final Truck truck;

  @override
  ConsumerState<_QrCredentialCard> createState() => _QrCredentialCardState();
}

class _QrCredentialCardState extends ConsumerState<_QrCredentialCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(truckQrStatusProvider(widget.truck.id));
    return Card(
      key: const Key('truck-qr-status-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: status.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.truckQrStatus,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                error is ApiException
                    ? localizedErrorCode(context.l10n, error.code)
                    : context.l10n.genericError,
              ),
              TextButton.icon(
                onPressed: () =>
                    ref.invalidate(truckQrStatusProvider(widget.truck.id)),
                icon: const Icon(Icons.refresh),
                label: Text(context.l10n.retry),
              ),
            ],
          ),
          data: (value) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.truckQrStatus,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                value.hasActiveCredential
                    ? context.l10n.truckQrActiveHint(value.codeHint ?? '')
                    : context.l10n.truckQrNotGenerated,
              ),
              if (value.generatedAt != null)
                Text(value.generatedAt!.toLocal().toString()),
              if (value.generatedByDisplayName != null)
                Text(
                  '${context.l10n.generatedBy}: '
                  '${value.generatedByDisplayName}',
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('generate-truck-qr'),
                onPressed: _busy ? null : () => _generate(value),
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.qr_code_2),
                label: Text(
                  value.hasActiveCredential
                      ? context.l10n.regenerateTruckQr
                      : context.l10n.generateTruckQr,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generate(TruckQrStatus status) async {
    if (status.hasActiveCredential) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.l10n.regenerateTruckQr),
          content: Text(context.l10n.truckQrExplanation),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.l10n.confirm),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => _busy = true);
    try {
      final credential = await ref
          .read(membershipRepositoryProvider)
          .regenerateTruckQr(widget.truck.id);
      ref.invalidate(truckQrStatusProvider(widget.truck.id));
      if (mounted) await _showGeneratedQrDialog(context, credential);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizedErrorCode(context.l10n, error.code))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

Future<void> _showGeneratedQrDialog(
  BuildContext context,
  TruckQrCredential credential,
) async {
  final repaintKey = GlobalKey();
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text('${context.l10n.qrCode} - ${credential.plateNumber}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              key: repaintKey,
              child: ColoredBox(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: QrImageView(
                    data: credential.qrPayload,
                    size: 240,
                    semanticsLabel:
                        '${context.l10n.qrCode} ${credential.plateNumber}',
                  ),
                ),
              ),
            ),
            SelectableText(credential.code),
            const SizedBox(height: 8),
            Text(context.l10n.truckQrExplanation),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () =>
              Clipboard.setData(ClipboardData(text: credential.code)),
          icon: const Icon(Icons.copy),
          label: Text(context.l10n.copy),
        ),
        TextButton.icon(
          key: const Key('download-truck-qr-png'),
          onPressed: () => _saveQrPng(repaintKey, credential.plateNumber),
          icon: const Icon(Icons.download),
          label: Text(context.l10n.downloadPng),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(context.l10n.done),
        ),
      ],
    ),
  );
}

Future<void> _saveQrPng(GlobalKey repaintKey, String plateNumber) async {
  final boundary =
      repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return;
  final image = await boundary.toImage(pixelRatio: 3);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  if (data == null) return;
  final safePlate = plateNumber.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final fileName = '${safePlate}_truck_qr.png';
  final location = await getSaveLocation(
    suggestedName: fileName,
    acceptedTypeGroups: const [
      XTypeGroup(label: 'PNG image', extensions: ['png']),
    ],
  );
  if (location == null) return;
  final file = XFile.fromData(
    data.buffer.asUint8List(),
    mimeType: 'image/png',
    name: fileName,
  );
  await file.saveTo(location.path);
}
