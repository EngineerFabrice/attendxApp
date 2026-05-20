class AppConstants {
  AppConstants._();

  static const String appName = 'AttendX';

  // API base URL is set via --dart-define=API_BASE_URL at build time (see api_client.dart)

  // Session & attendance thresholds — must match backend env vars
  static const int    sessionTimeoutMinutes      = 90;
  static const double defaultGeofenceRadiusM     = 50.0;
  static const int    attendanceWarningThreshold  = 75;   // percent
  static const int    lateThresholdMinutes        = 15;

  // Secure storage keys
  static const String keyAccessToken       = 'access_token';
  static const String keyRefreshToken      = 'refresh_token';
  static const String keyUser              = 'user_data';
  static const String keyDeviceFingerprint = 'device_fingerprint';
  static const String keyBiometricEnabled  = 'biometric_enabled';

  // Attendance status strings (match DB ENUM values exactly)
  static const String statusPresent = 'present';
  static const String statusLate    = 'late';
  static const String statusAbsent  = 'absent';

  // Session status strings
  static const String sessionActive = 'active';
  static const String sessionClosed = 'closed';

  // Appeal status strings
  static const String appealPending  = 'pending';
  static const String appealApproved = 'approved';
  static const String appealRejected = 'rejected';
}
