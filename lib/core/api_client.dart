import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import 'biometric_service.dart';

class ApiClient {
  static const _storage = FlutterSecureStorage();

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl, // ← pulled from utils/constants.dart
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  /// Public accessor for generic requests (e.g. maintenance screen).
  static Dio get dio => _dio;

  static void init() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          final refreshed = await _refreshToken();
          if (refreshed) {
            final token = await _storage.read(key: 'access_token');
            error.requestOptions.headers['Authorization'] = 'Bearer $token';
            final response = await _dio.fetch(error.requestOptions);
            return handler.resolve(response);
          }
        }
        return handler.next(error);
      },
    ));
  }

  // ── Internal token refresh ────────────────────────────────────────────────
  static Future<bool> _refreshToken() async {
    try {
      final refresh = await _storage.read(key: 'refresh_token');
      if (refresh == null) return false;
      final res = await Dio().post(
        ApiEndpoints.refreshToken,
        data: {'refresh': refresh},
      );
      if (res.statusCode == 200) {
        final newAccess   = res.data['access']   as String?;
        final newRefresh  = res.data['refresh']  as String?;  // may be null if no rotation
        if (newAccess != null) {
          await _storage.write(key: 'access_token', value: newAccess);
          _dio.options.headers['Authorization'] = 'Bearer $newAccess';
        }
        if (newRefresh != null) {
          // Persist rotated refresh token so the next silent refresh works
          await _storage.write(key: 'refresh_token', value: newRefresh);
          // Keep biometric token in sync — prevents stale token on Face ID / fingerprint login
          await BiometricService().syncRefreshToken(newRefresh);
        }
        return true;
      }
    } catch (_) {}
    return false;
  }

  // ── Auth ──────────────────────────────────────────────────────────────────
  static Future<Response> login(String email, String password) =>
      _dio.post(ApiEndpoints.login, data: {'email': email, 'password': password});

  /// Register a new user + company.
  /// Backend: POST /api/auth/register/
  /// Fields: email, first_name, last_name, phone, password, password2, company_name
  static Future<Response> register({
    required String email,
    required String firstName,
    required String lastName,
    required String phone,
    required String password,
    required String password2,
    required String companyName,
  }) =>
      _dio.post(ApiEndpoints.register, data: {
        'email':        email,
        'first_name':   firstName,
        'last_name':    lastName,
        'phone':        phone,
        'password':     password,
        'password2':    password2,
        'company_name': companyName,
      });

  static Future<Response> getProfile() => _dio.get(ApiEndpoints.me);

  static Future<Response> forgotPassword(String email) =>
      _dio.post(ApiEndpoints.forgotPassword, data: {'email': email});

  static Future<Response> resetPassword(String token, String newPassword) =>
      _dio.post(ApiEndpoints.resetPassword, data: {'token': token, 'new_password': newPassword});

  // ── Drivers ───────────────────────────────────────────────────────────────
  static Future<Response> getDrivers() => _dio.get(ApiEndpoints.drivers);
  static Future<Response> hireDriver(Map<String, dynamic> data) =>
      _dio.post(ApiEndpoints.hireDriver, data: data);

  static Future<Response> adminResetDriverPassword(int driverId, String newPassword) =>
      _dio.post(ApiEndpoints.driverResetPassword(driverId), data: {'new_password': newPassword});

  // ── Trucks ────────────────────────────────────────────────────────────────
  static Future<Response> getTrucks() => _dio.get(ApiEndpoints.trucks);
  static Future<Response> createTruck(Map<String, dynamic> data) =>
      _dio.post(ApiEndpoints.trucks, data: data);
  static Future<Response> updateTruck(int id, Map<String, dynamic> data) =>
      _dio.patch(ApiEndpoints.truckDetail(id), data: data);
  static Future<Response> deleteTruck(int id) =>
      _dio.delete(ApiEndpoints.truckDetail(id));

  // ── Trips ─────────────────────────────────────────────────────────────────
  static Future<Response> getTrips({int page = 1, String? status}) => _dio.get(
        ApiEndpoints.trips,
        queryParameters: {
          'page': page,
          'page_size': AppConfig.tripsPageSize,
          if (status != null) 'status': status,
        },
      );

  /// Fetch route data (state miles, duration, polyline) from Django.
  /// Set [avoidTolls] or [avoidHighways] to get alternative routes.
  static Future<Response> calculateRoute({
    required String origin,
    required String destination,
    List<String> stops = const [],
    bool avoidTolls    = false,
    bool avoidHighways = false,
  }) => _dio.post(ApiEndpoints.calculateRoute, data: {
        'origin':        origin,
        'destination':   destination,
        'stops':         stops,
        'avoid_tolls':   avoidTolls,
        'avoid_highways': avoidHighways,
      });

  /// Update a trip's status and optionally its route data (for start-trip flow).
  static Future<Response> updateTrip(int id, Map<String, dynamic> data) =>
      _dio.patch(ApiEndpoints.tripDetail(id), data: data);

  /// Fetch full details of a single trip by ID.
  static Future<Response> getTripById(int id) =>
      _dio.get(ApiEndpoints.tripDetail(id));

  // ── Fuel Purchases ────────────────────────────────────────────────────────
  static Future<Response> getFuelLogs({int page = 1, String? search}) => _dio.get(
        ApiEndpoints.fuelPurchases,
        queryParameters: {
          'page': page,
          'page_size': AppConfig.fuelPageSize,
          if (search != null) 'search': search,
        },
      );

  static Future<Response> logFuelFromDevice(Map<String, dynamic> data) =>
      _dio.post(ApiEndpoints.logFuelFromDevice, data: data);

  static Future<Response> uploadFuelReceipt(int id, String filePath) async {
    final formData = FormData.fromMap({
      'receipt': await MultipartFile.fromFile(filePath),
    });
    return _dio.post(ApiEndpoints.fuelReceipt(id), data: formData);
  }

  // ── Dashboard ─────────────────────────────────────────────────────────────
  static Future<Response> getDashboardSummary() => _dio.get(ApiEndpoints.dashboardSummary);
  static Future<Response> getIftaCurrentQuarter() => _dio.get(ApiEndpoints.dashboardIftaCurrent);
  static Future<Response> getDashboardCharts() => _dio.get(ApiEndpoints.dashboardCharts);

  // ── IFTA Reports ──────────────────────────────────────────────────────────
  static Future<Response> getIftaReports() => _dio.get(ApiEndpoints.iftaReports);

  static Future<Response> getIftaReportDetail(int id) =>
      _dio.get(ApiEndpoints.iftaReportDetail(id));

  static Future<Response> downloadIftaReportPdf(int id) =>
      _dio.get(ApiEndpoints.iftaReportExport(id, 'pdf'),
          options: Options(responseType: ResponseType.bytes));

  static Future<Response> downloadIftaReportCsv(int id) =>
      _dio.get(ApiEndpoints.iftaReportExport(id, 'csv'),
          options: Options(responseType: ResponseType.bytes));

  static Future<Response> getAvailableQuarters() =>
      _dio.get(ApiEndpoints.iftaQuarters);

  static Future<Response> generateIftaReport(Map<String, dynamic> data) =>
      _dio.post(ApiEndpoints.iftaGenerate, data: data);

  static Future<Response> deleteIftaReport(int id) =>
      _dio.delete(ApiEndpoints.iftaReportDetail(id));

  // ── Documents ─────────────────────────────────────────────────────────────
  static Future<Response> getDocuments({int? pageSize}) => _dio.get(
        ApiEndpoints.documents,
        queryParameters: {'page_size': pageSize ?? AppConfig.documentsPageSize},
      );

  static Future<Response> uploadDocument(Map<String, dynamic> fields, String filePath) async {
    final formData = FormData.fromMap({
      ...fields,
      'file': await MultipartFile.fromFile(filePath, filename: filePath.split('/').last),
    });
    return _dio.post(
      ApiEndpoints.documents,
      data: formData,
      options: Options(headers: {'Content-Type': 'multipart/form-data'}),
    );
  }

  // ── Driver Self-Service ──────────────────────────────────────────────────────
  /// Returns the logged-in driver's own profile, trips, fuel logs, and documents.
  static Future<Response> getDriverData() => _dio.get('/api/auth/me/driver-data/');

  /// Upload profile photo for a driver (drivers call with their own profile ID).
  static Future<Response> uploadDriverPhoto(int profileId, String imagePath) async {
    final formData = FormData.fromMap({
      'photo': await MultipartFile.fromFile(imagePath,
          filename: imagePath.split('/').last),
    });
    return _dio.post(
      '/api/drivers/$profileId/photo/',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  // ── Secure storage helpers ─────────────────────────────────────────────────
  static Future<void> saveTokens(String access, String refresh) async {
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
  }

  static Future<void> saveUser(Map<String, dynamic> user) async {
    await _storage.write(key: 'user_name', value: user['full_name'] ?? user['username'] ?? '');
    await _storage.write(key: 'user_email', value: user['email'] ?? '');
    await _storage.write(key: 'user_role', value: user['role'] ?? 'driver');
    await _storage.write(key: 'company_name', value: user['company_name'] ?? '');
  }

  static Future<Map<String, String?>> getUser() async => {
        'name': await _storage.read(key: 'user_name'),
        'email': await _storage.read(key: 'user_email'),
        'role': await _storage.read(key: 'user_role'),
        'company': await _storage.read(key: 'company_name'),
      };

  static Future<void> logout() async {
    // Only clear auth tokens — biometric prefs (SharedPreferences) are preserved
    await Future.wait([
      _storage.delete(key: 'access_token'),
      _storage.delete(key: 'refresh_token'),
      _storage.delete(key: 'user_name'),
      _storage.delete(key: 'user_email'),
      _storage.delete(key: 'user_role'),
      _storage.delete(key: 'company_name'),
    ]);
  }

  static Future<bool> get isLoggedIn async {
    final token = await _storage.read(key: 'access_token');
    return token != null;
  }

  /// Quick role check — used by router to choose correct shell.
  static Future<String?> getUserRole() => _storage.read(key: 'user_role');

  /// Returns stored refresh token (null if no session saved).
  static Future<String?> getRefreshToken() => _storage.read(key: 'refresh_token');

  /// Refreshes the access token using the stored refresh token.
  static Future<bool> refreshAccessToken() => _refreshToken();

  /// Refreshes the access token using an explicit refresh token.
  /// Used by biometric login to pass the dedicated biometric_refresh_token.
  static Future<bool> refreshWithToken(String refreshToken) async {
    try {
      debugPrint('🔐 refreshWithToken: posting to ${ApiEndpoints.refreshToken}');
      final res = await Dio().post(
        ApiEndpoints.refreshToken,
        data: {'refresh': refreshToken},
      );
      debugPrint('🔐 refreshWithToken: status=${res.statusCode}');
      if (res.statusCode == 200) {
        final newAccess  = res.data['access']  as String?;
        final newRefresh = res.data['refresh'] as String?;
        if (newAccess != null) {
          await _storage.write(key: 'access_token', value: newAccess);
          _dio.options.headers['Authorization'] = 'Bearer $newAccess';
        }
        if (newRefresh != null) {
          await _storage.write(key: 'refresh_token', value: newRefresh);
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ refreshWithToken failed: $e');
      return false;
    }
  }

  // ── Face ID preference (SharedPreferences — persists across debug reinstalls) ─
  static Future<bool> getFaceIdEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('faceid_enabled') ?? false;
  }

  static Future<void> setFaceIdEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('faceid_enabled', value);
  }

  /// Whether the Face ID setup prompt has been shown before.
  static Future<bool> getFaceIdAsked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('faceid_asked') ?? false;
  }

  static Future<void> setFaceIdAsked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('faceid_asked', true);
  }

  // ── Duty / HOS ─────────────────────────────────────────────────────────────
  static Future<Response> getDutyStatus() => _dio.get('/api/duty/status/');

  static Future<Response> startDuty(String status) =>
      _dio.post('/api/duty/start/', data: {'status': status});

  static Future<Response> endDuty() => _dio.post('/api/duty/end/');

  static Future<Response> updateDutyStatus(String status) =>
      _dio.post('/api/duty/update-status/', data: {'status': status});

  static Future<Response> getDutyHistory({int days = 7}) =>
      _dio.get('/api/duty/history/', queryParameters: {'days': days});

  // ── Inspections ────────────────────────────────────────────────────────────
  static Future<Response> submitInspection(Map<String, dynamic> data) =>
      _dio.post('/api/inspections/mobile/submit/', data: data);

  static Future<Response> listInspections() =>
      _dio.get('/api/inspections/mobile/');

  static Future<Response> listAdminInspections({
    int? driverId, int? truckId, String? statusFilter,
  }) =>
      _dio.get('/api/inspections/', queryParameters: {
        if (driverId != null)    'driver': driverId,
        if (truckId != null)     'truck':  truckId,
        if (statusFilter != null) 'status': statusFilter,
      });

  static Future<Response> getTodayInspection({String type = 'pre_trip'}) =>
      _dio.get('/api/inspections/mobile/today/', queryParameters: {'type': type});

  static Future<Response> updateInspection(int id, Map<String, dynamic> data) =>
      _dio.patch('/api/inspections/mobile/$id/edit/', data: data);


  // ── Inspection Checklist Template (admin-managed) ──────────────────────────
  /// Returns the company's custom checklist template (drivers + admins).
  static Future<Response> getInspectionTemplate() =>
      _dio.get('/api/inspections/checklist-template/');

  /// Admin: create a new category in the template.
  static Future<Response> createInspectionCategory(Map<String, dynamic> data) =>
      _dio.post('/api/inspections/checklist-template/categories/', data: data);

  /// Admin: update an existing category.
  static Future<Response> updateInspectionCategory(int id, Map<String, dynamic> data) =>
      _dio.patch('/api/inspections/checklist-template/categories/$id/', data: data);

  /// Admin: delete a category (and all its items).
  static Future<Response> deleteInspectionCategory(int id) =>
      _dio.delete('/api/inspections/checklist-template/categories/$id/');

  /// Admin: add an item to a category.
  static Future<Response> createInspectionItem(Map<String, dynamic> data) =>
      _dio.post('/api/inspections/checklist-template/items/', data: data);

  /// Admin: update an item label.
  static Future<Response> updateInspectionItem(int id, Map<String, dynamic> data) =>
      _dio.patch('/api/inspections/checklist-template/items/$id/', data: data);

  /// Admin: delete an item.
  static Future<Response> deleteInspectionItem(int id) =>
      _dio.delete('/api/inspections/checklist-template/items/$id/');

  // ── Trucks ────────────────────────────────────────────────────────────────────────
  static Future<Response> getTruck(int truckId) =>
      _dio.get(ApiEndpoints.truckDetail(truckId));

  // ── Trip BOL ─────────────────────────────────────────────────────────────────────
  /// Upload a Bill of Lading image/file to a trip.
  static Future<Response> uploadTripBol(int tripId, String filePath) async {
    final formData = FormData.fromMap({
      'bol_file': await MultipartFile.fromFile(
        filePath,
        filename: filePath.split('/').last,
      ),
    });
    return _dio.post(
      '/api/trips/$tripId/bol/',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  // ── Avatar upload ────────────────────────────────────────────────────────────────
  /// Upload a profile avatar image via PATCH /api/auth/me/
  static Future<Response> uploadAvatar(dynamic file) async {
    final String filePath = file is String ? file : file.path;
    final formData = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(
        filePath,
        filename: filePath.split('/').last,
      ),
    });
    return _dio.patch(
      '/api/auth/me/',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  // ── Change password ──────────────────────────────────────────────────────────
  /// POST /api/auth/change-password/ with {old_password, new_password}
  static Future<Response> changePassword(String oldPassword, String newPassword) =>
      _dio.post('/api/auth/change-password/', data: {
        'old_password': oldPassword,
        'new_password': newPassword,
      });

  // ── Notification preferences ─────────────────────────────────────────────────
  /// GET /api/auth/notification-preferences/
  static Future<Response> getNotificationPrefs() =>
      _dio.get('/api/auth/notification-preferences/');

  /// PATCH /api/auth/notification-preferences/ with any of { push, email, sms }
  static Future<Response> updateNotificationPrefs({
    bool? push,
    bool? email,
    bool? sms,
  }) {
    final data = <String, dynamic>{};
    if (push  != null) data['push']  = push;
    if (email != null) data['email'] = email;
    if (sms   != null) data['sms']   = sms;
    return _dio.patch('/api/auth/notification-preferences/', data: data);
  }

  // ── Legal content (public) ────────────────────────────────────────────────────
  /// GET /api/auth/legal/ — returns privacy_policy and terms_of_service
  static Future<Response> getLegalContent() =>
      _dio.get('/api/auth/legal/');

  // ── Subscription / Trial status ──────────────────────────────────────────────
  /// GET /api/company/subscription/
  static Future<Response> getSubscription() =>
      _dio.get('/api/company/subscription/');

  /// GET /api/company/pricing/ — public, returns list of visible plans
  static Future<Response> getPricing() =>
      _dio.get('/api/company/pricing/');

  // ── Stripe ──────────────────────────────────────────────────────────────────
  /// POST /api/company/stripe/checkout/
  /// Body: { "plan": "starter" | "growth" | "fleet" }
  /// Returns: { "checkout_url": "https://checkout.stripe.com/pay/cs_..." }
  static Future<Response> createCheckoutSession(String planSlug) =>
      _dio.post('/api/company/stripe/checkout/', data: {'plan': planSlug});

  /// POST /api/company/stripe/payment-sheet/
  /// Returns { customer_id, ephemeral_key_secret, client_secret, publishable_key }
  static Future<Response> getPaymentSheetData(String planSlug) =>
      _dio.post('/api/company/stripe/payment-sheet/', data: {'plan': planSlug});

  /// POST /api/company/stripe/confirm-payment/
  /// Called after Stripe.instance.confirmPayment() succeeds on the client.
  /// Verifies with Stripe and activates the subscription in our database.
  static Future<Response> confirmStripePayment({
    required String paymentIntentId,
    required String plan,
  }) =>
      _dio.post('/api/company/stripe/confirm-payment/', data: {
        'payment_intent_id': paymentIntentId,
        'plan': plan,
      });

  /// GET /api/company/invoices/
  /// Returns paginated list of Stripe invoices for the authenticated company.
  static Future<Response> getInvoices({String? startingAfter}) =>
      _dio.get('/api/company/invoices/', queryParameters: {
        if (startingAfter != null) 'starting_after': startingAfter,
      });
}

