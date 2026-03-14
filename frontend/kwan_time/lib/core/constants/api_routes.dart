/// ═══════════════════════════════════════════════════════════════════════════
/// KWAN-TIME v2.0 — API Routes & Environment Configuration
/// All URLs configured via environment variables — zero hardcoding
/// ═══════════════════════════════════════════════════════════════════════════
library;

class ApiRoutes {
  ApiRoutes._();

  // ─────────────────────────────────────────────────────────────────────────
  // BASE URLS (set via environment)
  // ─────────────────────────────────────────────────────────────────────────
  static const String apiBaseUrl = 'API_BASE_URL'; // http://localhost:8080 (dev)
  // https://api.kwan.time (prod)
  static const String wsBaseUrl = 'WS_BASE_URL'; // ws://localhost:8080 (dev)
  // wss://api.kwan.time (prod)
  static const String bookingBaseUrl = 'BOOKING_BASE_URL'; // https://kwan.time (prod)

  // Default fallbacks for development
  static const String defaultApiBase = 'http://localhost:8080';
  static const String defaultWsBase = 'ws://localhost:8080';
  static const String defaultBookingBase = 'https://kwan.time';

  // ─────────────────────────────────────────────────────────────────────────
  // API V1 ENDPOINTS
  // ─────────────────────────────────────────────────────────────────────────

  // Events CRUD
  static const String eventsPath = '/api/v1/events';
  static String eventById(String id) => '$eventsPath/$id';
  static String eventsByRange(DateTime start, DateTime end) =>
      '$eventsPath?start=${start.toIso8601String()}&end=${end.toIso8601String()}';
  static String eventsByType(String type) => '$eventsPath?type=$type';
  static String eventsByStatus(String status) => '$eventsPath?status=$status';

  // Dashboard
  static const String dashboardPath = '/api/v1/dashboard';
  static const String threeMonthOverview = '$dashboardPath/three-month-overview';

  // Notifications (Agent 10)
  static const String notificationsPath = '/api/v1/notifications';
  static const String registerDevice = '$notificationsPath/register-device';
  static const String notificationPreferences = '$notificationsPath/preferences';

  // Sound Preferences (Agent 11)
  static const String userPath = '/api/v1/user';
  static const String soundProfile = '$userPath/sound-profile';

  // Public Booking (Agent 12) — NO AUTH
  static const String publicPath = '/api/v1/public';
  static String publicAvailability(String username, String month) => '$publicPath/$username/availability?month=$month';
  static String publicBookingPage(String slug) => '$publicPath/booking/$slug';
  static String confirmBooking(String slug) => '$publicPath/booking/$slug/confirm';

  // ─────────────────────────────────────────────────────────────────────────
  // WEBSOCKET ENDPOINT
  // ─────────────────────────────────────────────────────────────────────────
  static const String wsPath = '/ws';
  static String wsUrl(String token) => '$wsBaseUrl$wsPath?token=$token';

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC BOOKING PAGES
  // ─────────────────────────────────────────────────────────────────────────
  static String bookingPageUrl(String username) => '$bookingBaseUrl/u/$username/book';

  // ─────────────────────────────────────────────────────────────────────────
  // REQUEST/RESPONSE HEADERS
  // ─────────────────────────────────────────────────────────────────────────
  static const String headerOptimisticId = 'X-Optimistic-ID';
  static const String headerRequestId = 'X-Request-ID';
  static const String headerResponseTime = 'X-Response-Time';
  static const String headerAuthorization = 'Authorization';
  static const String headerContentType = 'Content-Type';

  // ─────────────────────────────────────────────────────────────────────────
  // HTTP TIMEOUTS
  // ─────────────────────────────────────────────────────────────────────────
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  // ─────────────────────────────────────────────────────────────────────────
  // RATE LIMITS
  // ─────────────────────────────────────────────────────────────────────────
  static const int publicRateLimitPerMin = 100; // public endpoints
  static const int authenticatedRateLimitPerMin = 1000; // authenticated
}

/// ═══════════════════════════════════════════════════════════════════════════
/// ENVIRONMENT CONFIGURATION
/// Load from Flavor or .env at app startup
/// ═══════════════════════════════════════════════════════════════════════════

class Environment {
  Environment._();

  static const bool isDevelopment = String.fromEnvironment('ENV') == 'DEV';
  static const bool isProduction = String.fromEnvironment('ENV') == 'PROD';
  static const bool isTesting = String.fromEnvironment('ENV') == 'TEST';

  static String getApiBase() => const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: ApiRoutes.defaultApiBase,
      );

  static String getWsBase() => const String.fromEnvironment(
        'WS_BASE_URL',
        defaultValue: ApiRoutes.defaultWsBase,
      );

  static String getBookingBase() => const String.fromEnvironment(
        'BOOKING_BASE_URL',
        defaultValue: ApiRoutes.defaultBookingBase,
      );
}
