import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class HistoryApi {
  final Dio _dio = ApiClient().dio;

  Future<Response> getHistory({String? courseId}) {
    return _dio.get(
      ApiEndpoints.studentHistory,
      queryParameters: courseId != null ? {'courseId': courseId} : null,
    );
  }

  Future<Response> getCourses() {
    return _dio.get(ApiEndpoints.studentCourses);
  }

  Future<Response> submitAppeal(String recordId, String reason) {
    return _dio.post(ApiEndpoints.appeals, data: {
      'recordId': recordId,
      'reason': reason,
    });
  }
}
