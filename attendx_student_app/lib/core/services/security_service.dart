import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:safe_device/safe_device.dart';

/// Holds the result of a full device security scan.
class SecurityContext {
  final bool isEmulator;
  final bool isRooted;
  final bool isMockGps;
  final bool isVpn;
  final String platform;
  final String? deviceModel;

  const SecurityContext({
    required this.isEmulator,
    required this.isRooted,
    required this.isMockGps,
    required this.isVpn,
    required this.platform,
    this.deviceModel,
  });

  List<String> get activeFlags {
    final flags = <String>[];
    if (isEmulator) flags.add('emulator');
    if (isRooted)   flags.add('root');
    if (isMockGps)  flags.add('mockGps');
    if (isVpn)      flags.add('vpn');
    return flags;
  }

  bool get hasAnyFlag => activeFlags.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'isEmulator':  isEmulator,
        'isRooted':    isRooted,
        'isMockGps':   isMockGps,
        'isVpn':       isVpn,
        'platform':    platform,
        'deviceModel': deviceModel,
      };
}

class SecurityService {
  /// Run all checks and return a [SecurityContext].
  /// This is designed to be fast (< 2 seconds) and never throw.
  static Future<SecurityContext> scan() async {
    final results = await Future.wait([
      _checkEmulator(),
      _checkRooted(),
      _checkMockGps(),
      _checkVpn(),
    ]);

    final model = await _getDeviceModel();

    return SecurityContext(
      isEmulator:  results[0],
      isRooted:    results[1],
      isMockGps:   results[2],
      isVpn:       results[3],
      platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      deviceModel: model,
    );
  }

  // ── Individual checks ────────────────────────────────────────────────────────

  static Future<bool> _checkEmulator() async {
    try {
      // safe_device: isRealDevice is false on emulators
      final isReal = await SafeDevice.isRealDevice;
      if (!isReal) return true;

      // Extra Android signal: known emulator identifiers
      if (defaultTargetPlatform == TargetPlatform.android) {
        final info = await DeviceInfoPlugin().androidInfo;
        final suspect = [
          info.manufacturer.toLowerCase().contains('genymotion'),
          info.model.toLowerCase().contains('sdk_gphone'),
          info.model.toLowerCase().contains('generic'),
          info.model.toLowerCase().contains('emulator'),
          info.hardware.toLowerCase().contains('goldfish'),
          info.hardware.toLowerCase().contains('ranchu'),
          info.product.toLowerCase().contains('sdk'),
          !info.isPhysicalDevice,
        ];
        if (suspect.any((s) => s)) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _checkRooted() async {
    try {
      return await SafeDevice.isJailBroken;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _checkMockGps() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return false;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 5));

      // isMocked is set by Android when a mock location provider is active
      if (position.isMocked) { return true; }

      // Extra heuristic: suspiciously perfect accuracy
      if (position.accuracy == 0.0) { return true; }

      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _checkVpn() async {
    try {
      // Method 1: connectivity_plus — works on Android 10+ (API 29+)
      final result = await Connectivity().checkConnectivity();
      if (result.contains(ConnectivityResult.vpn)) return true;

      // Method 2: network interface name check — works on ALL Android versions.
      // Every VPN protocol creates a tunnel interface with a known prefix:
      //   tun*   → OpenVPN, WireGuard, most commercial VPNs
      //   ppp*   → PPTP, L2TP
      //   tap*   → bridged VPNs
      //   ipsec* → IPSec/IKEv2
      //   utun*  → iOS/macOS utun (WireGuard, built-in VPN)
      //   wg*    → WireGuard explicit naming
      const vpnPrefixes = ['tun', 'ppp', 'tap', 'ipsec', 'utun', 'wg'];
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.any,
      );
      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        if (vpnPrefixes.any((prefix) => name.startsWith(prefix))) return true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> _getDeviceModel() async {
    try {
      final info = DeviceInfoPlugin();
      if (defaultTargetPlatform == TargetPlatform.android) {
        final a = await info.androidInfo;
        return '${a.manufacturer} ${a.model}';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final i = await info.iosInfo;
        return i.utsname.machine;
      }
    } catch (_) {}
    return null;
  }
}
