import 'package:local_auth/local_auth.dart';
import '../storage/secure_storage.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();
  static final SecureStorage _storage = SecureStorage();

  // Returns true if the device has enrolled biometrics (fingerprint / face)
  static Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // Returns the user's saved preference
  static Future<bool> isEnabled() => _storage.getBiometricsEnabled();

  // Saves the user's preference
  static Future<void> setEnabled(bool value) =>
      _storage.setBiometricsEnabled(value);

  // Prompt for biometric authentication.
  // Returns true on success, false on failure or if not available.
  static Future<bool> authenticate({
    String reason = 'Confirm your identity to continue',
  }) async {
    try {
      if (!await isAvailable()) return true; // graceful fallback — don't block
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // allow device PIN as fallback
          stickyAuth: true,     // keeps dialog open if user switches app
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
