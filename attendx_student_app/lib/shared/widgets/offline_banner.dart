import 'package:flutter/material.dart';
import '../../core/services/offline_sync_service.dart';

/// Shows a slim amber banner when displaying cached data offline.
/// Also shows a sync progress indicator when syncing queued check-ins.
class OfflineBanner extends StatelessWidget {
  final DateTime? cachedAt;
  final bool showSyncQueue;

  const OfflineBanner({super.key, this.cachedAt, this.showSyncQueue = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.amber.shade700,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              cachedAt != null
                  ? 'Offline — showing data cached ${_age(cachedAt!)}'
                  : 'Offline — showing cached data',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ),
          if (showSyncQueue)
            ValueListenableBuilder<int>(
              valueListenable: OfflineSyncService.instance.pendingCount,
              builder: (context, count, child) {
                if (count == 0) return const SizedBox.shrink();
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count pending',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  String _age(DateTime cachedAt) {
    final diff = DateTime.now().difference(cachedAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

/// Floating sync status widget — shows pending count and last sync time.
class SyncStatusCard extends StatelessWidget {
  const SyncStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: OfflineSyncService.instance.pendingCount,
      builder: (context, count, child) {
        if (count == 0) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.sync, size: 18, color: Colors.orange),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count check-in${count > 1 ? 's' : ''} pending sync',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Colors.orange),
                    ),
                    const Text(
                      'Will sync automatically when connected',
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                onPressed: () => OfflineSyncService.instance.sync(),
                child: const Text('Sync now',
                    style: TextStyle(fontSize: 12, color: Colors.orange)),
              ),
            ],
          ),
        );
      },
    );
  }
}
