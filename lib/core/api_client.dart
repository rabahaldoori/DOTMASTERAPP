import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

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
        await _storage.write(key: 'access_token', value: res.data['access']);
        return true;
      }
    } catch (_) {}
    return false;
  }

  // ── Auth ──────────────────────────────────────────────────────────────────
  static Future<Response> login(String email, String password) =>
      _dio.post(ApiEndpoints.login, data: {'email': email, 'password': password});

  static Future<Response> getProfile() => _dio.get(ApiEndpoints.me);

  static Future<Response> forgotPassword(String email) =>
      _dio.post(ApiEndpoints.forgotPassword, data: {'email': email});

  static Future<Response> resetPassword(String token, String newPassword) =>
      _dio.post(ApiEndpoints.resetPassword, data: {'token': token, 'new_password': newPassword});

  // ── Drivers ───────────────────────────────────────────────────────────────
  static Future<Response> getDrivers() => _dio.get(ApiEndpoints.drivers);

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
  /// Returns true on success, false if expired/missing.
  static Future<bool> refreshAccessToken() => _refreshToken();

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

  static Future<Response> getTodayInspection({String type = 'pre_trip'}) =>
      _dio.get('/api/inspections/mobile/today/', queryParameters: {'type': type});

  static Future<Response> updateInspection(int id, Map<String, dynamic> data) =>
      _dio.patch('/api/inspections/mobile/$id/edit/', data: data);

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
}
