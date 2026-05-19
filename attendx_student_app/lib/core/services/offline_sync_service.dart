import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../database/local_database.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';

class OfflineSyncService {
  static final OfflineSyncService instance = OfflineSyncService._();
  OfflineSyncService._();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _syncing = false;

  // Notifier so any widget can listen for queue changes
  final pendingCount = ValueNotifier<int>(0);
  final lastSyncedAt = ValueNotifier<DateTime?>(null);

  Future<void> start() async {
    await _refreshCount();
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) sync();
    });
    // Attempt immediately if already online
    sync();
  }

  void dispose() {
    _connectivitySub?.cancel();
  }

  Future<void> sync() async {
    if (_syncing) return;
    final pending = await LocalDatabase.instance.getPendingQueue();
    if (pending.isEmpty) return;

    _syncing = true;
    final dio = ApiClient().dio;

    for (final item in pending) {
      await _syncItem(item, dio);
    }

    await LocalDatabase.instance.clearSyncedQueue();
    await _refreshCount();
    lastSyncedAt.value = DateTime.now();
    _syncing = false;
  }

  Future<void> _syncItem(QueuedCheckin item, Dio dio) async {
    final updated = item.copyWith(
      attempts: item.attempts + 1,
      lastAttemptAt: DateTime.now(),
    );

    try {
      final body = <String, dynamic>{
        'sessionId': item.sessionId,
        'latitude':  item.latitude,
        'longitude': item.longitude,
      };

      if (item.qrToken != null && item.qrWindow != null) {
        body['qrToken']  = item.qrToken;
        body['qrWindow'] = item.qrWindow;
      } else if (item.entryCode != null) {
        body['entryCode'] = item.entryCode;
      }

      if (item.securityContext != null) {
        body['securityContext'] = item.securityContext;
      }

      await dio.post(ApiEndpoints.checkin, data: body);

      // Success — mark synced
      await LocalDatabase.instance.updateQueueItem(
        updated.copyWith(status: 'synced'),
      );
    } on DioException catch (e) {
      final isNetworkError = e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionTimeout;

      if (!isNetworkError) {
        // Validation error (already checked in, session expired, etc.)
        // Don't retry — mark as failed permanently
        await LocalDatabase.instance.updateQueueItem(
          updated.copyWith(status: 'failed'),
        );
      } else {
        // Network error — keep as pending so it retries next time
        await LocalDatabase.instance.updateQueueItem(updated);
      }
    } catch (_) {
      await LocalDatabase.instance.updateQueueItem(updated);
    }
  }

  Future<void> _refreshCount() async {
    pendingCount.value = await LocalDatabase.instance.getPendingCount();
  }

  Future<void> enqueue(QueuedCheckin item) async {
    await LocalDatabase.instance.enqueue(item);
    await _refreshCount();
  }
}
