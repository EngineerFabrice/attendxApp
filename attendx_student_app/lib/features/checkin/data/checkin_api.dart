import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/services/security_service.dart';

class CheckinApi {
  final Dio _dio = ApiClient().dio;

  Future<Response> checkIn(
    String sessionId,
    Map<String, dynamic> data, {
    SecurityContext? securityContext,
  }) {
    return _dio.post(ApiEndpoints.checkin, data: {
      'sessionId': sessionId,
      ...data,
      if (securityContext != null) 'securityContext': securityContext.toJson(),
    });
  }

  Future<Response> checkInWithQr({
    required String sessionId,
    required String qrToken,
    required int qrWindow,
    required double latitude,
    required double longitude,
    SecurityContext? securityContext,
  }) {
    return _dio.post(ApiEndpoints.checkin, data: {
      'sessionId': sessionId,
      'qrToken': qrToken,
      'qrWindow': qrWindow,
      'latitude': latitude,
      'longitude': longitude,
      if (securityContext != null) 'securityContext': securityContext.toJson(),
    });
  }
}
