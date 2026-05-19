import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

class MessagesApi {
  final Dio _dio = ApiClient().dio;

  Future<Response> getInbox()        => _dio.get('/messages/inbox');
  Future<Response> getUnreadCount()  => _dio.get('/messages/unread-count');
  Future<Response> markRead(String id)    => _dio.patch('/messages/$id/read');
  Future<Response> markAllRead()     => _dio.patch('/messages/mark-all-read');
}
