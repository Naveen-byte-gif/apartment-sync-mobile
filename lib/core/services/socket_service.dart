import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../constants/api_constants.dart';
import 'storage_service.dart';
import '../constants/app_constants.dart';

class SocketService {
  IO.Socket? _socket;
  String? _userId;

  void connect(String userId) {
    print('🔌 [FLUTTER] Connecting to socket...');
    _userId = userId;
    final token = StorageService.getString(AppConstants.tokenKey);
    
    print('🔌 [FLUTTER] Socket URL: ${ApiConstants.socketUrl}');
    print('🔌 [FLUTTER] User ID: $userId');
    
    _socket = IO.io(
      ApiConstants.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .enableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      print('✅ [FLUTTER] Socket connected');
      print('🔌 [FLUTTER] Joining user room: user_$userId');
      _socket!.emit('join_room', 'user_$userId');
    });

    _socket!.onDisconnect((_) {
      print('❌ [FLUTTER] Socket disconnected');
    });

    _socket!.onError((error) {
      print('❌ [FLUTTER] Socket error: $error');
    });

    // Listen for real-time events
    _setupEventListeners();
  }

  void _setupEventListeners() {
    print('🔌 [FLUTTER] Setting up socket event listeners');
    
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
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
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

