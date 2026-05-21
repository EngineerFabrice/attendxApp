import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../constants/app_constants.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Set this from app.dart so tapped notifications can navigate
  static GlobalKey<NavigatorState>? navigatorKey;

  static Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: _onTap,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static void _onTap(NotificationResponse response) {
    final payload = response.payload ?? '';
    if (payload == 'messages') {
      navigatorKey?.currentState?.pushNamed('/messages');
    } else if (payload == 'dashboard') {
      navigatorKey?.currentState?.pushNamed('/dashboard');
    }
  }

  static Future<void> showSessionStarted(
      String courseName, String room) async {
    await _plugin.show(
      id: 10,
      title: 'Session Started',
      body: '$courseName in $room — tap to check in',
      notificationDetails: _details(channelId: 'attendx_sessions'),
      payload: 'dashboard',
    );
  }

  static Future<void> showAttendanceConfirmed(String courseName) async {
    await _plugin.show(
      id: 11,
      title: 'Attendance Confirmed',
      body: 'You have been marked present for $courseName',
      notificationDetails: _details(channelId: 'attendx_sessions'),
      payload: 'dashboard',
    );
  }

  static Future<void> showAbsenceWarning(
      String courseName, double rate) async {
    await _plugin.show(
      id: 12,
      title: 'Absence Warning',
      body: '$courseName attendance ${rate.toInt()}% — below ${AppConstants.attendanceWarningThreshold}% threshold',
      notificationDetails: _details(channelId: 'attendx_alerts'),
      payload: 'messages',
    );
  }

  static Future<void> showNewMessage(
      String senderName, String preview) async {
    await _plugin.show(
      id: 13,
      title: 'New message from $senderName',
      body: preview.length > 80 ? '${preview.substring(0, 80)}…' : preview,
      notificationDetails: _details(channelId: 'attendx_messages'),
      payload: 'messages',
    );
  }

  static NotificationDetails _details({String channelId = 'attendx_main'}) {
    final channelName = switch (channelId) {
      'attendx_sessions' => 'Session Alerts',
      'attendx_alerts'   => 'Attendance Warnings',
      'attendx_messages' => 'Messages',
      _                  => 'AttendX',
    };
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: 'AttendX $channelName',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
  }
}
