import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/driver_trip_history_repository.dart';
import '../domain/driver_trip_history_models.dart';

final driverTripHistoryRepositoryProvider = Provider(
  (ref) => DriverTripHistoryRepository(ref.watch(apiClientProvider)),
);

final driverTripHistoryControllerProvider =
    AsyncNotifierProvider<DriverTripHistoryController, DriverTripHistoryPage>(
      DriverTripHistoryController.new,
    );

final driverTripHistoryDetailProvider = FutureProvider.autoDispose
    .family<DriverTripHistoryDetail, String>(
      (ref, id) => ref.watch(driverTripHistoryRepositoryProvider).detail(id),
    );

class DriverTripHistoryController extends AsyncNotifier<DriverTripHistoryPage> {
  String category = 'current';
  int page = 1;
  DateTime? from, to;
  int _generation = 0;

  @override
  FutureOr<DriverTripHistoryPage> build() => _load();

  Future<DriverTripHistoryPage> _load() => ref
      .read(driverTripHistoryRepositoryProvider)
      .query(category: category, page: page, from: from, to: to);

  Future<void> refresh() async {
    final generation = ++_generation;
    final result = await AsyncValue.guard(_load);
    if (ref.mounted && generation == _generation) state = result;
  }

  void setCategory(String value) {
    if (category == value) return;
    category = value;
    page = 1;
    state = const AsyncLoading();
    refresh();
  }

  void setDateRange(DateTime? start, DateTime? end) {
    from = start;
    to = end == null
        ? null
        : DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
    page = 1;
    state = const AsyncLoading();
    refresh();
  }

  void goToPage(int value) {
    if (value < 1) return;
    page = value;
    state = const AsyncLoading();
    refresh();
  }
}
