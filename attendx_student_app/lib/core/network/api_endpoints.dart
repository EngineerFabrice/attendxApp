class ApiEndpoints {
  // Auth
  static const String login  = '/auth/login';
  static const String logout = '/auth/logout';

  // Student
  static const String studentDashboard = '/student/dashboard';
  static const String studentHistory   = '/student/history';
  static const String studentCourses   = '/student/courses';
  static const String activeSessions   = '/student/sessions/active';
  static const String studentAnalytics = '/student/analytics';

  // Check-in (body: { sessionId, latitude, longitude })
  static const String checkin = '/student/checkin';

  // Appeals
  static const String appeals = '/appeals';

  // Password reset
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword  = '/auth/reset-password';

  // Profile
  static const String profile        = '/auth/me';
  static const String updateProfile  = '/auth/profile';
  static const String notifPrefs     = '/student/notification-preferences';
}
