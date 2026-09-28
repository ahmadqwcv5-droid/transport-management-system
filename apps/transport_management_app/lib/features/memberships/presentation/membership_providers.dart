import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/membership_repository.dart';
import '../domain/membership_models.dart';

final membershipRepositoryProvider = Provider<MembershipRepository>(
  (ref) => MembershipRepository(ref.watch(apiClientProvider)),
);

final invitationsProvider = FutureProvider<List<Invitation>>(
  (ref) => ref.watch(membershipRepositoryProvider).invitations(),
);
final companyCodeProvider = FutureProvider<CompanyCode>(
  (ref) => ref.watch(membershipRepositoryProvider).companyCode(),
);
final pendingConnectionsProvider = FutureProvider<List<ConnectionRequest>>(
  (ref) => ref.watch(membershipRepositoryProvider).pendingConnections(),
);
final ownConnectionsProvider = FutureProvider<List<ConnectionRequest>>(
  (ref) => ref.watch(membershipRepositoryProvider).ownConnections(),
);
final handoversProvider = FutureProvider<List<Handover>>(
  (ref) => ref.watch(membershipRepositoryProvider).handovers(),
);
final signInMethodsProvider = FutureProvider<List<SignInMethod>>(
  (ref) => ref.watch(membershipRepositoryProvider).signInMethods(),
);
final googleConfiguredProvider = Provider<bool>(
  (_) =>
      const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID').isNotEmpty ||
      const String.fromEnvironment('GOOGLE_ANDROID_CLIENT_ID').isNotEmpty ||
      const String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID').isNotEmpty,
);
