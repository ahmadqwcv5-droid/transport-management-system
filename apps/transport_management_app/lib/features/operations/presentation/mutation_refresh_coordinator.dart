import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../clients/domain/client_models.dart';
import '../../dashboard/presentation/dashboard_controller.dart';
import '../../fleet/domain/fleet_models.dart';
import '../../trips/presentation/trips_controller.dart';
import 'operations_controller.dart';

final clientDetailsProvider = FutureProvider.autoDispose
    .family<ClientDetails, String>(
      (ref, id) => ref.watch(operationsRepositoryProvider).clientDetails(id),
    );
final truckDetailsProvider = FutureProvider.autoDispose
    .family<TruckDetails, String>(
      (ref, id) => ref.watch(operationsRepositoryProvider).truckDetails(id),
    );

final mutationRefreshCoordinatorProvider = Provider(
  MutationRefreshCoordinator.new,
);

final class MutationRefreshCoordinator {
  MutationRefreshCoordinator(this.ref);
  final Ref ref;
  int _generation = 0;
  Object? lastError;

  Future<void> refresh({String? clientId, String? truckId}) async {
    final generation = ++_generation;
    if (clientId != null) ref.invalidate(clientDetailsProvider(clientId));
    if (truckId != null) ref.invalidate(truckDetailsProvider(truckId));
    await Future.wait([
      ref.read(operationsControllerProvider.notifier).reload(),
      ref.read(tripsControllerProvider.notifier).refresh(),
      ref.read(dashboardControllerProvider.notifier).refresh(silent: true),
    ]);
    if (generation != _generation) return;
    if (clientId != null) {
      await ref.read(clientDetailsProvider(clientId).future);
    }
    if (truckId != null) await ref.read(truckDetailsProvider(truckId).future);
  }

  Future<bool> mutate(
    Future<void> Function() operation, {
    String? clientId,
    String? truckId,
  }) async {
    try {
      lastError = null;
      await operation();
      await refresh(clientId: clientId, truckId: truckId);
      return true;
    } catch (error) {
      lastError = error;
      return false;
    }
  }
}
