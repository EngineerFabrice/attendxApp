import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/history_provider.dart';

class AppealDialog extends ConsumerStatefulWidget {
  final AttendanceRecord record;

  const AppealDialog({super.key, required this.record});

  static Future<bool> show(BuildContext context, AttendanceRecord record) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AppealDialog(record: record),
    );
    return result ?? false;
  }

  @override
  ConsumerState<AppealDialog> createState() => _AppealDialogState();
}

class _AppealDialogState extends ConsumerState<AppealDialog> {
  final _reasonCtrl = TextEditingController();
  final _formKey    = GlobalKey<FormState>();
  bool _submitting  = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final error = await ref
        .read(historyProvider.notifier)
        .submitAppeal(widget.record.id, _reasonCtrl.text.trim());

    if (!mounted) return;
    setState(() => _submitting = false);

    if (error == null) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary  = Theme.of(context).primaryColor;
    final record   = widget.record;
    final isAbsent = record.status == 'absent';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      title: Row(
        children: [
          Icon(Icons.gavel_outlined, color: primary, size: 22),
          const SizedBox(width: 8),
          const Text('Appeal Attendance', style: TextStyle(fontSize: 17)),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Record summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isAbsent
                    ? Colors.red.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.session.course.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${record.session.course.code}  •  '
                    '${DateFormat('MMM d, y').format(record.markedAt)}',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isAbsent
                          ? Colors.red.shade100
                          : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      record.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isAbsent
                            ? Colors.red.shade800
                            : Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Text(
              'Reason for appeal',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 6),

            TextFormField(
              controller: _reasonCtrl,
              maxLines: 4,
              maxLength: 500,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText:
                    'Explain why you believe this should be corrected '
                    '(e.g. I was present but had connectivity issues)…',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.all(12),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please provide a reason';
                }
                if (v.trim().length < 10) {
                  return 'At least 10 characters required';
                }
                return null;
              },
            ),

            const SizedBox(height: 4),
            Text(
              'Your lecturer will review and respond to this appeal.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
      actionsPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed:
                    _submitting ? null : () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Submit Appeal'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
