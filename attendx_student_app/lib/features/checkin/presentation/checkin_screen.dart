import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'providers/checkin_provider.dart';
import '../../../core/utils/haversine.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/services/security_service.dart';
import 'fraud_warning_dialog.dart';

class CheckinScreen extends ConsumerStatefulWidget {
  const CheckinScreen({super.key});

  @override
  ConsumerState<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends ConsumerState<CheckinScreen> {
  Position? _currentPosition;
  double? _distance;
  bool _isCheckingLocation = true;
  bool _isCheckingIn = false;
  String? _errorMessage;
  
  bool _initialized = false;
  late String sessionId;
  late String sessionCode;
  late String courseName;
  late String roomName;
  late double classroomLat;
  late double classroomLng;
  late double radiusM;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    sessionId = args['sessionId'] as String;
    sessionCode = args['sessionCode'] as String;
    courseName = args['courseName'] as String;
    roomName = args['roomName'] as String;
    classroomLat = args['classroomLat'] as double;
    classroomLng = args['classroomLng'] as double;
    radiusM = args['radiusM'] as double;
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isCheckingLocation = true);

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _errorMessage = 'Location permission is required to check in';
          _isCheckingLocation = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _errorMessage = 'Location permission permanently denied. Please enable in settings.';
        _isCheckingLocation = false;
      });
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      
      final distance = Haversine.calculateDistance(
        position.latitude, position.longitude,
        classroomLat, classroomLng,
      );

      setState(() {
        _currentPosition = position;
        _distance = distance;
        _isCheckingLocation = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to get location: $e';
        _isCheckingLocation = false;
      });
    }
  }

  bool get _isWithinGeofence => _distance != null && _distance! <= radiusM;

  Future<void> _handleCheckIn() async {
    if (!_isWithinGeofence) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You are ${_distance?.toInt()}m away. Move within ${radiusM.toInt()}m of $roomName.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Biometric gate — only if the user has it enabled
    final biometricEnabled = await BiometricService.isEnabled();
    if (biometricEnabled) {
      final passed = await BiometricService.authenticate(
        reason: 'Confirm your identity to record attendance',
      );
      if (!passed) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric verification failed. Check-in cancelled.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Run security scan
    setState(() { _isCheckingIn = true; });
    final secCtx = await SecurityService.scan();

    if (!mounted) return;

    // Evaluate client-side before even hitting the API
    if (secCtx.hasAnyFlag) {
      // Map flag count to approximate risk for pre-flight dialog
      final estimatedHigh = secCtx.activeFlags.length >= 2 ||
          secCtx.isMockGps || secCtx.isRooted;
      final level = estimatedHigh
          ? FraudRiskLevel.high
          : FraudRiskLevel.medium;

      final proceed = await FraudWarningDialog.show(
        context,
        level: level,
        flags: secCtx.activeFlags,
        score: secCtx.activeFlags.length * 35,
      );
      if (!proceed) {
        setState(() => _isCheckingIn = false);
        return;
      }
    }

    final result = await ref.read(checkinProvider.notifier).checkIn(
      sessionId: sessionId,
      latitude: _currentPosition!.latitude,
      longitude: _currentPosition!.longitude,
      courseName: courseName,
      entryCode: sessionCode,
      securityContext: secCtx,
    );

    setState(() => _isCheckingIn = false);
    if (!mounted) return;

    if (result) {
      final checkinState = ref.read(checkinProvider);
      if (checkinState.wasQueued) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '📶 No internet — check-in saved and will sync when connected.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      } else if (checkinState.lastSecurityResult?.warned == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '✓ Attendance recorded. Security flags were logged for review.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        // Show late or on-time message from the server response
        final msg = checkinState.lateMessage ?? 'Check-in successful!';
        final isLate = checkinState.lateMessage != null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: isLate ? Colors.orange.shade700 : Colors.green,
          ),
        );
      }
      Navigator.pop(context, true);
    } else {
      final errMsg = ref.read(checkinProvider).error;
      final isBlocked = errMsg?.toLowerCase().contains('blocked') ?? false;
      if (isBlocked) {
        await FraudWarningDialog.show(
          context,
          level: FraudRiskLevel.high,
          flags: secCtx.activeFlags,
          score: secCtx.activeFlags.length * 35,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Check-in failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Check In'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Course info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    courseName,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    roomName,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Code: $sessionCode',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Geofence status
            if (_isCheckingLocation)
              const CircularProgressIndicator()
            else if (_errorMessage != null)
              Column(
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                  const SizedBox(height: 16),
                  Text(_errorMessage!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _getCurrentLocation,
                    child: const Text('Retry'),
                  ),
                ],
              )
            else
              Column(
                children: [
                  Icon(
                    _isWithinGeofence ? Icons.check_circle : Icons.location_off,
                    size: 80,
                    color: _isWithinGeofence ? Colors.green : Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isWithinGeofence ? 'Within Geofence' : 'Outside Geofence',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _isWithinGeofence ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Distance: ${_distance?.toInt() ?? 0}m / ${radiusM.toInt()}m',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  if (!_isWithinGeofence)
                    Text(
                      'Please move closer to the classroom',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  const SizedBox(height: 32),
                  
                  // Check-in button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isCheckingIn ? null : _handleCheckIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isWithinGeofence ? Colors.green : Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isCheckingIn
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Check In',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}