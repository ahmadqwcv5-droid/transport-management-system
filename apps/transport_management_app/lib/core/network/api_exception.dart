import 'package:dio/dio.dart';

final class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.code});
  final String message;
  final int? statusCode;
  final String? code;

  factory ApiException.fromDio(DioException error) {
    final data = error.response?.data;
    final detail = data is Map<String, dynamic> ? data['detail'] : null;
    final code = data is Map<String, dynamic> ? data['errorCode'] : null;
    return ApiException(
      detail is String ? detail : 'Unable to complete the request.',
      statusCode: error.response?.statusCode,
      code: code is String ? code : null,
    );
  }

  @override
  String toString() => message;
}
