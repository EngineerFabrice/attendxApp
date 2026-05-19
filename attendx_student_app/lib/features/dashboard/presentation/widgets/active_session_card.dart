import 'dart:async';
import 'package:flutter/material.dart';
import '../providers/dashboard_provider.dart';

class ActiveSessionCard extends StatefulWidget {
  final TodaySession session;

  const ActiveSessionCard({super.key, required this.session});

  @override
  State<ActiveSessionCard> createState() => _ActiveSessionCardState();
}

class _ActiveSessionCardState extends State<ActiveSessionCard> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.session.isActive) {
      _updateRemaining();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) _updateRemaining();
      });
    }
  }

  void _updateRemaining() {
    final diff = widget.session.expiresAt.difference(DateTime.now());
    setState(() => _remaining = diff.isNegative ? Duration.zero : diff);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmtCountdown(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.session.isActive;

    return Card(
      elevation: isActive ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isActive
            ? BorderSide(color: Colors.green.shade300, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: isActive
            ? () {
                Navigator.pushNamed(
                  context,
                  '/checkin',
                  arguments: {
                    'sessionId': widget.session.id,
                    'sessionCode': widget.session.sessionCode,
                    'courseName': widget.session.course.name,
                    'roomName': widget.session.classroom.name,
                    'classroomLat': widget.session.classroom.latitude,
                    'classroomLng': widget.session.classroom.longitude,
                    'radiusM': widget.session.classroom.radiusM,
                  },
                );
              }
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status badge + countdown / code
              Row(
                children: [
                  _StatusBadge(isActive: isActive),
                  const Spacer(),
                  if (isActive && _remaining > Duration.zero)
                    Row(
                      children: [
                        Icon(Icons.timer_outlined,
                            size: 14,
                            color: _remaining.inMinutes < 10
                                ? Colors.orange
                                : Colors.grey.shade500),
                        const SizedBox(width: 3),
                        Text(
                          _fmtCountdown(_remaining),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _remaining.inMinutes < 10
                                ? Colors.orange
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      widget.session.sessionCode,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Course name
              Text(
                widget.session.course.name,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                widget.session.course.code,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              // Room + time
              Row(
                children: [
                  Icon(Icons.location_on,
                      size: 15, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(widget.session.classroom.name,
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 13)),
                  const Spacer(),
                  Icon(Icons.access_time,
                      size: 15, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    isActive
                        ? 'Until ${_formatTime(widget.session.expiresAt)}'
                        : 'Starts ${_formatTime(widget.session.startedAt)}',
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
              if (isActive) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    // GPS check-in
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/checkin',
                          arguments: {
                            'sessionId': widget.session.id,
                            'sessionCode': widget.session.sessionCode,
                            'courseName': widget.session.course.name,
                            'roomName': widget.session.classroom.name,
                            'classroomLat': widget.session.classroom.latitude,
                            'classroomLng': widget.session.classroom.longitude,
                            'radiusM': widget.session.classroom.radiusM,
                          },
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text(
                              'Check In',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // QR scan check-in
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/qr-scan',
                        arguments: {
                          'sessionId': widget.session.id,
                          'courseName': widget.session.course.name,
                          'roomName': widget.session.classroom.name,
                          'classroomLat': widget.session.classroom.latitude,
                          'classroomLng': widget.session.classroom.longitude,
                          'radiusM': widget.session.classroom.radiusM,
                        },
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.qr_code_scanner,
                                size: 16,
                                color: Theme.of(context).primaryColor),
                            const SizedBox(width: 4),
                            Text(
                              'QR',
                              style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;

  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.shade100 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isActive ? 'LIVE' : 'UPCOMING',
        style: TextStyle(
          color: isActive ? Colors.green.shade700 : Colors.grey.shade600,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
