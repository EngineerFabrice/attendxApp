import 'package:socket_io_client/socket_io_client.dart' as sio;

typedef SocketCallback = void Function(Map<String, dynamic> data);

class SocketService {
  static final SocketService _instance = SocketService._();
  factory SocketService() => _instance;
  SocketService._();

  static const String _socketUrl = 'https://api.attendx.ac.rw';

  sio.Socket? _socket;

  final _sessionStartedListeners   = <SocketCallback>[];
  final _attendanceUpdateListeners = <SocketCallback>[];
  final _sessionClosedListeners    = <SocketCallback>[];
  final _newMessageListeners       = <SocketCallback>[];

  void connect(String token) {
    if (_socket?.connected == true) return;

    _socket = sio.io(
      _socketUrl,
      sio.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnectError((_) {
      // Silently ignore — backend may not be reachable in dev/mock mode
    });

    _socket!.on('session_started', (raw) {
      final data = _toMap(raw);
      for (final cb in _sessionStartedListeners) {
        cb(data);
      }
    });

    _socket!.on('attendance_update', (raw) {
      final data = _toMap(raw);
      for (final cb in _attendanceUpdateListeners) {
        cb(data);
      }
    });

    _socket!.on('session_closed', (raw) {
      final data = _toMap(raw);
      for (final cb in _sessionClosedListeners) {
        cb(data);
      }
    });

    _socket!.on('new_message', (raw) {
      final data = _toMap(raw);
      for (final cb in _newMessageListeners) {
        cb(data);
      }
    });

    _socket!.connect();
  }

  void onSessionStarted(SocketCallback cb)   => _sessionStartedListeners.add(cb);
  void onAttendanceUpdate(SocketCallback cb)  => _attendanceUpdateListeners.add(cb);
  void onSessionClosed(SocketCallback cb)     => _sessionClosedListeners.add(cb);
  void onNewMessage(SocketCallback cb)        => _newMessageListeners.add(cb);

  void emitStudentCheckin(Map<String, dynamic> data) {
    _socket?.emit('student_checkin', data);
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _sessionStartedListeners.clear();
    _attendanceUpdateListeners.clear();
    _sessionClosedListeners.clear();
    _newMessageListeners.clear();
  }

  bool get isConnected => _socket?.connected ?? false;

  Map<String, dynamic> _toMap(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }
}
