# 🔐 Biometric Authentication — Full Implementation Guide
> **Project:** DOT Master (DOTMASTERAPP)  
> **Stack:** Flutter + Django REST Framework + SimpleJWT  
> **Last updated:** May 2026

---

## Table of Contents
1. [How It Works — Overview](#1-how-it-works--overview)
2. [The Token Architecture](#2-the-token-architecture)
3. [Session Flow (Password Login)](#3-session-flow-password-login)
4. [Biometric Enrollment Flow](#4-biometric-enrollment-flow)
5. [Biometric Login Flow](#5-biometric-login-flow)
6. [Token Rotation & Sync](#6-token-rotation--sync)
7. [Logout Behavior](#7-logout-behavior)
8. [Files & Where Everything Lives](#8-files--where-everything-lives)
9. [Setup Guide for a New Project](#9-setup-guide-for-a-new-project)
10. [iOS & Android Configuration](#10-ios--android-configuration)
11. [Common Mistakes & Gotchas](#11-common-mistakes--gotchas)

---

## 1. How It Works — Overview

The app uses a **banking-style biometric architecture**:

- There are **two separate refresh tokens**: one for the active session, one dedicated to biometrics.
- The **biometric refresh token** is stored in `FlutterSecureStorage` with `first_unlock_this_device` accessibility — it **survives logout**.
- After a normal logout, when the user reopens the app, the **Face ID / Fingerprint button** appears automatically if they previously enrolled.
- Tapping the button triggers the OS biometric prompt, then silently exchanges the stored biometric token for a fresh access token — no password needed.

```
┌─────────────────────────────────────────────────────┐
│                   LOGIN SCREEN                       │
│                                                      │
│  [Email]  [Password]   [Face ID Button] ← appears   │
│                          only if enrolled            │
│  [Sign In →]                                         │
└─────────────────────────────────────────────────────┘
         │                        │
         ▼ password login         ▼ biometric login
   POST /api/auth/login      local_auth.authenticate()
         │                        │
         ▼                        ▼
   saves access +           reads biometric_refresh_token
   refresh tokens           from FlutterSecureStorage
         │                        │
         ▼                        ▼
   prompt enrollment         POST /api/auth/refresh/
   (first time only)              │
         │                        ▼
         ▼                   new access token saved
   BiometricService.enable()      │
         │                        ▼
   stores biometric_refresh_token navigate to dashboard
   in FlutterSecureStorage
```

---

## 2. The Token Architecture

### Two separate refresh tokens

| Token | Storage | Survives logout? | Used for |
|-------|---------|-----------------|----------|
| `access_token` | `FlutterSecureStorage` (default) | ❌ Cleared on logout | Every API call via `Authorization: Bearer` header |
| `refresh_token` | `FlutterSecureStorage` (default) | ❌ Cleared on logout | Silent session refresh via interceptor |
| `biometric_refresh_token` | `FlutterSecureStorage` (`first_unlock_this_device`) | ✅ Persists after logout | Biometric re-login |

### Why two refresh tokens?

If you only had one refresh token and cleared it on logout, biometric login would fail because there is nothing to exchange for a new access token. By keeping a **dedicated biometric token** that is never cleared on logout, Face ID works exactly like a banking app.

---

## 3. Session Flow (Password Login)

```
User types email + password
        │
        ▼
POST /api/auth/login/
  body: { username, password }
        │
        ▼
Django returns:
  { access: "JWT...", refresh: "JWT...", user: {...} }
        │
        ├── save access_token  → FlutterSecureStorage
        ├── save refresh_token → FlutterSecureStorage  
        ├── save user JSON     → SharedPreferences
        └── OneSignal.login(userId)
        │
        ▼
_promptFaceIdEnrollment() called
  (only if not yet enrolled — checked via SharedPreferences)
        │
        ▼
context.go('/dashboard') or '/driver-dashboard'
```

### Session Persistence (app restart)

On app startup (`main.dart` / router), the app:
1. Reads `access_token` from secure storage
2. If present → restores user from `SharedPreferences` → goes to dashboard
3. If missing → goes to login screen
4. The API interceptor automatically calls `/api/auth/refresh/` when it gets a 401

---

## 4. Biometric Enrollment Flow

Called automatically after **first successful password login**.

```dart
// login_screen.dart — called after successful login
await _promptFaceIdEnrollment(email, refreshToken);
```

```
_promptFaceIdEnrollment(email, refreshToken)
        │
        ▼
BiometricService.wasAsked() → SharedPreferences 'biometric_asked'
  if true → return early (don't ask again)
        │
        ▼
BiometricService.isEnabled() → SharedPreferences 'biometric_enabled'
  if true → return early (already enrolled)  
        │
        ▼
LocalAuthentication.isDeviceSupported()
LocalAuthentication.canCheckBiometrics()
  if device has no biometrics → return early
        │
        ▼
showDialog → "Enable Face ID / Fingerprint?"
  [Enable]   [Not Now]
        │
   ┌────┴────┐
   ▼         ▼
Enable      Not Now
   │         │
   ▼         ▼
BiometricService.enable(email, refreshToken)
   │        set 'biometric_asked' = true
   ▼        return
LocalAuthentication.authenticate()
  (OS shows Face ID / fingerprint prompt)
   │
   ▼
FlutterSecureStorage.write('biometric_username', email)
FlutterSecureStorage.write('biometric_refresh_token', refreshToken)
SharedPreferences.set('biometric_enabled', true)
SharedPreferences.set('biometric_asked', true)
   │
   ▼
print('✅ Biometric enabled — username & refresh token stored')
```

> **Key**: `biometric_asked` is in `SharedPreferences` (persists reinstalls). `biometric_enabled` is also in `SharedPreferences`. The actual tokens are in `FlutterSecureStorage` with `first_unlock_this_device`.

---

## 5. Biometric Login Flow

```
App opens → LoginScreen._initBiometric()
        │
        ▼
BiometricService.canAuthenticate()
  checks:
    1. SharedPreferences 'biometric_enabled' == true
    2. FlutterSecureStorage 'biometric_username' != null
    3. FlutterSecureStorage 'biometric_refresh_token' != null
        │
   ┌────┴────┐
   ▼         ▼
 false      true
   │         │
   ▼         ▼
button      _bioVisible = true → show Face ID button
hidden      
        │
        ▼ user taps Face ID button
_biometricLogin()
        │
        ▼
LocalAuthentication.authenticate()
  reason: 'Sign in to DOT Master'
        │
        ▼
BiometricService.getStoredRefreshToken()
  → reads 'biometric_refresh_token' from FlutterSecureStorage
        │
        ▼
ApiClient.refreshWithToken(bioToken)
  POST /api/auth/refresh/
  body: { refresh: bioToken }
        │
        ▼
Django returns new { access, refresh }
        │
        ├── save new access_token  → FlutterSecureStorage
        ├── save new refresh_token → FlutterSecureStorage (session)
        └── BiometricService.syncRefreshToken(newRefresh)
              → overwrites 'biometric_refresh_token' with new token
        │
        ▼
ApiClient.getProfile() → restore user object
        │
        ▼
OneSignal.login(userId)
        │
        ▼
context.go('/dashboard') or '/driver-dashboard' based on role
```

---

## 6. Token Rotation & Sync

Django's `ROTATE_REFRESH_TOKENS = True` means **every time you use a refresh token, you get a new one back** and the old one is blacklisted.

This means: if the biometric token is used and a new one comes back, you must **immediately save the new one** or the next biometric login will fail with 401.

### Where sync happens

**1. After biometric login** (`login_screen.dart`):
```dart
final newRefresh = res.data['refresh'] as String?;
if (newRefresh != null) {
  await _bio.syncRefreshToken(newRefresh);
}
```

**2. After interceptor silent refresh** (`api_client.dart`):
```dart
// _refreshToken() — called automatically on 401
if (newRefresh != null) {
  await _storage.write(key: 'refresh_token', value: newRefresh);
  await BiometricService().syncRefreshToken(newRefresh); // ← critical
}
```

`syncRefreshToken` just writes to secure storage:
```dart
Future<void> syncRefreshToken(String newToken) async {
  if (!await isEnabled()) return; // don't sync if biometric not enabled
  await _storage.write(key: _kRefreshToken, value: newToken);
}
```

---

## 7. Logout Behavior

```dart
// Logout clears session tokens but NOT biometric token
await storage.delete(key: 'access_token');
await storage.delete(key: 'refresh_token');
await prefs.remove('user_data');
// DO NOT delete 'biometric_refresh_token'
// DO NOT delete 'biometric_enabled' 
```

After logout:
- User sees login screen
- Biometric button **still appears** (because `biometric_enabled` and `biometric_refresh_token` are intact)
- User taps Face ID → authenticated instantly without password

To **fully disable biometrics** (e.g., from Profile settings):
```dart
await BiometricService().disable();
// disable() clears: biometric_username, biometric_refresh_token,
// biometric_enabled, biometric_asked from their respective stores
```

---

## 8. Files & Where Everything Lives

```
lib/
├── core/
│   ├── biometric_service.dart      ← all biometric logic (enable/disable/auth)
│   └── api_client.dart             ← refreshWithToken(), _refreshToken() with sync
└── features/
    └── auth/
        └── login_screen.dart       ← _initBiometric(), _biometricLogin(),
                                       _promptFaceIdEnrollment()
```

### `biometric_service.dart` — key methods

| Method | Description |
|--------|-------------|
| `canAuthenticate()` | Returns true if device supports biometrics AND user is enrolled |
| `enable(username, refreshToken)` | Triggers OS prompt, stores credentials |
| `disable()` | Clears all biometric state |
| `authenticate(reason)` | Triggers OS biometric prompt, returns bool |
| `getStoredRefreshToken()` | Reads `biometric_refresh_token` from secure storage |
| `getStoredUsername()` | Reads `biometric_username` from secure storage |
| `syncRefreshToken(newToken)` | Updates stored token after rotation |
| `isEnabled()` | Reads `biometric_enabled` from SharedPreferences |
| `wasAsked()` | Reads `biometric_asked` from SharedPreferences |

### `api_client.dart` — key methods

| Method | Description |
|--------|-------------|
| `refreshWithToken(token)` | Exchanges specific token for new access token |
| `_refreshToken()` | Internal interceptor refresh — also syncs biometric token |
| `saveTokens(access, refresh)` | Saves both tokens to secure storage |
| `clearTokens()` | Clears session tokens (NOT biometric token) |

---

## 9. Setup Guide for a New Project

### Step 1 — Add dependencies

```yaml
# pubspec.yaml
dependencies:
  local_auth: ^2.3.0
  flutter_secure_storage: ^9.2.2
  shared_preferences: ^2.3.3
```

### Step 2 — Copy `biometric_service.dart`

Copy `lib/core/biometric_service.dart` from this project. Key storage config:

```dart
static const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
    // ^ CRITICAL: persists across logout, does NOT persist across app uninstall
  ),
);

// Keys
static const _kUsername     = 'biometric_username';
static const _kRefreshToken = 'biometric_refresh_token';

// SharedPreferences keys (persist across reinstalls)
static const _kEnabled = 'biometric_enabled';
static const _kAsked   = 'biometric_asked';
```

> **Why two storage systems?**  
> - `FlutterSecureStorage` for sensitive data (tokens) — encrypted keychain  
> - `SharedPreferences` for flags (enabled/asked) — survives reinstalls in debug, always survives logout

### Step 3 — Add `refreshWithToken` to your API client

```dart
static Future<bool> refreshWithToken(String refreshToken) async {
  try {
    final res = await Dio().post(
      ApiEndpoints.refreshToken, // use YOUR actual refresh endpoint URL
      data: {'refresh': refreshToken},
    );
    if (res.statusCode == 200) {
      final newAccess  = res.data['access']  as String?;
      final newRefresh = res.data['refresh'] as String?;
      if (newAccess != null) {
        await _storage.write(key: 'access_token', value: newAccess);
        _dio.options.headers['Authorization'] = 'Bearer $newAccess';
      }
      if (newRefresh != null) {
        await _storage.write(key: 'refresh_token', value: newRefresh);
        await BiometricService().syncRefreshToken(newRefresh);
      }
      return true;
    }
    return false;
  } catch (e) {
    debugPrint('❌ refreshWithToken failed: $e');
    return false;
  }
}
```

### Step 4 — Add sync to your interceptor's `_refreshToken()`

```dart
static Future<bool> _refreshToken() async {
  try {
    final refresh = await _storage.read(key: 'refresh_token');
    if (refresh == null) return false;
    final res = await Dio().post(ApiEndpoints.refreshToken,
        data: {'refresh': refresh});
    if (res.statusCode == 200) {
      final newAccess  = res.data['access']  as String?;
      final newRefresh = res.data['refresh'] as String?;
      if (newAccess != null) {
        await _storage.write(key: 'access_token', value: newAccess);
        _dio.options.headers['Authorization'] = 'Bearer $newAccess';
      }
      if (newRefresh != null) {
        await _storage.write(key: 'refresh_token', value: newRefresh);
        await BiometricService().syncRefreshToken(newRefresh); // ← add this
      }
      return true;
    }
  } catch (_) {}
  return false;
}
```

### Step 5 — Wire up LoginScreen

```dart
// State vars
bool _bioVisible = false;
bool _bioLoading = false;
final _bio = BiometricService();

@override
void initState() {
  super.initState();
  _initBiometric();
}

Future<void> _initBiometric() async {
  final ok = await _bio.canAuthenticate();
  if (mounted) setState(() => _bioVisible = ok);
}

// After successful password login
Future<void> _onLoginSuccess(String email, String refreshToken) async {
  // ... save tokens, restore user ...
  await _promptFaceIdEnrollment(email, refreshToken);
  // ... navigate ...
}

Future<void> _promptFaceIdEnrollment(String email, String refreshToken) async {
  if (await _bio.wasAsked()) return;
  if (await _bio.isEnabled()) return;
  if (!await LocalAuthentication().isDeviceSupported()) return;
  if (!await LocalAuthentication().canCheckBiometrics()) return;

  final enabled = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Enable Face ID?'),
      content: const Text('Sign in instantly next time.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not Now')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enable')),
      ],
    ),
  );

  if (enabled == true) {
    final success = await _bio.enable(email, refreshToken);
    if (success && mounted) setState(() => _bioVisible = true);
  }
}

Future<void> _biometricLogin() async {
  setState(() { _bioLoading = true; _error = null; });
  final token = await _bio.getStoredRefreshToken();
  if (token == null) {
    setState(() { _bioLoading = false; _bioVisible = false; });
    return;
  }
  final authenticated = await _bio.authenticate(reason: 'Sign in to your account');
  if (!authenticated) { setState(() => _bioLoading = false); return; }
  
  final refreshed = await ApiClient.refreshWithToken(token);
  if (!refreshed) {
    setState(() { _bioLoading = false; _bioVisible = false; _error = 'Session expired.'; });
    return;
  }
  // restore user profile, navigate to dashboard...
}
```

### Step 6 — Show the button in UI

```dart
if (_bioVisible)
  IconButton(
    icon: const Icon(Icons.fingerprint), // or Icons.face
    onPressed: _bioLoading ? null : _biometricLogin,
  ),
```

---

## 10. iOS & Android Configuration

### iOS

**`ios/Runner/Info.plist`** — add usage description:
```xml
<key>NSFaceIDUsageDescription</key>
<string>Sign in securely with Face ID</string>
```

**`ios/Podfile`** — minimum iOS version:
```ruby
platform :ios, '13.0'
```

### Android

**`android/app/src/main/AndroidManifest.xml`** — add permission:
```xml
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
```

**`android/app/build.gradle`** — minimum SDK:
```gradle
minSdkVersion 23
```

---

## 11. Common Mistakes & Gotchas

### ❌ Wrong refresh endpoint URL
```dart
// WRONG — hardcoded Django SimpleJWT default
'/api/token/refresh/'

// CORRECT — use your actual endpoint constant
ApiEndpoints.refreshToken  // e.g. '/api/auth/refresh/'
```

### ❌ Not syncing biometric token after rotation
If Django has `ROTATE_REFRESH_TOKENS = True`, every refresh returns a new token. If you don't call `syncRefreshToken()` after BOTH the interceptor refresh AND biometric login, the stored token becomes stale and biometric fails on next launch.

### ❌ Using `Navigator.pop(context, ...)` in `useRootNavigator: true` sheets
```dart
// WRONG — closes the wrong navigator
onTap: () => Navigator.pop(context, ImageSource.camera)

// CORRECT — matches the root navigator used to show the sheet
onTap: () => Navigator.of(ctx, rootNavigator: true).pop(ImageSource.camera)
```

### ❌ Clearing biometric token on logout
The whole point of the architecture is that the biometric token SURVIVES logout. Only clear `access_token` and `refresh_token` on logout.

### ❌ Hardcoded bottom spacer hiding buttons
```dart
// WRONG — doesn't account for home indicator + nav bar
const SizedBox(height: 80)

// CORRECT
SizedBox(height: 80 + MediaQuery.of(context).padding.bottom)
```

### ❌ Bottom sheets sitting behind the nav bar
```dart
// WRONG
showModalBottomSheet(context: context, ...)

// CORRECT — renders above shell route nav bars
showModalBottomSheet(
  context: context,
  useRootNavigator: true,
  useSafeArea: true,
  ...
)
```

### ❌ Keyboard not dismissing on tap outside
```dart
// WRONG — Form/ListView alone doesn't dismiss keyboard
body: Form(...)

// CORRECT
body: GestureDetector(
  behavior: HitTestBehavior.opaque,
  onTap: () => FocusScope.of(context).unfocus(),
  child: Form(...),
)
```

---

## Session Summary

| Scenario | What happens |
|----------|-------------|
| First login | Password auth → enrollment dialog → biometric token stored |
| Subsequent login with password | Password auth → enrollment skipped (already asked) |
| App restart with valid session | Access token found → go straight to dashboard |
| App restart with expired session | 401 → interceptor calls refresh → if refresh expired → login screen |
| Login screen opened, biometric enrolled | Face ID button shows automatically |
| Tap Face ID button | OS prompt → exchange biometric token → dashboard |
| Logout | Session tokens cleared, biometric token preserved |
| After logout → reopen app | Login screen shows Face ID button → works without password |
| Token rotation | Interceptor saves new refresh token AND syncs biometric token |
| Biometric token expired (days of inactivity) | Face ID fails → "Session expired" message → user must re-login with password → re-enrolls automatically |
