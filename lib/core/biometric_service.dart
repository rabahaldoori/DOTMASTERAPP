import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Biometric authentication service — mirrors fly365_mobile architecture.
///
/// KEY DESIGN: Stores a dedicated `biometric_refresh_token` separately from
/// the session token. This means Face ID / Fingerprint works AFTER logout,
/// just like banking apps.
class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isAuthenticating = false;

  // Secure storage with iOS Keychain settings that persist across reinstalls
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Storage keys
  static const _kEnabled       = 'biometric_enabled';       // SharedPreferences bool
  static const _kUsername      = 'biometric_username';      // SecureStorage
  static const _kRefreshToken  = 'biometric_refresh_token'; // SecureStorage — survives logout
  static const _kAsked         = 'biometric_asked';         // SharedPreferences bool

  // ── Availability ────────────────────────────────────────────────────────────

  Future<bool> isAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics && await _localAuth.isDeviceSupported();
    } catch (_) { return false; }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try { return await _localAuth.getAvailableBiometrics(); } catch (_) { return []; }
  }

  String getBiometricName(List<BiometricType> types) {
    if (types.contains(BiometricType.face))        return 'Face ID';
    if (types.contains(BiometricType.fingerprint)) return 'Fingerprint';
    if (types.contains(BiometricType.strong) || types.contains(BiometricType.weak))
      return 'Biometric Authentication';
    return 'Biometric Authentication';
  }

  // ── Preferences ─────────────────────────────────────────────────────────────

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEnabled) ?? false;
  }

  Future<bool> wasAsked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAsked) ?? false;
  }

  Future<void> markAsked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAsked, true);
  }

  // ── Enable / Disable ────────────────────────────────────────────────────────

  /// Enable biometrics: verifies hardware works, then stores username +
  /// a dedicated refresh token (never stores password).
  Future<bool> enable(String username, String refreshToken) async {
    try {
      // Verify biometric hardware actually works before storing anything
      final ok = await authenticate(reason: 'Enable biometric login');
      if (!ok) return false;

      await _storage.write(key: _kUsername,     value: username);
      await _storage.write(key: _kRefreshToken, value: refreshToken);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnabled, true);
      await prefs.setBool(_kAsked, true);

      debugPrint('✅ Biometric enabled — username & refresh token stored');
      return true;
    } catch (e) {
      debugPrint('❌ Error enabling biometric: $e');
      return false;
    }
  }

  /// Disable biometrics and clear all stored biometric data.
  Future<void> disable() async {
    await _storage.delete(key: _kUsername);
    await _storage.delete(key: _kRefreshToken);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, false);
    debugPrint('✅ Biometric disabled and data cleared');
  }

  /// Update the stored biometric refresh token after token rotation.
  /// Must be called after every successful token refresh.
  Future<void> syncRefreshToken(String newRefreshToken) async {
    if (!await isEnabled()) return;
    try {
      await _storage.write(key: _kRefreshToken, value: newRefreshToken);
      debugPrint('✅ Biometric refresh token synced');
    } catch (e) {
      debugPrint('❌ Failed to sync biometric refresh token: $e');
    }
  }

  // ── Authenticate ────────────────────────────────────────────────────────────

  Future<bool> authenticate({required String reason}) async {
    if (_isAuthenticating) return false;
    _isAuthenticating = true;
    try {
      if (!await isAvailable()) return false;
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('❌ Biometric PlatformException: ${e.code} — ${e.message}');
      return false;
    } catch (e) {
      debugPrint('❌ Biometric error: $e');
      return false;
    } finally {
      _isAuthenticating = false;
    }
  }

  // ── Session helpers ──────────────────────────────────────────────────────────

  Future<String?> getStoredUsername() => _storage.read(key: _kUsername);
  Future<String?> getStoredRefreshToken() => _storage.read(key: _kRefreshToken);

  /// Returns true only if biometric is enabled AND a biometric refresh token exists.
  /// The token survives logout so the button stays visible.
  Future<bool> canAuthenticate() async {
    if (!await isEnabled()) return false;
    final username = await getStoredUsername();
    if (username == null) return false;
    final token = await getStoredRefreshToken();
    return token != null;
  }
}
