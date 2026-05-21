import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'core/services/notification_service.dart';
import 'core/services/offline_sync_service.dart';

/// MUST be a top-level function — Flutter runs this in a separate isolate
/// when the app is closed or in the background.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await NotificationService.initialize();
  await NotificationService.showFromFcm(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  // Register background handler BEFORE runApp
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await NotificationService.initialize();
  await NotificationService.setupFcmListeners();
  await OfflineSyncService.instance.start();

  runApp(
    const ProviderScope(
      child: AttendXApp(),
    ),
  );
}
