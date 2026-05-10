import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_strings.dart';
import 'language_en.dart';
import 'language_ar.dart';
import 'language_es.dart';

/// Supported language codes
enum AppLanguage { en, ar, es }

extension AppLanguageExtension on AppLanguage {
  String get code => name; // 'en', 'ar', 'es'

  Locale get locale {
    switch (this) {
      case AppLanguage.ar: return const Locale('ar', 'SA');
      case AppLanguage.es: return const Locale('es', 'ES');
      case AppLanguage.en:
      default:             return const Locale('en', 'US');
    }
  }

  AppStrings get strings {
    switch (this) {
      case AppLanguage.ar: return const LanguageAr();
      case AppLanguage.es: return const LanguageEs();
      case AppLanguage.en:
      default:             return const LanguageEn();
    }
  }

  String get displayName {
    switch (this) {
      case AppLanguage.ar: return 'العربية';
      case AppLanguage.es: return 'Español';
      case AppLanguage.en:
      default:             return 'English';
    }
  }

  String get flagEmoji {
    switch (this) {
      case AppLanguage.ar: return '🇸🇦';
      case AppLanguage.es: return '🇪🇸';
      case AppLanguage.en:
      default:             return '🇺🇸';
    }
  }
}

/// ChangeNotifier that drives MaterialApp locale and provides strings.
/// Wrap MaterialApp with ChangeNotifierProvider<LocaleProvider> in main.dart.
class LocaleProvider extends ChangeNotifier {
  static const _prefKey = 'app_language';

  AppLanguage _language = AppLanguage.en;

  AppLanguage get language => _language;
  Locale      get locale  => _language.locale;
  AppStrings  get strings => _language.strings;

  LocaleProvider() { _loadSaved(); }

  /// Shorthand used in widgets: context.read<LocaleProvider>().s.appName
  AppStrings get s => strings;

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null) {
      _language = AppLanguage.values.firstWhere(
          (l) => l.code == saved, orElse: () => AppLanguage.en);
      notifyListeners();
    }
  }

  Future<void> setLanguage(AppLanguage lang) async {
    if (_language == lang) return;
    _language = lang;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, lang.code);
  }
}

/// Convenience helper — use anywhere you have a BuildContext.
///   final s = AppL10n.of(context);  // returns AppStrings
class AppL10n {
  static AppStrings of(BuildContext context) {
    return _LocaleProviderInheritedWidget.of(context);
  }
}

// ---------------------------------------------------------------------------
// Internal InheritedWidget so we don't always need to import provider.
// (The ChangeNotifierProvider approach is recommended; this is a fallback.)
// ---------------------------------------------------------------------------
class _LocaleProviderInheritedWidget extends InheritedWidget {
  final LocaleProvider provider;
  const _LocaleProviderInheritedWidget({
    required this.provider,
    required super.child,
  });

  static AppStrings of(BuildContext context) {
    final widget = context
        .dependOnInheritedWidgetOfExactType<_LocaleProviderInheritedWidget>();
    return widget?.provider.strings ?? const LanguageEn();
  }

  @override
  bool updateShouldNotify(_LocaleProviderInheritedWidget old) =>
      old.provider.language != provider.language;
}
