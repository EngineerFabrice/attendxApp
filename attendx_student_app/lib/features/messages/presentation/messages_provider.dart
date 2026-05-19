import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/messages_api.dart';
import '../../../core/services/socket_service.dart';
import '../../../core/services/notification_service.dart';

enum NotificationType { announcement, courseAlert, directMessage, system }

class Message {
  final String id;
  final String senderName;
  final String senderRole;
  final String targetType;
  final String content;
  final DateTime sentAt;
  bool isRead;

  Message({
    required this.id,
    required this.senderName,
    required this.senderRole,
    required this.targetType,
    required this.content,
    required this.sentAt,
    required this.isRead,
  });

  /// Inferred notification type from sender + target fields.
  NotificationType get notificationType {
    if (senderRole == 'admin') return NotificationType.system;
    if (targetType == 'all')    return NotificationType.announcement;
    if (targetType == 'course') return NotificationType.courseAlert;
    return NotificationType.directMessage;
  }

  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id:         j['id'] as String,
        senderName: j['senderName'] as String,
        senderRole: j['senderRole'] as String,
        targetType: j['targetType'] as String,
        content:    j['content'] as String,
        sentAt:     DateTime.parse(j['sentAt'] as String),
        isRead:     j['isRead'] as bool? ?? false,
      );
}

class MessagesState {
  final List<Message> messages;
  final int unreadCount;
  final bool isLoading;

  MessagesState({
    this.messages    = const [],
    this.unreadCount = 0,
    this.isLoading   = false,
  });

  MessagesState copyWith({
    List<Message>? messages,
    int?           unreadCount,
    bool?          isLoading,
  }) => MessagesState(
    messages:    messages    ?? this.messages,
    unreadCount: unreadCount ?? this.unreadCount,
    isLoading:   isLoading   ?? this.isLoading,
  );
}

final messagesProvider =
    StateNotifierProvider<MessagesNotifier, MessagesState>(
        (ref) => MessagesNotifier());

class MessagesNotifier extends StateNotifier<MessagesState> {
  final _api = MessagesApi();

  MessagesNotifier() : super(MessagesState()) {
    loadMessages();
    SocketService().onNewMessage(_onSocketMessage);
  }

  void _onSocketMessage(Map<String, dynamic> data) {
    addRealTimeMessage(data);
    final senderName = data['senderName'] as String? ?? 'Lecturer';
    final content    = data['content']    as String? ?? '';
    NotificationService.showNewMessage(senderName, content);
  }

  Future<void> loadMessages() async {
    state = state.copyWith(isLoading: true);
    try {
      final res  = await _api.getInbox();
      final msgs = (res.data['data'] as List)
          .map((j) => Message.fromJson(j as Map<String, dynamic>))
          .toList();

      final unread = msgs.where((m) => !m.isRead).length;

      state = MessagesState(
        messages:    msgs,
        unreadCount: unread,
        isLoading:   false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Called when a new_message socket event arrives.
  void addRealTimeMessage(Map<String, dynamic> data) {
    final msg = Message(
      id:         data['id'] as String? ?? '',
      senderName: data['senderName'] as String? ?? 'Lecturer',
      senderRole: data['senderRole'] as String? ?? 'lecturer',
      targetType: data['targetType'] as String? ?? 'course',
      content:    data['content'] as String? ?? '',
      sentAt:     DateTime.tryParse(data['sentAt'] as String? ?? '') ?? DateTime.now(),
      isRead:     false,
    );
    state = state.copyWith(
      messages:    [msg, ...state.messages],
      unreadCount: state.unreadCount + 1,
    );
  }

  Future<void> markRead(String id) async {
    try {
      await _api.markRead(id);
      final updated = state.messages.map((m) {
        if (m.id == id && !m.isRead) {
          m.isRead = true;
          return m;
        }
        return m;
      }).toList();
      final unread = updated.where((m) => !m.isRead).length;
      state = state.copyWith(messages: updated, unreadCount: unread);
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    try {
      await _api.markAllRead();
      for (final m in state.messages) { m.isRead = true; }
      state = state.copyWith(
        messages:    [...state.messages],
        unreadCount: 0,
      );
    } catch (_) {}
  }
}
