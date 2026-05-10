import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'core/router.dart';
import 'core/api_client.dart';
import 'core/l10n/locale_provider.dart';

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

  // ── Stripe (publishable key set at runtime from /api/company/stripe/payment-sheet/) ──
  Stripe.publishableKey = const String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue: 'pk_test_placeholder',   // overridden at checkout time
  );
  await Stripe.instance.applySettings();

  // ── OneSignal Push Notifications ────────────────────────────────────────
  OneSignal.Debug.setLogLevel(OSLogLevel.none);
  OneSignal.initialize(_kOneSignalAppId);
  OneSignal.Notifications.requestPermission(true);

  OneSignal.Notifications.addClickListener((event) {
    debugPrint('🔔 OneSignal notification clicked: ${event.notification.title}');
  });

  runApp(
    ChangeNotifierProvider(
      create: (_) => LocaleProvider(),
      child: const IFTATrackApp(),
    ),
  );
}

class IFTATrackApp extends StatelessWidget {
  const IFTATrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();

    return MaterialApp.router(
      title: 'DOT Master',
      debugShowCheckedModeBanner: false,
      theme: localeProvider.locale.languageCode == 'ar'
          ? AppTheme.arabic
          : AppTheme.light,
      routerConfig: router,

      // ── Localization ──────────────────────────────────────────────────────
      locale: localeProvider.locale,
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('ar', 'SA'),
        Locale('es', 'ES'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
