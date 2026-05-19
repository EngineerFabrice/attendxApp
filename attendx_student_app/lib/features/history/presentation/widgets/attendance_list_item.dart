import 'package:flutter/material.dart';
import '../providers/history_provider.dart';
import 'appeal_dialog.dart';

class AttendanceListItem extends StatelessWidget {
  final AttendanceRecord record;
  final BuildContext? dialogContext; // passed from list so dialog can access provider

  const AttendanceListItem({
    super.key,
    required this.record,
    this.dialogContext,
  });

  Color get _statusColor {
    switch (record.status) {
      case 'present': return Colors.green;
      case 'late':    return Colors.orange.shade700;
      default:        return Colors.red;
    }
  }

  Color get _statusBg {
    switch (record.status) {
      case 'present': return Colors.green.shade50;
      case 'late':    return Colors.orange.shade50;
      default:        return Colors.red.shade50;
    }
  }

  IconData get _statusIcon {
    switch (record.status) {
      case 'present': return Icons.check_circle_outline;
      case 'late':    return Icons.schedule_outlined;
      default:        return Icons.cancel_outlined;
    }
  }

  String get _statusLabel {
    switch (record.status) {
      case 'present': return 'Present';
      case 'late':    return 'Late';
      default:        return 'Absent';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                // Status icon circle
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _statusBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_statusIcon, color: _statusColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.session.course.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${record.session.course.code} • ${record.session.classroom.name}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(record.markedAt),
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _statusBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon, size: 12, color: _statusColor),
                      const SizedBox(width: 4),
                      Text(
                        _statusLabel,
                        style: TextStyle(
                          color: _statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Appeal row
            if (record.canAppeal || record.appeal != null) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              _AppealRow(record: record),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} • '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}

// ── Appeal row shown below the attendance card ────────────────────────────────

class _AppealRow extends StatelessWidget {
  final AttendanceRecord record;
  const _AppealRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final appeal = record.appeal;

    // Already has an appeal — show its status
    if (appeal != null) {
      final (color, icon, label) = switch (appeal.status) {
        'approved' => (Colors.green, Icons.check_circle_outline, 'Appeal Approved'),
        'rejected' => (Colors.red, Icons.cancel_outlined,        'Appeal Rejected'),
        _          => (Colors.orange, Icons.hourglass_top_outlined, 'Appeal Pending'),
      };
      return Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w600),
          ),
          if (appeal.reviewNote != null) ...[
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '— ${appeal.reviewNote}',
                style:
                    TextStyle(fontSize: 11, color: Colors.grey.shade600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      );
    }

    // Can appeal — show button
    return Row(
      children: [
        Icon(Icons.info_outline, size: 13, color: Colors.grey.shade500),
        const SizedBox(width: 5),
        Text(
          'Think this is wrong?',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => AppealDialog.show(context, record),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    Theme.of(context).primaryColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.gavel_outlined,
                    size: 13,
                    color: Theme.of(context).primaryColor),
                const SizedBox(width: 4),
                Text(
                  'Appeal',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}