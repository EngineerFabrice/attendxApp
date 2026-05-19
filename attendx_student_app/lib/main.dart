import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'core/services/notification_service.dart';
import 'core/services/offline_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService.initialize();
  await OfflineSyncService.instance.start();

  // Firebase.initializeApp() requires google-services.json — enable when deploying
  // await Firebase.initializeApp();

  runApp(
    const ProviderScope(
      child: AttendXApp(),
    ),
  );
}
