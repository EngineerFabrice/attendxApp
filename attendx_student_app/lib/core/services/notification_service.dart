import 'package:firebase_messaging/firebase_messaging.dart';
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

  /// Call once from main() — after initialize().
  /// Sets up FCM permission + foreground/tap listeners.
  static Future<void> setupFcmListeners() async {
    // Request permission (Android 13+, iOS)
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Show notification while app is in FOREGROUND
    FirebaseMessaging.onMessage.listen((message) {
      showFromFcm(message);
    });

    // App was in BACKGROUND and user tapped the notification
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _routeFromData(message.data);
    });

    // App was fully CLOSED and user tapped the notification
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _routeFromData(initial.data);
    }
  }

  /// Shows a local notification from an FCM RemoteMessage.
  /// Called for foreground AND background (from the top-level handler).
  static Future<void> showFromFcm(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;
    final channelId = message.data['channel'] as String? ?? 'attendx_main';
    final payload   = message.data['route']   as String? ?? 'dashboard';
    await _plugin.show(
      id: message.hashCode,
      title: n.title,
      body: n.body,
      notificationDetails: _details(channelId: channelId),
      payload: payload,
    );
  }

  static void _routeFromData(Map<String, dynamic> data) {
    final route = data['route'] as String? ?? 'dashboard';
    navigatorKey?.currentState?.pushNamed('/$route');
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
