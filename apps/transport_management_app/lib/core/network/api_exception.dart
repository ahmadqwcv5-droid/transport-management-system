import 'package:dio/dio.dart';

final class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  factory ApiException.fromDio(DioException error) {
    final data = error.response?.data;
    final detail = data is Map<String, dynamic> ? data['detail'] : null;
    return ApiException(
      detail is String ? detail : 'Unable to complete the request.',
      statusCode: error.response?.statusCode,
    );
  }

  @override
  String toString() => message;
}
