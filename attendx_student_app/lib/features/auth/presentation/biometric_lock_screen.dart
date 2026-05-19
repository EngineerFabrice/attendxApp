import 'package:flutter/material.dart';
import '../../../core/services/biometric_service.dart';

/// Shown at app startup (if biometrics enabled) and on background→foreground resume.
/// [onSuccess] is called when the user passes authentication.
/// Pass [canSkipToLogin] = true to show a "Use password instead" fallback.
class BiometricLockScreen extends StatefulWidget {
  final VoidCallback onSuccess;
  final bool canSkipToLogin;

  const BiometricLockScreen({
    super.key,
    required this.onSuccess,
    this.canSkipToLogin = false,
  });

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  bool _authenticating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Auto-trigger on mount
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _tryAuthenticate());
  }

  Future<void> _tryAuthenticate() async {
    if (_authenticating) return;
    setState(() {
      _authenticating = true;
      _errorMessage = null;
    });

    final ok = await BiometricService.authenticate(
      reason: 'Unlock AttendX to continue',
    );

    if (!mounted) return;
    setState(() => _authenticating = false);

    if (ok) {
      widget.onSuccess();
    } else {
      setState(() =>
          _errorMessage = 'Authentication failed. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [primary, primary.withValues(alpha: 0.75)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.fingerprint,
                    size: 56,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 32),

                const Text(
                  'AttendX',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Authenticate to continue',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 56),

                // Fingerprint button
                GestureDetector(
                  onTap: _authenticating ? null : _tryAuthenticate,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _authenticating
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 2),
                    ),
                    child: _authenticating
                        ? const Padding(
                            padding: EdgeInsets.all(22),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Icon(Icons.fingerprint,
                            size: 44, color: Colors.white),
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  _authenticating
                      ? 'Verifying…'
                      : 'Tap to authenticate',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _tryAuthenticate,
                    child: const Text(
                      'Try Again',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],

                if (widget.canSkipToLogin) ...[
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () =>
                        Navigator.pushReplacementNamed(context, '/login'),
                    child: Text(
                      'Use password instead',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
