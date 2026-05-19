import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/checkin_api.dart';
import '../../../../core/services/socket_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/security_service.dart';
import '../../../../core/services/offline_sync_service.dart';
import '../../../../core/database/local_database.dart';

final checkinProvider =
    StateNotifierProvider<CheckinNotifier, CheckinState>((ref) {
  return CheckinNotifier();
});

class SecurityResult {
  final String riskLevel;
  final int score;
  final List<String> flags;
  final bool warned;

  const SecurityResult({
    required this.riskLevel,
    required this.score,
    required this.flags,
    required this.warned,
  });

  factory SecurityResult.fromJson(Map<String, dynamic> json) => SecurityResult(
        riskLevel: json['riskLevel'] as String? ?? 'low',
        score:     (json['score']    as num?)?.toInt() ?? 0,
        flags:     (json['flags']    as List?)?.cast<String>() ?? [],
        warned:    json['warned']    as bool? ?? false,
      );
}

class CheckinState {
  final bool isCheckingIn;
  final String? error;
  final SecurityResult? lastSecurityResult;
  final bool wasQueued;
  final String? lateMessage; // non-null when server marked check-in as late

  CheckinState({
    this.isCheckingIn = false,
    this.error,
    this.lastSecurityResult,
    this.wasQueued = false,
    this.lateMessage,
  });

  CheckinState copyWith({
    bool? isCheckingIn,
    String? error,
    SecurityResult? lastSecurityResult,
    bool? wasQueued,
    String? lateMessage,
  }) {
    return CheckinState(
      isCheckingIn: isCheckingIn ?? this.isCheckingIn,
      error: error ?? this.error,
      lastSecurityResult: lastSecurityResult ?? this.lastSecurityResult,
      wasQueued: wasQueued ?? this.wasQueued,
      lateMessage: lateMessage,
    );
  }
}

class CheckinNotifier extends StateNotifier<CheckinState> {
  final _api = CheckinApi();

  CheckinNotifier() : super(CheckinState());

  Future<({bool success, SecurityContext secCtx})> runSecurityScan() async {
    final secCtx = await SecurityService.scan();
    return (success: true, secCtx: secCtx);
  }

  Future<bool> checkInWithQr({
    required String sessionId,
    required String qrToken,
    required int qrWindow,
    required double latitude,
    required double longitude,
    String courseName = '',
    SecurityContext? securityContext,
  }) async {
    state = state.copyWith(isCheckingIn: true, error: null);
    try {
      final response = await _api.checkInWithQr(
        sessionId: sessionId,
        qrToken: qrToken,
        qrWindow: qrWindow,
        latitude: latitude,
        longitude: longitude,
        securityContext: securityContext,
      );
      final ok = response.data['success'] as bool? ?? false;
      final secData = response.data['data']?['security'] as Map<String, dynamic>?;
      final secResult = secData != null ? SecurityResult.fromJson(secData) : null;
      state = state.copyWith(isCheckingIn: false, lastSecurityResult: secResult);
      if (ok) {
        SocketService().emitStudentCheckin({
          'sessionId': sessionId,
          'latitude': latitude,
          'longitude': longitude,
        });
        if (courseName.isNotEmpty) {
          await NotificationService.showAttendanceConfirmed(courseName);
        }
      }
      return ok;
    } catch (e) {
      state = state.copyWith(isCheckingIn: false, error: e.toString());
      return false;
    }
  }

  Future<bool> checkIn({
    required String sessionId,
    required double latitude,
    required double longitude,
    String courseName = '',
    String? entryCode,
    SecurityContext? securityContext,
  }) async {
    state = state.copyWith(isCheckingIn: true, error: null, wasQueued: false);
    try {
      final response = await _api.checkIn(
        sessionId,
        {
          'latitude': latitude,
          'longitude': longitude,
          'entryCode': entryCode,
        },
        securityContext: securityContext,
      );

      final ok      = response.data['success'] as bool? ?? false;
      final data    = response.data['data'] as Map<String, dynamic>?;
      final secData = data?['security'] as Map<String, dynamic>?;
      final secResult = secData != null ? SecurityResult.fromJson(secData) : null;
      final isLate  = data?['attendanceStatus'] == 'late';
      final lateMsg = isLate ? (data?['message'] as String?) : null;

      state = state.copyWith(
        isCheckingIn: false,
        lastSecurityResult: secResult,
        lateMessage: lateMsg,
      );

      if (ok) {
        SocketService().emitStudentCheckin({
          'sessionId': sessionId,
          'latitude': latitude,
          'longitude': longitude,
        });
        if (courseName.isNotEmpty) {
          await NotificationService.showAttendanceConfirmed(courseName);
        }
      }

      return ok;
    } on DioException catch (e) {
      final isNetworkError = e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionTimeout;

      if (isNetworkError) {
        // Queue for later sync
        await OfflineSyncService.instance.enqueue(QueuedCheckin(
          id: const Uuid().v4(),
          sessionId: sessionId,
          entryCode: entryCode,
          latitude: latitude,
          longitude: longitude,
          courseName: courseName,
          securityContext: securityContext?.toJson(),
          queuedAt: DateTime.now(),
        ));
        state = state.copyWith(
            isCheckingIn: false, wasQueued: true, error: null);
        return true; // treat queued as "success" so UI shows confirmation
      }
      state = state.copyWith(
          isCheckingIn: false, error: e.response?.data?['error'] as String?);
      return false;
    } catch (e) {
      state = state.copyWith(isCheckingIn: false, error: e.toString());
      return false;
    }
  }
}
