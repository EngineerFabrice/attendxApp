import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'messages_provider.dart';
import '../../../shared/widgets/main_bottom_nav.dart';

// Maps notification type to icon + label
({IconData icon, String label, Color color}) _typeInfo(NotificationType t) =>
    switch (t) {
      NotificationType.announcement  => (icon: Icons.campaign_outlined,      label: 'Announcement', color: const Color(0xFF8E24AA)),
      NotificationType.courseAlert   => (icon: Icons.school_outlined,         label: 'Course',       color: const Color(0xFF1E88E5)),
      NotificationType.directMessage => (icon: Icons.person_outline,          label: 'Direct',       color: const Color(0xFF43A047)),
      NotificationType.system        => (icon: Icons.admin_panel_settings_outlined, label: 'System', color: const Color(0xFFF59E0B)),
    };

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  @override
  void initState() {
    super.initState();
    // Mark all as read when screen is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(messagesProvider.notifier).markAllRead();
    });
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60)  return 'Just now';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)    return '${diff.inHours}h ago';
    if (diff.inDays < 7)      return '${diff.inDays}d ago';
    return DateFormat('MMM d, y').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(messagesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Messages'),
            if (state.unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${state.unreadCount}',
                  style: const TextStyle(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (state.messages.isNotEmpty)
            TextButton(
              onPressed: () => ref.read(messagesProvider.notifier).markAllRead(),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      bottomNavigationBar: const MainBottomNav(currentIndex: 3),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mark_chat_read_outlined,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('No messages yet',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Messages from your lecturers will appear here',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(messagesProvider.notifier).loadMessages(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.messages.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final msg  = state.messages[i];
                      final info = _typeInfo(msg.notificationType);
                      return _MessageCard(
                        message:    msg,
                        typeColor:  info.color,
                        typeIcon:   info.icon,
                        typeLabel:  info.label,
                        timeLabel:  _formatTime(msg.sentAt),
                        onTap: () =>
                            ref.read(messagesProvider.notifier).markRead(msg.id),
                      );
                    },
                  ),
                ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final Message  message;
  final Color    typeColor;
  final IconData typeIcon;
  final String   typeLabel;
  final String   timeLabel;
  final VoidCallback onTap;

  const _MessageCard({
    required this.message,
    required this.typeColor,
    required this.typeIcon,
    required this.typeLabel,
    required this.timeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: message.isRead ? Colors.white : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: message.isRead ? Colors.grey.shade200 : Colors.blue.shade200,
            width: message.isRead ? 1 : 1.5,
          ),
          boxShadow: message.isRead
              ? []
              : [BoxShadow(color: Colors.blue.withValues(alpha:0.08), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar — shows type icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(typeIcon, color: typeColor, size: 22),
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            message.senderName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: message.isRead ? Colors.grey.shade800 : Colors.black87,
                            ),
                          ),
                        ),
                        Text(timeLabel,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            typeLabel.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: typeColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'from ${message.senderName}',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message.content,
                      style: TextStyle(
                        fontSize: 14,
                        color: message.isRead ? Colors.grey.shade700 : Colors.grey.shade900,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              // Unread dot
              if (!message.isRead)
                Container(
                  width: 8, height: 8,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: const BoxDecoration(
                    color: Colors.blue, shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
