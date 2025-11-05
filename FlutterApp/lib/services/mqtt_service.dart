import 'dart:convert';
import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

/// Direct MQTT Service for ESP32 Communication
/// Connects directly to MQTT broker without backend intermediary
class MqttService {
  // MQTT Configuration (matching ESP32 settings)
  // WiFi Network: "Wifi" (Password: "password")
  // MQTT Broker IP: 10.124.122.189 (on WiFi network)
  static const String _broker = '10.124.122.189';  // MQTT broker on WiFi network
  static const int _port = 1883;
  static const String _clientId = 'flutter_app_client';
  
  // MQTT Topics (matching ESP32 configuration)
  static const String _pumpDataTopic = 'arc/water-monitoring/group6/water-sensor';
  static const String _commandTopic = 'grp6_irrigation_command';
  static const String _moistureTopic = 'irrigation/moisture-readings';
  
  // Device UID (matching ESP32)
  static const String _deviceUid = 'GROUP6_ESP32_01';
  
  // MQTT Client
  MqttServerClient? _client;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  
  // Callbacks for different data types
  Function(Map<String, dynamic>)? onPumpData;
  Function(Map<String, dynamic>)? onMoistureData;
  Function(bool)? onConnectionChange;
  
  // Connection status
  bool get isConnected => _isConnected;
  String get broker => _broker;
  int get port => _port;

  /// Connect to MQTT broker
  Future<void> connect() async {
    if (_isConnected && _client != null) {
      print('[MQTT] Already connected');
      return;
    }

    try {
      print('[MQTT] Connecting to broker: $_broker:$_port');
      
      // Create MQTT client
      _client = MqttServerClient.withPort(_broker, _clientId, _port);
      _client!.logging(on: false);
      _client!.keepAlivePeriod = 60;
      _client!.connectTimeoutPeriod = 5000; // 5 seconds
      _client!.autoReconnect = true;
      
      // Set up callbacks
      _client!.onConnected = _onConnected;
      _client!.onDisconnected = _onDisconnected;
      _client!.onSubscribed = _onSubscribed;
      _client!.onSubscribeFail = _onSubscribeFail;
      _client!.onAutoReconnect = _onAutoReconnect;
      _client!.onAutoReconnected = _onAutoReconnected;
      
      // Create connection message
      final connMessage = MqttConnectMessage()
          .withClientIdentifier(_clientId)
          .startClean()
          .withWillQos(MqttQos.atMostOnce);
      
      _client!.connectionMessage = connMessage;
      
      // Connect
      await _client!.connect();
      
    } catch (e) {
      print('[MQTT] ✗ Connection failed: $e');
      _handleConnectionFailure();
    }
  }

  /// Handle successful connection
  void _onConnected() {
    print('[MQTT] ✓ Successfully connected to broker');
    _isConnected = true;
    onConnectionChange?.call(true);
    
    // Subscribe to topics
    _subscribeToTopics();
    
    // Set up message listener
    _client!.updates!.listen(_onMessage);
  }

  /// Handle disconnection
  void _onDisconnected() {
    print('[MQTT] Disconnected from broker');
    _isConnected = false;
    onConnectionChange?.call(false);
  }

  /// Handle auto-reconnect attempt
  void _onAutoReconnect() {
    print('[MQTT] Attempting to reconnect...');
  }

  /// Handle successful auto-reconnect
  void _onAutoReconnected() {
    print('[MQTT] ✓ Auto-reconnected successfully');
    _isConnected = true;
    onConnectionChange?.call(true);
    _subscribeToTopics();
  }

  /// Handle subscription success
  void _onSubscribed(String topic) {
    print('[MQTT] ✓ Subscribed to: $topic');
  }

  /// Handle subscription failure
  void _onSubscribeFail(String topic) {
    print('[MQTT] ✗ Failed to subscribe to: $topic');
  }

  /// Subscribe to all required topics
  void _subscribeToTopics() {
    if (_client == null || !_isConnected) return;
    
    try {
      // Subscribe to pump data
      _client!.subscribe(_pumpDataTopic, MqttQos.atLeastOnce);
      print('[MQTT] Subscribing to pump data: $_pumpDataTopic');
      
      // Subscribe to moisture data
      _client!.subscribe(_moistureTopic, MqttQos.atLeastOnce);
      print('[MQTT] Subscribing to moisture data: $_moistureTopic');
      
    } catch (e) {
      print('[MQTT] ✗ Subscription error: $e');
    }
  }

  /// Handle incoming MQTT messages
  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final message in messages) {
      final topic = message.topic;
      final payload = message.payload as MqttPublishMessage;
      final messageText = MqttPublishPayload.bytesToStringAsString(payload.payload.message);
      
      try {
        // Parse JSON payload
        final data = json.decode(messageText) as Map<String, dynamic>;
        
        // Route to appropriate handler based on topic
        if (topic == _pumpDataTopic) {
          _handlePumpData(data);
        } else if (topic == _moistureTopic) {
          _handleMoistureData(data);
        }
        
      } catch (e) {
        print('[MQTT] ✗ Error parsing message from $topic: $e');
        print('[MQTT] Raw message: $messageText');
      }
    }
  }

  /// Handle pump data from MQTT
  void _handlePumpData(Map<String, dynamic> data) {
    try {
      // Verify this is from our device
      if (data['device_uid'] != _deviceUid) {
        return; // Ignore messages from other devices
      }
      
      print('[MQTT] ✓ Pump data received: pump_state=${data['pump_state']}, flow_rate=${data['flow_rate_Lmin']}');
      
      // Forward to callback
      onPumpData?.call(data);
      
    } catch (e) {
      print('[MQTT] ✗ Error handling pump data: $e');
    }
  }

  /// Handle moisture data from MQTT
  void _handleMoistureData(Map<String, dynamic> data) {
    try {
      // Verify this is from our device (or allow any device for moisture)
      if (data.containsKey('device_uid') && data['device_uid'] != _deviceUid) {
        // Allow moisture data from any device (could be from Group 2 sensors)
        // Comment out this return if you want to accept all moisture readings
        // return;
      }
      
      print('[MQTT] ✓ Moisture data received: moisture=${data['moisture']}%');
      
      // Forward to callback
      onMoistureData?.call(data);
      
    } catch (e) {
      print('[MQTT] ✗ Error handling moisture data: $e');
    }
  }

  /// Publish pump command to MQTT
  Future<bool> publishCommand(String command) async {
    if (!_isConnected || _client == null) {
      print('[MQTT] ✗ Cannot publish: Not connected');
      return false;
    }

    try {
      // Validate command
      if (command != 'ON' && command != 'OFF') {
        print('[MQTT] ✗ Invalid command: $command (must be ON or OFF)');
        return false;
      }

      print('[MQTT] Publishing command: $command to $_commandTopic');
      
      // Create message builder
      final builder = MqttClientPayloadBuilder();
      builder.addString(command);
      
      // Publish
      _client!.publishMessage(
        _commandTopic,
        MqttQos.atLeastOnce,
        builder.payload!,
      );
      
      print('[MQTT] ✓ Command published successfully: $command');
      return true;
      
    } catch (e) {
      print('[MQTT] ✗ Error publishing command: $e');
      return false;
    }
  }

  /// Publish pump ON command
  Future<bool> turnPumpOn() async {
    return await publishCommand('ON');
  }

  /// Publish pump OFF command
  Future<bool> turnPumpOff() async {
    return await publishCommand('OFF');
  }

  /// Handle connection failure
  void _handleConnectionFailure() {
    _isConnected = false;
    onConnectionChange?.call(false);
    
    // Schedule reconnection attempt
    _scheduleReconnect();
  }

  /// Schedule automatic reconnection
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isConnected) {
        print('[MQTT] Attempting to reconnect...');
        connect();
      }
    });
  }

  /// Disconnect from MQTT broker
  void disconnect() {
    print('[MQTT] Disconnecting...');
    _reconnectTimer?.cancel();
    
    try {
      _client?.disconnect();
    } catch (e) {
      print('[MQTT] Error during disconnect: $e');
    }
    
    _client = null;
    _isConnected = false;
    onConnectionChange?.call(false);
    print('[MQTT] Disconnected');
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

  /// Get connection info for debugging
  Map<String, dynamic> getConnectionInfo() {
    return {
      'broker': _broker,
      'port': _port,
      'connected': _isConnected,
      'client_id': _clientId,
      'device_uid': _deviceUid,
      'topics': {
        'pump_data': _pumpDataTopic,
        'commands': _commandTopic,
        'moisture': _moistureTopic,
      },
    };
  }
}

