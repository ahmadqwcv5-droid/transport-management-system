import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/company_users_repository.dart';
import '../domain/company_user.dart';
import '../../memberships/domain/membership_models.dart' show Invitation;

final companyUsersRepositoryProvider = Provider<CompanyUsersRepository>(
  (ref) => CompanyUsersRepository(ref.watch(apiClientProvider)),
);

final companyUsersControllerProvider =
    AsyncNotifierProvider<CompanyUsersController, List<CompanyUser>>(
      CompanyUsersController.new,
    );

class CompanyUsersController extends AsyncNotifier<List<CompanyUser>> {
  CompanyUsersRepository get _repository =>
      ref.read(companyUsersRepositoryProvider);

  @override
  Future<List<CompanyUser>> build() => _repository.list();

  Future<void> refresh() async {
    state = await AsyncValue.guard(_repository.list);
  }

  Future<Invitation?> create({
    required String email,
    required String displayName,
    String? driverId,
  }) async {
    try {
      final credential = await _repository.createDriver(
        email: email,
        displayName: displayName,
        driverId: driverId,
      );
      await refresh();
      return credential;
    } on Object {
      return null;
    }
  }

  Future<bool> updateRoles(String id, List<String> roles) =>
      _mutate(() => _repository.updateRoles(id, roles));
  Future<bool> setActive(String id, bool active) =>
      _mutate(() => _repository.setActive(id, active));
  Future<bool> link(String userId, String driverId) =>
      _mutate(() => _repository.link(userId, driverId));
  Future<bool> unlink(String userId) =>
      _mutate(() => _repository.unlink(userId));

  Future<bool> _mutate(Future<void> Function() action) async {
    try {
      await action();
      await refresh();
      return true;
    } on Object {
      return false;
    }
  }
}
