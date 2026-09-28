import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/company_user.dart';
import '../../memberships/domain/membership_models.dart' show Invitation;

final class CompanyUsersRepository {
  CompanyUsersRepository(this._client);
  final ApiClient _client;

  Future<List<CompanyUser>> list({String? role, bool? active}) async {
    try {
      final response = await _client.dio.get<List<dynamic>>(
        '/api/company-users',
        queryParameters: {'role': ?role, 'isActive': ?active},
      );
      return response.data!.cast<Json>().map(CompanyUser.fromJson).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Invitation> createDriver({
    required String email,
    required String displayName,
    String? driverId,
  }) async {
    try {
      final response = await _client.dio.post<Json>(
        '/api/company-users/drivers',
        data: {
          'email': email.trim(),
          'displayName': displayName.trim(),
          'driverId': ?driverId,
        },
      );
      return Invitation.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> setActive(String id, bool active) =>
      _send('PUT', '/api/company-users/$id/active', {'isActive': active});

  Future<void> link(String userId, String driverId) => _send(
    'PUT',
    '/api/company-users/$userId/driver-link',
    {'driverId': driverId},
  );

  Future<void> unlink(String userId) =>
      _send('DELETE', '/api/company-users/$userId/driver-link');

  Future<void> _send(String method, String path, [Json? data]) async {
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
