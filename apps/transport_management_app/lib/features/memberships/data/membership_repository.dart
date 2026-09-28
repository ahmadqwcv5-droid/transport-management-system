import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/membership_models.dart';

final class MembershipRepository {
  MembershipRepository(this._client);
  final ApiClient _client;

  Future<List<Invitation>> invitations() =>
      _list('/api/membership-invitations', Invitation.fromJson);

  Future<Invitation> createInvitation({
    required String email,
    required List<String> roles,
    String? driverId,
    String? displayName,
  }) => _post('/api/membership-invitations', {
    'email': email.trim(),
    'roles': roles,
    'driverId': ?driverId,
    'displayName': ?displayName,
  }, Invitation.fromJson);

  Future<void> revokeInvitation(String id) =>
      _empty('POST', '/api/membership-invitations/$id/revoke');

  Future<Invitation> previewInvitation(String token) async {
    try {
      final response = await _client.dio.get<Json>(
        '/api/invitations/preview',
        queryParameters: {'token': token},
      );
      return Invitation.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> acceptInvitation({
    required String token,
    String? email,
    String? displayName,
    String? password,
  }) => _empty('POST', '/api/invitations/accept', {
    'token': token,
    'email': ?email,
    'displayName': ?displayName,
    'password': ?password,
  });

  Future<void> declineInvitation(String token) =>
      _empty('POST', '/api/invitations/decline', {'token': token});

  Future<CompanyCode> companyCode() =>
      _get('/api/company-connection-code', CompanyCode.fromJson);

  Future<CompanyCode> rotateCompanyCode() =>
      _post('/api/company-connection-code/rotate', null, CompanyCode.fromJson);

  Future<CompanySummary> resolveCompany(String code) => _post(
    '/api/company-connections/resolve',
    {'code': code},
    CompanySummary.fromJson,
  );

  Future<ConnectionRequest> requestConnection(String code) => _post(
    '/api/company-connections',
    {'code': code},
    ConnectionRequest.fromJson,
  );

  Future<List<ConnectionRequest>> ownConnections() =>
      _list('/api/company-connections/mine', ConnectionRequest.fromJson);

  Future<List<ConnectionRequest>> pendingConnections() =>
      _list('/api/company-connections/pending', ConnectionRequest.fromJson);

  Future<ConnectionRequest> resolveConnection(
    String id, {
    required bool approve,
    String? driverId,
    String? reason,
  }) => _post(
    '/api/company-connections/$id/${approve ? 'approve' : 'reject'}',
    {'driverId': ?driverId, 'reason': ?reason},
    ConnectionRequest.fromJson,
  );

  Future<ConnectionRequest> cancelConnection(String id) => _post(
    '/api/company-connections/$id/cancel',
    null,
    ConnectionRequest.fromJson,
  );

  Future<void> setMembershipStatus(String id, String status) =>
      _empty('PUT', '/api/memberships/$id/status', {'status': status});

  Future<TruckQrStatus> truckQrStatus(String truckId) =>
      _get('/api/trucks/$truckId/qr', TruckQrStatus.fromJson);

  Future<TruckQrCredential> regenerateTruckQr(String truckId) => _post(
    '/api/trucks/$truckId/qr/regenerate',
    null,
    TruckQrCredential.fromJson,
  );

  Future<TruckQrPreview> previewTruckQr(String code) => _post(
    '/api/driver/truck-qr/preview',
    {'code': code},
    TruckQrPreview.fromJson,
  );

  Future<TruckSwitchResult> confirmTruckQr(String code, {String? reason}) =>
      _post('/api/driver/truck-qr/confirm', {
        'code': code,
        'reason': ?reason,
      }, TruckSwitchResult.fromJson);

  Future<List<Handover>> handovers() =>
      _list('/api/handovers', Handover.fromJson);

  Future<Handover> resolveHandover(
    String id, {
    required bool approve,
    String? reason,
  }) => _post('/api/handovers/$id/${approve ? 'approve' : 'reject'}', {
    'reason': ?reason,
  }, Handover.fromJson);

  Future<List<SignInMethod>> signInMethods() =>
      _list('/api/auth/me/sign-in-methods', SignInMethod.fromJson);

  Future<List<SignInMethod>> linkProvider(
    String provider,
    String idToken, {
    String? nonce,
  }) async {
    try {
      final response = await _client.dio.post<List<dynamic>>(
        '/api/auth/me/external-logins',
        data: {'provider': provider, 'idToken': idToken, 'nonce': ?nonce},
      );
      return response.data!.cast<Json>().map(SignInMethod.fromJson).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<SignInMethod>> unlinkProvider(String provider) async {
    try {
      final response = await _client.dio.delete<List<dynamic>>(
        '/api/auth/me/external-logins/$provider',
      );
      return response.data!.cast<Json>().map(SignInMethod.fromJson).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<bool> googleConfigured() async {
    try {
      final response = await _client.dio.get<List<dynamic>>(
        '/api/auth/external/providers',
      );
      final providers = response.data!.cast<Json>();
      for (final provider in providers) {
        if ((provider['provider'] as String?)?.toLowerCase() == 'google') {
          return provider['isConfigured'] as bool? ?? false;
        }
      }
      return false;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<T> _get<T>(String path, T Function(Json) parse) async {
    try {
      final response = await _client.dio.get<Json>(path);
      return parse(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<T> _post<T>(String path, Object? data, T Function(Json) parse) async {
    try {
      final response = await _client.dio.post<Json>(path, data: data);
      return parse(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<T>> _list<T>(String path, T Function(Json) parse) async {
    try {
      final response = await _client.dio.get<List<dynamic>>(path);
      return response.data!.cast<Json>().map(parse).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> _empty(String method, String path, [Object? data]) async {
    try {
      await _client.dio.request<void>(
        path,
        data: data,
        options: Options(method: method),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
