import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/operations_repository.dart';
import '../domain/operations_data.dart';

final operationsRepositoryProvider = Provider<OperationsRepository>(
  (ref) => OperationsRepository(ref.watch(apiClientProvider)),
);
final operationsControllerProvider =
    AsyncNotifierProvider<OperationsController, OperationsData>(
      OperationsController.new,
    );

class OperationsController extends AsyncNotifier<OperationsData> {
  OperationsRepository get _repository =>
      ref.read(operationsRepositoryProvider);
  @override
  FutureOr<OperationsData> build() => _repository.load();
  Future<void> reload() async =>
      state = await AsyncValue.guard(_repository.load);
  Future<bool> mutate(
    Future<void> Function(OperationsRepository) operation,
  ) async {
    try {
      await operation(_repository);
      await reload();
      return true;
    } catch (error, stack) {
      state = AsyncError(error, stack);
      return false;
    }
  }
}

bool canManageOperations(WidgetRef ref) {
  return ref.watch(operationsCanManageProvider);
}

final operationsCanManageProvider = Provider<bool>((ref) {
  final role = ref.watch(authControllerProvider).value?.user.role;
  return role == 'Owner' || role == 'Operations';
});
