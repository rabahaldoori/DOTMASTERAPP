import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'core/theme.dart';
import 'core/router.dart';
import 'core/api_client.dart';

const _kOneSignalAppId = 'eecc27a7-0556-4f6f-a17c-73a6a34c467e';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize API client with JWT interceptor
  ApiClient.init();

  // ── OneSignal Push Notifications ────────────────────────────────────────
  OneSignal.Debug.setLogLevel(OSLogLevel.none);      // disable verbose logs in prod
  OneSignal.initialize(_kOneSignalAppId);

  // Request permission (iOS will show native prompt; Android 13+ too)
  OneSignal.Notifications.requestPermission(true);

  // When user logs in, tag them with their role & company for targeted pushes
  OneSignal.Notifications.addClickListener((event) {
    // Additional click handling can go here
    debugPrint('🔔 OneSignal notification clicked: ${event.notification.title}');
  });

  runApp(const IFTATrackApp());
}

class IFTATrackApp extends StatelessWidget {
  const IFTATrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'IFTATrack',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
