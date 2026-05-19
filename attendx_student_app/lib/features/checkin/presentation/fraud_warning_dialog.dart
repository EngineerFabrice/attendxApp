import 'package:flutter/material.dart';

enum FraudRiskLevel { low, medium, high }

/// Shown when the security engine returns medium or high risk.
/// Returns true if the user chose to proceed (medium only).
class FraudWarningDialog extends StatelessWidget {
  final FraudRiskLevel level;
  final List<String> flags;
  final int score;

  const FraudWarningDialog({
    super.key,
    required this.level,
    required this.flags,
    required this.score,
  });

  static Future<bool> show(
    BuildContext context, {
    required FraudRiskLevel level,
    required List<String> flags,
    required int score,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => FraudWarningDialog(level: level, flags: flags, score: score),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isHigh = level == FraudRiskLevel.high;
    final color  = isHigh ? Colors.red : Colors.orange;
    final icon   = isHigh ? Icons.block : Icons.warning_amber_rounded;
    final title  = isHigh ? 'Check-in Blocked' : 'Security Warning';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: color),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isHigh
                ? 'Your device has been flagged for suspicious activity. Attendance cannot be recorded.'
                : 'Security issues were detected on your device. Your check-in has been logged for review.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Flag list
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Detected issues:',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color)),
                const SizedBox(height: 6),
                ...flags.map((f) => Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.circle, size: 6, color: color),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _flagDescription(f),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade800),
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 6),
                Text('Risk score: $score / 100',
                    style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
      actionsPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: isHigh
          ? [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('OK'),
                ),
              ),
            ]
          : [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        side:
                            BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Proceed'),
                    ),
                  ),
                ],
              ),
            ],
    );
  }

  String _flagDescription(String flag) => switch (flag) {
        'emulator' => 'Emulator or virtual device detected',
        'root'     => 'Rooted / jailbroken device',
        'mockGps'  => 'Fake GPS / mock location is active',
        'vpn'      => 'VPN or proxy connection active',
        _          => flag,
      };
}
