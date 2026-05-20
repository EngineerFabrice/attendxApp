import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  final Dio _dio = ApiClient().dio;

  bool _loading = true;
  bool _saving = false;

  bool _sessionStart = true;
  bool _absenceAlert = true;
  bool _lowAttendance = true;
  bool _weeklyReport = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await _dio.get(ApiEndpoints.notifPrefs);
      final data = (res.data['data'] ?? res.data) as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _sessionStart  = data['sessionStart']  as bool? ?? true;
          _absenceAlert  = data['absenceAlert']  as bool? ?? true;
          _lowAttendance = data['lowAttendance'] as bool? ?? true;
          _weeklyReport  = data['weeklyReport']  as bool? ?? false;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _dio.put(ApiEndpoints.notifPrefs, data: {
        'sessionStart':  _sessionStart,
        'absenceAlert':  _absenceAlert,
        'lowAttendance': _lowAttendance,
        'weeklyReport':  _weeklyReport,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferences saved'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save preferences'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggle(String field, bool value) {
    setState(() {
      switch (field) {
        case 'sessionStart':
          _sessionStart = value;
        case 'absenceAlert':
          _absenceAlert = value;
        case 'lowAttendance':
          _lowAttendance = value;
        case 'weeklyReport':
          _weeklyReport = value;
      }
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Preferences'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 8),
                const _SectionHeader('Push Notifications'),
                _PrefTile(
                  icon: Icons.play_circle_outline,
                  iconColor: Colors.blue,
                  title: 'Session Started',
                  subtitle: 'Alert when a lecturer opens a check-in session',
                  value: _sessionStart,
                  onChanged: (v) => _toggle('sessionStart', v),
                ),
                _PrefTile(
                  icon: Icons.warning_amber_outlined,
                  iconColor: Colors.orange,
                  title: 'Missed Attendance',
                  subtitle: 'Alert when you are marked absent',
                  value: _absenceAlert,
                  onChanged: (v) => _toggle('absenceAlert', v),
                ),
                _PrefTile(
                  icon: Icons.trending_down,
                  iconColor: Colors.red,
                  title: 'Low Attendance Warning',
                  subtitle: 'Alert when your attendance rate drops below 75%',
                  value: _lowAttendance,
                  onChanged: (v) => _toggle('lowAttendance', v),
                ),
                const Divider(height: 32, indent: 16, endIndent: 16),
                const _SectionHeader('Reports'),
                _PrefTile(
                  icon: Icons.assessment_outlined,
                  iconColor: Colors.purple,
                  title: 'Weekly Summary',
                  subtitle: 'Receive a weekly attendance summary every Monday',
                  value: _weeklyReport,
                  onChanged: (v) => _toggle('weeklyReport', v),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade500,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _PrefTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PrefTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}
