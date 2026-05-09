// ─────────────────────────────────────────────────────────────────────────────
// IFTATrack App Constants
// ─────────────────────────────────────────────────────────────────────────────

const String appName = "IFTATrack";
const String appVersion = "1.0.0";

// ─── Base URLs ───────────────────────────────────────────────────────────────
// Change these to your actual server before deploying.
//
// For local development on iOS Simulator:     http://localhost
// For local development on Android Emulator:  http://10.0.2.2
// For local development on physical device:   http://<your-mac-ip>  (e.g. http://192.168.1.100)
// For production:                             https://yourdomain.com

const String _kDebugBaseUrl = "http://localhost";   // ← Your Mac's LAN IP (auto-detected)
                                                         //   iOS Simulator: use http://localhost
                                                         //   Android Emulator: use http://10.0.2.2
const String _kProductionBaseUrl = "https://yourdomain.com"; // Production — update before release

/// Resolves to production URL in release builds, debug URL in debug/profile builds.
const String baseUrl = bool.fromEnvironment('dart.vm.product')
    ? _kProductionBaseUrl
    : _kDebugBaseUrl;

/// Base path for all REST API calls.
const String apiUrl = "$baseUrl/api";

/// For display purposes (e.g., links, web redirects).
const String webUrl = baseUrl;

/// Support contact.
const String supportEmail = "support@iftatrack.com";

/// How long error banners / snackbars stay visible.
const Duration errorMessageDisplayDuration = Duration(milliseconds: 3000);

// ─── API Endpoints ───────────────────────────────────────────────────────────
class ApiEndpoints {
  ApiEndpoints._(); // non-instantiable

  // ── Authentication ─────────────────────────────────────────────────────────
  static const String login          = "$apiUrl/auth/login/";
  static const String logout         = "$apiUrl/auth/logout/";
  static const String refreshToken   = "$apiUrl/auth/refresh/";
  static const String register       = "$apiUrl/auth/register/";
  static const String me             = "$apiUrl/auth/me/";
  static const String forgotPassword = "$apiUrl/auth/forgot-password/";
  static const String resetPassword  = "$apiUrl/auth/reset-password/";

  // ── Drivers ────────────────────────────────────────────────────────────────
  static const String drivers        = "$apiUrl/drivers/";
  static String driverDetail(int id)         => "$apiUrl/drivers/$id/";
  static String driverPhoto(int id)          => "$apiUrl/drivers/$id/photo/";
  static String driverResetPassword(int id)  => "$apiUrl/drivers/$id/reset-password/";

  // ── Trucks ─────────────────────────────────────────────────────────────────
  static const String trucks         = "$apiUrl/trucks/";
  static String truckDetail(int id)          => "$apiUrl/trucks/$id/";

  // ── Trips ──────────────────────────────────────────────────────────────────
  static const String trips          = "$apiUrl/trips/";
  static String tripDetail(int id)           => "$apiUrl/trips/$id/";
  static const String calculateRoute  = "$apiUrl/trips/calculate-route/";

  // ── Fuel Purchases ─────────────────────────────────────────────────────────
  static const String fuelPurchases     = "$apiUrl/fuel-purchases/";
  static const String logFuelFromDevice = "$apiUrl/fuel-purchases/log-from-device/";
  static String fuelReceipt(int id)          => "$apiUrl/fuel-purchases/$id/receipt/";
  static String fuelDetail(int id)           => "$apiUrl/fuel-purchases/$id/";

  // ── Dashboard / Reports ────────────────────────────────────────────────────
  static const String dashboardSummary       = "$apiUrl/dashboard/summary/";
  static const String dashboardIftaCurrent   = "$apiUrl/dashboard/ifta-current-quarter/";

  // ── IFTA Reports ───────────────────────────────────────────────────────────
  static const String iftaReports       = "$apiUrl/ifta/reports/";
  static const String iftaQuarters      = "$apiUrl/ifta/quarters/";
  static const String iftaGenerate      = "$apiUrl/ifta/reports/generate/";
  static const String iftaTaxRates      = "$apiUrl/ifta/tax-rates/";
  static String iftaReportDetail(int id)  => "$apiUrl/ifta/reports/$id/";
  static String iftaReportPdf(int id)     => "$apiUrl/ifta/reports/$id/pdf/";
  static String iftaReportCsv(int id)     => "$apiUrl/ifta/reports/$id/csv/";
  // legacy alias kept for compatibility
  static String iftaReportExport(int id, String format) =>
      format == 'pdf' ? iftaReportPdf(id) : iftaReportCsv(id);


  // ── Documents ──────────────────────────────────────────────────────────────
  static const String documents         = "$apiUrl/documents/";
  static String documentDetail(int id)       => "$apiUrl/documents/$id/";
  static String documentDownload(int id)     => "$apiUrl/documents/$id/download/";

  // ── Dashboard / Reports ────────────────────────────────────────────────────
  static const String dashboard         = "$apiUrl/dashboard/";
  static const String dashboardStats    = "$apiUrl/dashboard/stats/";

  // ── Companies ──────────────────────────────────────────────────────────────
  static const String company           = "$apiUrl/company/";
  static const String companySettings   = "$apiUrl/company/settings/";

  // ── Audit Logs ─────────────────────────────────────────────────────────────
  static const String auditLogs         = "$apiUrl/audit-logs/";

  // ── Search ─────────────────────────────────────────────────────────────────
  static const String search            = "$apiUrl/search/";
}

// ─── App Configuration ───────────────────────────────────────────────────────
class AppConfig {
  AppConfig._(); // non-instantiable

  static const String appName    = "IFTATrack";
  static const String appVersion = "1.0.0";

  /// Build ID for display in Settings / About.
  static const int buildNumber = 1;

  /// How many times to retry a failed network request.
  static const int maxRetryAttempts = 3;

  /// JWT access token lifespan (minutes). Should match Django SIMPLE_JWT setting.
  static const int tokenExpirationMinutes = 60;

  // ── Environment detection ─────────────────────────────────────────────────
  static bool get isProduction  => bool.fromEnvironment('dart.vm.product');
  static bool get isDevelopment => !isProduction;

  // ── Dynamic URL resolution ────────────────────────────────────────────────
  /// Override via `--dart-define=BASE_URL=https://myserver.com` at build time.
  static String get dynamicBaseUrl {
    const String envBaseUrl = String.fromEnvironment('BASE_URL');
    if (envBaseUrl.isNotEmpty) return envBaseUrl;
    return isProduction ? _kProductionBaseUrl : _kDebugBaseUrl;
  }

  static String get dynamicApiUrl => "$dynamicBaseUrl/api";

  // ── Pagination defaults ───────────────────────────────────────────────────
  static const int defaultPageSize  = 20;
  static const int fuelPageSize     = 20;
  static const int tripsPageSize    = 20;
  static const int documentsPageSize = 50;

  // ── Feature flags ─────────────────────────────────────────────────────────
  static const bool enableGpsAutoCapture = true;
  static const bool enableReceiptCamera  = true;
  static const bool enablePushNotifications = false; // set true when FCM is configured
}
