import 'package:flutter/material.dart';

class SummaryStatsRow extends StatelessWidget {
  final int totalSessions;
  final int totalPresent;
  final int totalLate;
  final int totalAbsent;

  const SummaryStatsRow({
    super.key,
    required this.totalSessions,
    required this.totalPresent,
    required this.totalLate,
    required this.totalAbsent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatTile(
          label: 'On-time',
          value: '$totalPresent',
          color: Colors.green.shade600,
          icon: Icons.check_circle_outline,
        ),
        const SizedBox(width: 6),
        _StatTile(
          label: 'Late',
          value: '$totalLate',
          color: Colors.orange.shade700,
          icon: Icons.schedule_outlined,
        ),
        const SizedBox(width: 6),
        _StatTile(
          label: 'Absent',
          value: '$totalAbsent',
          color: Colors.red.shade400,
          icon: Icons.cancel_outlined,
        ),
        const SizedBox(width: 6),
        _StatTile(
          label: 'Total',
          value: '$totalSessions',
          color: Colors.blue.shade600,
          icon: Icons.event_note_outlined,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
