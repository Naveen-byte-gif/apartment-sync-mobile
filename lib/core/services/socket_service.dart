import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../constants/api_constants.dart';
import 'storage_service.dart';
import '../constants/app_constants.dart';

/// Singleton SocketService to share one real-time connection across the app.
class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  String? _userId;
  bool _listenersInitialized = false;
  /// Room to re-join on connect/reconnect (e.g. community_ABC1) so messages are received immediately.
  String? _currentChatRoom;

  void connect(String userId) {
    if (_socket != null && _socket!.connected && _userId == userId) {
      return;
    }

    print('🔌 [FLUTTER] Connecting to socket...');
    _userId = userId;
    final token = StorageService.getString(AppConstants.tokenKey);

    print('🔌 [FLUTTER] Socket URL: ${ApiConstants.socketUrl}');
    print('🔌 [FLUTTER] User ID: $userId');

    _socket = IO.io(
      ApiConstants.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(2000)
          .build(),
    );

    void joinRooms() {
      if (_userId != null) {
        print('🔌 [FLUTTER] Joining user room: user_$_userId');
        _socket!.emit('join_room', 'user_$_userId');
      }
      if (_currentChatRoom != null && _currentChatRoom!.isNotEmpty) {
        print('🔌 [FLUTTER] Re-joining chat room: $_currentChatRoom');
        _socket!.emit('join_chat_room', _currentChatRoom);
      }
    }

    _socket!.onConnect((_) {
      print('✅ [FLUTTER] Socket connected');
      joinRooms();
    });

    _socket!.onReconnect((_) {
      print('♻️ [FLUTTER] Socket reconnected');
      joinRooms();
    });

    _socket!.onConnectError((error) {
      print('❌ [FLUTTER] Socket connect error: $error');
    });

    _socket!.onDisconnect((_) {
      print('❌ [FLUTTER] Socket disconnected');
    });

    _socket!.onError((error) {
      print('❌ [FLUTTER] Socket error: $error');
    });

    if (!_listenersInitialized) {
      _setupBaseEventListeners();
      _listenersInitialized = true;
    }
  }

  void _setupBaseEventListeners() {
    print('🔌 [FLUTTER] Setting up base socket event listeners');

    // User events
    _socket?.on('user_approved', (data) {
      print('📡 [FLUTTER] User approved event: $data');
    });

    _socket?.on('user_rejected', (data) {
      print('📡 [FLUTTER] User rejected event: $data');
    });

    // Complaint events
    _socket?.on('complaint_assigned', (data) {
      print('📡 [FLUTTER] Complaint assigned event: $data');
    });

    _socket?.on('complaint_updated', (data) {
      print('📡 [FLUTTER] Complaint updated event: $data');
    });

    _socket?.on('work_update_added', (data) {
      print('📡 [FLUTTER] Work update added event: $data');
    });

    // Notice events
    _socket?.on('new_notice', (data) {
      print('📡 [FLUTTER] New notice event: $data');
    });

    // Building events
    _socket?.on('building_created', (data) {
      print('📡 [FLUTTER] Building created event: $data');
    });

    _socket?.on('user_created', (data) {
      print('📡 [FLUTTER] User created event: $data');
    });

    // Chat events - Community Chat
    _socket?.on('new_community_message', (data) {
      print('📡 [FLUTTER] New community message event: $data');
    });

    _socket?.on('message_pinned', (data) {
      print('📡 [FLUTTER] Message pinned event: $data');
    });

    _socket?.on('message_reaction', (data) {
      print('📡 [FLUTTER] Message reaction event: $data');
    });

    // Chat events - P2P Chat
    _socket?.on('p2p_message_sent', (data) {
      print('📡 [FLUTTER] P2P message sent event: $data');
    });

    _socket?.on('p2p_message_received', (data) {
      print('📡 [FLUTTER] P2P message received event: $data');
    });

    // Chat events - Complaint Chat
    _socket?.on('complaint_message', (data) {
      print('📡 [FLUTTER] Complaint message event: $data');
    });

    // User online/offline events
    _socket?.on('user_online', (data) {
      print('📡 [FLUTTER] User online event: $data');
    });

    _socket?.on('user_offline', (data) {
      print('📡 [FLUTTER] User offline event: $data');
    });
  }

  /// Join chat room (e.g. community_ABC1). Re-joined automatically on reconnect.
  void joinChatRoom(String roomName) {
    _currentChatRoom = roomName;
    _socket?.emit('join_chat_room', roomName);
    print('🔌 [FLUTTER] Joining chat room: $roomName');
  }

  /// Leave chat room. Clears re-join on reconnect.
  void leaveChatRoom(String roomName) {
    if (_currentChatRoom == roomName) _currentChatRoom = null;
    _socket?.emit('leave_chat_room', roomName);
    print('🔌 [FLUTTER] Leaving chat room: $roomName');
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
    _listenersInitialized = false;
    _currentChatRoom = null;
  }

  void on(String event, Function(dynamic) callback) {
    _socket?.on(event, callback);
  }

  void off(String event) {
    _socket?.off(event);
  }

  void emit(String event, dynamic data) {
    _socket?.emit(event, data);
  }

  bool get isConnected => _socket?.connected ?? false;
}
