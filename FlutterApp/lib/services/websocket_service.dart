import 'dart:convert';
import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket Service for real-time data from FastAPI backend
/// Cross-platform: works on Web, Android, iOS
class WebSocketService {
  // WebSocket URL - Update to match backend location
  // For localhost: 'ws://localhost:8000/ws'
  // For network: 'ws://10.124.122.189:8000/ws' (WiFi network "Wifi")
  static String _serverUrl = 'ws://10.124.122.189:8000/ws';  // Backend V5 on WiFi network
  
  WebSocketChannel? _channel;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  bool _manualDisconnect = false;
  int _messageCount = 0;
  StreamSubscription? _streamSubscription;
  
  /// Get current server URL
  static String get serverUrl => _serverUrl;
  
  /// Set server URL (useful for connecting to backend on network)
  /// Example for Android emulator: 'ws://10.0.2.2:8000/ws'
  /// Example for physical device: 'ws://10.124.122.189:8000/ws'
  static void setServerUrl(String url) {
    _serverUrl = url;
  }
  
  // Callbacks for different data types
  Function(Map<String, dynamic>)? onPumpData;
  Function(Map<String, dynamic>)? onMoistureData;
  Function(bool)? onConnectionChange;
  Function(bool)? onAutomationStatus;

  /// Connect to WebSocket server
  Future<void> connect() async {
    if (_isConnected || _channel != null) {
      print('[WEBSOCKET] Already connected or connecting');
      return;
    }

    _manualDisconnect = false;
    
    try {
      print('[WEBSOCKET] Attempting connection to: $_serverUrl');
      
      // Create WebSocket channel (works on all platforms)
      final uri = Uri.parse(_serverUrl);
      _channel = WebSocketChannel.connect(uri);

      // Set up message listener
      _streamSubscription = _channel!.stream.listen(
        (message) {
          print('[WEBSOCKET] ✓ Raw message received: $message');
          _handleMessage(message);
        },
        onError: (error) {
          print('[WEBSOCKET] ✗ Connection error: $error');
          _handleDisconnection();
        },
        onDone: () {
          print('[WEBSOCKET] Connection closed');
          _handleDisconnection();
        },
        cancelOnError: true,
      );

      // Wait a moment to establish connection
      await Future.delayed(const Duration(milliseconds: 500));
      
      _isConnected = true;
      print('[WEBSOCKET] ✓ Successfully connected to $_serverUrl');
      print('[WEBSOCKET] ✓ Connection established, ready to receive data');
      onConnectionChange?.call(true);
      
      // Start periodic ping
      _startPingTimer();

    } catch (e) {
      print('[WEBSOCKET] ✗ Failed to connect: $e');
      print('[WEBSOCKET] Make sure backend is running and accessible');
      print('[WEBSOCKET] Android Emulator: Use ws://10.0.2.2:8000/ws');
      print('[WEBSOCKET] Physical Device: Use WiFi IP 10.124.122.189:8000/ws');
      _isConnected = false;
      _channel = null;
      onConnectionChange?.call(false);
      
      // Auto-reconnect after 5 seconds
      if (!_manualDisconnect) {
        print('[WEBSOCKET] Will retry connection in 5 seconds...');
        _scheduleReconnect();
      }
    }
  }

  /// Handle incoming WebSocket messages
  void _handleMessage(dynamic message) {
    try {
      // Handle pong response
      if (message == 'pong') {
        return;
      }
      
      final data = json.decode(message as String);
      
      if (data is! Map<String, dynamic>) {
        print('[WEBSOCKET] Received non-map data: $data');
        return;
      }

      final type = data['type'] as String?;
      _messageCount++;
      
      // Log every 10th message to avoid spam
      if (_messageCount % 10 == 1) {
        print('[WEBSOCKET] ✓ Received message #$_messageCount: type=$type');
      }

      switch (type) {
        case 'live_data':
          // Backend sends live data with payload field
          final payload = data['payload'];
          if (payload is Map<String, dynamic>) {
            // Check if it's pump data or moisture data
            if (payload.containsKey('pump_state') || payload.containsKey('flow_rate_Lmin')) {
              if (_messageCount % 10 == 1) {
                print('[WEBSOCKET] ✓ Processing pump data: flow=${payload['flow_rate_Lmin']}');
              }
              onPumpData?.call(payload);
            }
            if (payload.containsKey('moisture')) {
              onMoistureData?.call(payload);
            }
          }
          break;
          
        case 'pump_command':
          // Immediate pump command from backend (manual/automation/schedule)
          print('[WEBSOCKET] ✓ Pump command received: ${data['command']}');
          final command = data['command'] as String?;
          if (command != null) {
            // Send as pump data with just state update
            onPumpData?.call({
              'pump_state': command,
              'flow_rate_Lmin': 0.0,
              'total_volume': 0.0,
              'timestamp': data['timestamp'] ?? DateTime.now().toIso8601String(),
            });
          }
          break;
          
        case 'automation_status':
          // Backend sends automation status updates
          print('[WEBSOCKET] Received automation status update');
          if (data.containsKey('enabled')) {
            onAutomationStatus?.call(data['enabled'] as bool);
          }
          onMoistureData?.call(data);
          break;
          
        default:
          print('[WEBSOCKET] Unknown message type: $type');
      }
    } catch (e) {
      print('[WEBSOCKET] ✗ Error handling message: $e');
    }
  }

  /// Handle disconnection and schedule reconnect
  void _handleDisconnection() {
    if (!_isConnected) return;
    
    print('[WEBSOCKET] Handling disconnection...');
    _isConnected = false;
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _channel = null;
    _messageCount = 0;
    onConnectionChange?.call(false);
    
    // Auto-reconnect if not manually disconnected
    if (!_manualDisconnect) {
      print('[WEBSOCKET] Will attempt to reconnect...');
      _scheduleReconnect();
    }
  }

  /// Schedule automatic reconnection
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isConnected && !_manualDisconnect) {
        print('Attempting to reconnect WebSocket...');
        connect();
      }
    });
  }

  /// Start periodic ping to keep connection alive
  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (connected) {
        try {
          send('ping');
        } catch (e) {
          print('[WEBSOCKET] Ping failed: $e');
        }
      } else {
        timer.cancel();
      }
    });
  }

  /// Disconnect from WebSocket
  void disconnect() {
    print('[WEBSOCKET] Disconnecting...');
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _streamSubscription?.cancel();
    
    try {
      _channel?.sink.close();
    } catch (e) {
      print('[WEBSOCKET] Error closing: $e');
    }
    
    _channel = null;
    _streamSubscription = null;
    _isConnected = false;
    _messageCount = 0;
    onConnectionChange?.call(false);
    print('[WEBSOCKET] Disconnected');
  }

  /// Check connection status
  bool get connected => _isConnected && _channel != null;

  /// Send message to server (if needed)
  void send(String message) {
    if (connected) {
      try {
        _channel!.sink.add(message);
      } catch (e) {
        print('[WEBSOCKET] Error sending message: $e');
      }
    } else {
      print('[WEBSOCKET] Cannot send: WebSocket not connected');
    }
  }

  /// Set callback for pump data
  void setPumpDataCallback(Function(Map<String, dynamic>) callback) {
    onPumpData = callback;
  }

  /// Set callback for moisture data
  void setMoistureDataCallback(Function(Map<String, dynamic>) callback) {
    onMoistureData = callback;
  }

  /// Set callback for connection changes
  void setConnectionCallback(Function(bool) callback) {
    onConnectionChange = callback;
  }
  
  /// Set callback for automation status changes
  void setAutomationStatusCallback(Function(bool) callback) {
    onAutomationStatus = callback;
  }
}
