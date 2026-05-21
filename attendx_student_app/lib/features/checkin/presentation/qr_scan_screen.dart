import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'providers/checkin_provider.dart';
import '../../../core/utils/haversine.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/services/security_service.dart';
import 'fraud_warning_dialog.dart';

class QrScanScreen extends ConsumerStatefulWidget {
  const QrScanScreen({super.key});

  @override
  ConsumerState<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends ConsumerState<QrScanScreen> {
  final MobileScannerController _scannerCtrl = MobileScannerController();

  bool _initialized = false;
  late String sessionId;
  late String courseName;
  late String roomName;
  late double classroomLat;
  late double classroomLng;
  late double radiusM;

  bool _processing = false;
  bool _scanned = false;
  String? _statusMessage;
  bool _success = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    sessionId     = args['sessionId'] as String;
    courseName    = args['courseName'] as String;
    roomName      = args['roomName'] as String;
    classroomLat  = args['classroomLat'] as double;
    classroomLng  = args['classroomLng'] as double;
    radiusM       = args['radiusM'] as double;
  }

  @override
  void dispose() {
    _scannerCtrl.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing || _scanned) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    setState(() { _processing = true; _statusMessage = 'Validating QR code…'; });

    // Parse QR payload
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      _setError('Invalid QR code. Please scan the code shown by your lecturer.');
      return;
    }

    final qrSessionId = payload['s'] as String?;
    final qrToken     = payload['t'] as String?;
    final qrWindow    = payload['w'] as int?;

    if (qrSessionId == null || qrToken == null || qrWindow == null) {
      _setError('Malformed QR code. Please ask your lecturer to refresh it.');
      return;
    }

    if (qrSessionId != sessionId) {
      _setError('This QR code is for a different session.');
      return;
    }

    // Get GPS location — best of 3 readings to handle indoor fluctuation
    setState(() => _statusMessage = 'Getting your location…');
    Position position;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _setError('Location permission is required to check in.');
        return;
      }

      // Take 3 readings and keep the most accurate one (lowest accuracy value)
      const settings = LocationSettings(accuracy: LocationAccuracy.best);
      final readings = <Position>[];
      for (int i = 0; i < 3; i++) {
        try {
          final p = await Geolocator.getCurrentPosition(
            locationSettings: settings,
          ).timeout(const Duration(seconds: 8));
          readings.add(p);
        } catch (_) {
          // skip failed reading, continue with what we have
        }
      }
      if (readings.isEmpty) {
        _setError('Failed to get location. Please enable GPS and try again.');
        return;
      }
      // Pick reading with best (lowest) reported accuracy
      readings.sort((a, b) => a.accuracy.compareTo(b.accuracy));
      position = readings.first;
    } catch (e) {
      _setError('Failed to get location. Please enable GPS and try again.');
      return;
    }

    // Geofence check — factor in GPS accuracy so marginal cases aren't rejected
    final distance = Haversine.calculateDistance(
      position.latitude, position.longitude, classroomLat, classroomLng,
    );
    // Allow extra buffer equal to the device's reported GPS accuracy
    final effectiveRadius = radiusM + position.accuracy.clamp(0, 30);
    if (distance > effectiveRadius) {
      _setError(
        'You are ${distance.toInt()}m away.\nMove within ${radiusM.toInt()}m of $roomName.',
      );
      return;
    }

    // Security scan
    setState(() => _statusMessage = 'Running security check…');
    final secCtx = await SecurityService.scan();

    if (!mounted) return;
    if (secCtx.hasAnyFlag) {
      final estimatedHigh = secCtx.activeFlags.length >= 2 ||
          secCtx.isMockGps || secCtx.isRooted;
      final level = estimatedHigh ? FraudRiskLevel.high : FraudRiskLevel.medium;
      final proceed = await FraudWarningDialog.show(
        context,
        level: level,
        flags: secCtx.activeFlags,
        score: secCtx.activeFlags.length * 35,
      );
      if (!proceed) {
        setState(() { _processing = false; _statusMessage = null; });
        return;
      }
    }

    // Biometric gate before final submission
    final biometricEnabled = await BiometricService.isEnabled();
    if (biometricEnabled) {
      setState(() => _statusMessage = 'Verifying identity…');
      final passed = await BiometricService.authenticate(
        reason: 'Confirm your identity to record attendance',
      );
      if (!passed) {
        _setError('Biometric verification failed. Check-in cancelled.');
        return;
      }
    }

    // Submit check-in
    setState(() => _statusMessage = 'Recording attendance…');
    final ok = await ref.read(checkinProvider.notifier).checkInWithQr(
      sessionId: sessionId,
      qrToken: qrToken,
      qrWindow: qrWindow,
      latitude: position.latitude,
      longitude: position.longitude,
      courseName: courseName,
      securityContext: secCtx,
    );

    if (!mounted) return;
    if (ok) {
      setState(() {
        _scanned = true;
        _success = true;
        _statusMessage = 'Attendance recorded!';
        _processing = false;
      });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context, true);
    } else {
      _setError('Check-in failed. You may have already checked in.');
    }
  }

  void _setError(String msg) {
    if (!mounted) return;
    setState(() { _statusMessage = msg; _processing = false; _scanned = false; });
    // Re-enable scanner after 3 seconds so user can retry
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _statusMessage = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _scannerCtrl.toggleTorch(),
            tooltip: 'Toggle flash',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera view
          MobileScanner(
            controller: _scannerCtrl,
            onDetect: _onDetect,
          ),

          // Overlay frame
          _ScanOverlay(color: _success ? Colors.green : primaryColor),

          // Session info at top
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(courseName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(roomName,
                      style: TextStyle(
                          color: Colors.grey.shade300, fontSize: 12)),
                ],
              ),
            ),
          ),

          // Status / result message
          if (_statusMessage != null)
            Positioned(
              bottom: 48,
              left: 24,
              right: 24,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: _success
                      ? Colors.green.shade700
                      : (_processing
                          ? Colors.black.withValues(alpha: 0.8)
                          : Colors.red.shade700),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    if (_processing)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else
                      Icon(
                        _success ? Icons.check_circle : Icons.error_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Hint label
          if (_statusMessage == null)
            const Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: Text(
                'Point your camera at the QR code\nshown on the lecturer\'s screen',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }
}

// Simple scan-frame overlay — uses 4 plain rectangles (no blend modes)
// ColorFiltered + BlendMode.srcOut causes black camera texture on Android
class _ScanOverlay extends StatelessWidget {
  final Color color;
  const _ScanOverlay({required this.color});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    const frameSize = 240.0;
    final frameTop  = (size.height - frameSize) / 2 - 40;
    final frameLeft = (size.width  - frameSize) / 2;
    const dimColor  = Color(0x99000000); // 60% black, no blend mode

    return Stack(
      children: [
        // Top bar
        Positioned(
          top: 0, left: 0, right: 0,
          height: frameTop,
          child: ColoredBox(color: dimColor),
        ),
        // Bottom bar
        Positioned(
          top: frameTop + frameSize, left: 0, right: 0,
          bottom: 0,
          child: ColoredBox(color: dimColor),
        ),
        // Left bar
        Positioned(
          top: frameTop, left: 0,
          width: frameLeft,
          height: frameSize,
          child: ColoredBox(color: dimColor),
        ),
        // Right bar
        Positioned(
          top: frameTop, right: 0,
          width: frameLeft,
          height: frameSize,
          child: ColoredBox(color: dimColor),
        ),
        // Corner brackets drawn on top of the clear window
        Positioned(
          top: frameTop,
          left: frameLeft,
          child: _Frame(size: frameSize, color: color),
        ),
      ],
    );
  }
}

class _Frame extends StatelessWidget {
  final double size;
  final Color color;
  const _Frame({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    const corner = 24.0;
    const thickness = 3.5;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _FramePainter(color: color, corner: corner, thickness: thickness),
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  final Color color;
  final double corner;
  final double thickness;
  const _FramePainter(
      {required this.color, required this.corner, required this.thickness});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paths = [
      // Top-left
      [Offset(0, corner), const Offset(0, 0), Offset(corner, 0)],
      // Top-right
      [
        Offset(size.width - corner, 0),
        Offset(size.width, 0),
        Offset(size.width, corner)
      ],
      // Bottom-left
      [
        Offset(0, size.height - corner),
        Offset(0, size.height),
        Offset(corner, size.height)
      ],
      // Bottom-right
      [
        Offset(size.width - corner, size.height),
        Offset(size.width, size.height),
        Offset(size.width, size.height - corner)
      ],
    ];

    for (final pts in paths) {
      final path = Path()
        ..moveTo(pts[0].dx, pts[0].dy)
        ..lineTo(pts[1].dx, pts[1].dy)
        ..lineTo(pts[2].dx, pts[2].dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FramePainter old) => old.color != color;
}
