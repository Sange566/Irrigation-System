import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../services/mqtt_service.dart';
import '../models/live_data_point.dart';

/// State management provider for irrigation system
class IrrigationProvider with ChangeNotifier {
  // Communication services
  final WebSocketService _wsService = WebSocketService();
  final MqttService _mqttService = MqttService();
  
  // Connection mode: 'mqtt' for direct MQTT, 'websocket' for backend WebSocket, 'api' for REST API
  // Default to 'api' for web compatibility (direct MQTT doesn't work well in browsers)
  String _connectionMode = 'api'; // Use backend API (works on all platforms)
  
  String get connectionMode => _connectionMode;

  // Connection states
  bool _isBackendConnected = false;
  bool _isWebSocketConnected = false;
  bool _isMqttConnected = false;
  bool _isLoading = false;
  String? _errorMessage;

  // Pump data
  bool _pumpStatus = false;
  double _flowRate = 0.0;
  double _totalWaterUsed = 0.0;
  DateTime? _lastPumpUpdate;

  // Moisture data
  double _soilMoisture = 0.0;
  double _temperature = 0.0;
  double _humidity = 0.0;
  DateTime? _lastMoistureUpdate;

  // Automation
  bool _automationEnabled = false;
  double _minMoistureThreshold = 25.0;
  double _maxMoistureThreshold = 60.0;
  String _soilStatus = "unknown";

  // Daily statistics
  double _todayUsage = 0.0;
  double _yesterdayUsage = 0.0;
  double _changePercent = 0.0;
  double _peakFlowRate = 0.0;
  DateTime? _lastStatsUpdate;

  // Historical data - stored as LiveDataPoint objects
  final List<LiveDataPoint> _liveDataHistory = [];
  final int _maxHistoryPoints = 288; // 24 hours at 5-min intervals
  
  // Chart data points
  final List<ChartDataPoint> _flowRateHistory = [];
  final List<ChartDataPoint> _waterUsageHistory = [];
  final List<ChartDataPoint> _moistureHistory = [];
  final List<ChartDataPoint> _temperatureHistory = [];
  
  // Legacy historical data (for API calls)
  List<Map<String, dynamic>> _historicalData = [];

  // Getters
  bool get isBackendConnected => _isBackendConnected;
  bool get isWebSocketConnected => _isWebSocketConnected;
  bool get isMqttConnected => _isMqttConnected;
  bool get isConnected {
    if (_connectionMode == 'mqtt') return _isMqttConnected;
    if (_connectionMode == 'api') return _isBackendConnected;
    return _isWebSocketConnected;
  }
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  bool get pumpStatus => _pumpStatus;
  double get flowRate => _flowRate;
  double get totalWaterUsed => _totalWaterUsed;
  DateTime? get lastPumpUpdate => _lastPumpUpdate;
  
  double get soilMoisture => _soilMoisture;
  double get temperature => _temperature;
  double get humidity => _humidity;
  DateTime? get lastMoistureUpdate => _lastMoistureUpdate;
  
  bool get automationEnabled => _automationEnabled;
  double get minMoistureThreshold => _minMoistureThreshold;
  double get maxMoistureThreshold => _maxMoistureThreshold;
  String get soilStatus => _soilStatus;
  
  // Backward compatibility
  double get moistureThreshold => _minMoistureThreshold;
  
  // Daily statistics getters
  double get todayUsage => _todayUsage;
  double get yesterdayUsage => _yesterdayUsage;
  double get changePercent => _changePercent;
  double get peakFlowRate => _peakFlowRate;
  DateTime? get lastStatsUpdate => _lastStatsUpdate;
  
  List<Map<String, dynamic>> get historicalData => _historicalData;
  
  // Real-time data getters
  List<LiveDataPoint> get liveDataHistory => List.unmodifiable(_liveDataHistory);
  List<ChartDataPoint> get flowRateHistory => List.unmodifiable(_flowRateHistory);
  List<ChartDataPoint> get waterUsageHistory => List.unmodifiable(_waterUsageHistory);
  List<ChartDataPoint> get moistureHistory => List.unmodifiable(_moistureHistory);
  List<ChartDataPoint> get temperatureHistory => List.unmodifiable(_temperatureHistory);
  
  // Latest data point
  LiveDataPoint? get latestDataPoint => _liveDataHistory.isNotEmpty ? _liveDataHistory.last : null;
  
  // Statistics from live data
  double get averageFlowRate {
    if (_flowRateHistory.isEmpty) return 0.0;
    // Only calculate average from non-zero values (when pump is ON)
    final nonZeroPoints = _flowRateHistory.where((point) => point.value > 0.0).toList();
    if (nonZeroPoints.isEmpty) return 0.0;
    final sum = nonZeroPoints.fold<double>(0.0, (sum, point) => sum + point.value);
    return sum / nonZeroPoints.length;
  }
  
  // Peak flow rate is now from daily stats API
  double get peakFlowRateFromHistory {
    if (_flowRateHistory.isEmpty) return 0.0;
    return _flowRateHistory.map((p) => p.value).reduce((a, b) => a > b ? a : b);
  }

  /// Initialize provider - connect to backend and real-time service
  Future<void> initialize() async {
    print('[PROVIDER] Initializing IrrigationProvider...');
    print('[PROVIDER] Connection mode: $_connectionMode');
    print('[PROVIDER] API URL: ${ApiService.baseUrl}');
    print('[PROVIDER] WebSocket URL: ${WebSocketService.serverUrl}');
    
    await checkBackendConnection();
    
    print('[PROVIDER] Backend connected: $_isBackendConnected');
    
    // For web browsers, always use WebSocket for real-time data
    // Direct MQTT doesn't work reliably in browsers
    if (_connectionMode == 'api' || _connectionMode == 'websocket') {
      if (_isBackendConnected) {
        print('[PROVIDER] Attempting WebSocket connection...');
        connectWebSocket();  // Get real-time data via WebSocket
      } else {
        print('[PROVIDER] ⚠️ Backend not reachable, skipping WebSocket connection');
      }
    } else if (_connectionMode == 'mqtt') {
      connectMqtt();  // Only for native apps (iOS/Android)
    }
    
    // Load initial data from backend if available
    if (_isBackendConnected) {
      await loadAutomationStatus();
      await loadDailyStats();
    } else {
      print('[PROVIDER] ⚠️ Backend not reachable, skipping data loading');
    }
    
    print('[PROVIDER] ✓ Initialization complete');
  }
  
  /// Switch connection mode
  void setConnectionMode(String mode) {
    if (mode != 'mqtt' && mode != 'websocket' && mode != 'api') {
      print('[PROVIDER] Invalid connection mode: $mode');
      return;
    }
    
    if (_connectionMode == mode) return;
    
    // Disconnect current connection
    if (_connectionMode == 'mqtt') {
      _mqttService.disconnect();
    } else {
      _wsService.disconnect();
    }
    
    // Switch mode
    _connectionMode = mode;
    
    // Connect with new mode
    if (_connectionMode == 'mqtt') {
      connectMqtt();
    } else {
      // For 'api' and 'websocket' modes, use WebSocket for real-time
      connectWebSocket();
    }
    
    notifyListeners();
  }

  /// Check if backend is reachable
  Future<void> checkBackendConnection() async {
    print('[PROVIDER] Checking backend connection at ${ApiService.baseUrl}...');
    try {
      _isBackendConnected = await ApiService.isBackendReachable();
      if (_isBackendConnected) {
        print('[PROVIDER] ✓ Backend is reachable');
      } else {
        print('[PROVIDER] ✗ Backend returned non-200 status');
      }
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      print('[PROVIDER] ✗ Backend connection error: $e');
      _isBackendConnected = false;
      _errorMessage = 'Backend not reachable';
      notifyListeners();
    }
  }

  /// Connect to WebSocket for real-time updates
  void connectWebSocket() {
    print('[PROVIDER] Setting up WebSocket callbacks...');
    
    _wsService.setConnectionCallback((connected) {
      print('[PROVIDER] WebSocket connection status changed: $connected');
      _isWebSocketConnected = connected;
      notifyListeners();
    });

    _wsService.setPumpDataCallback((data) {
      print('[PROVIDER] Received pump data via WebSocket');
      _handlePumpData(data);
    });

    _wsService.setMoistureDataCallback((data) {
      print('[PROVIDER] Received moisture data via WebSocket');
      _handleMoistureData(data);
    });
    
    _wsService.setAutomationStatusCallback((enabled) {
      print('[PROVIDER] Automation status update: $enabled');
      _automationEnabled = enabled;
      notifyListeners();
    });

    print('[PROVIDER] Initiating WebSocket connection to ${WebSocketService.serverUrl}...');
    _wsService.connect();
  }

  /// Connect to MQTT for direct real-time updates
  void connectMqtt() {
    print('[PROVIDER] Connecting to MQTT broker...');
    
    _mqttService.setConnectionCallback((connected) {
      _isMqttConnected = connected;
      if (connected) {
        print('[PROVIDER] ✓ MQTT connected successfully');
      } else {
        print('[PROVIDER] ✗ MQTT disconnected');
      }
      notifyListeners();
    });

    _mqttService.setPumpDataCallback((data) {
      print('[PROVIDER] MQTT pump data received');
      _handlePumpData(data);
    });

    _mqttService.setMoistureDataCallback((data) {
      print('[PROVIDER] MQTT moisture data received');
      _handleMoistureData(data);
    });

    _mqttService.connect();
  }

  /// Handle pump data from WebSocket - Backend version 3.py format
  void _handlePumpData(Map<String, dynamic> data) {
    try {
      print('[PROVIDER] ✓ Received pump data: $data');
      
      // Create LiveDataPoint from WebSocket data
      final dataPoint = LiveDataPoint.fromJson(data);
      
      // Update current state
      _pumpStatus = dataPoint.pumpState.toUpperCase() == 'ON';
      _flowRate = dataPoint.flowRate;
      _totalWaterUsed = dataPoint.totalVolume;
      _lastPumpUpdate = DateTime.now();
      
      print('[PROVIDER] Updated state - Pump: ${_pumpStatus ? 'ON' : 'OFF'}, Flow: $_flowRate L/min, Total: $_totalWaterUsed L');
      
      // Store in history (limit to max points)
      _liveDataHistory.add(dataPoint);
      if (_liveDataHistory.length > _maxHistoryPoints) {
        _liveDataHistory.removeAt(0);
      }
      
      // Update chart data points
      _flowRateHistory.add(ChartDataPoint(
        timestamp: dataPoint.timestamp,
        value: dataPoint.flowRate,
      ));
      if (_flowRateHistory.length > _maxHistoryPoints) {
        _flowRateHistory.removeAt(0);
      }
      
      _waterUsageHistory.add(ChartDataPoint(
        timestamp: dataPoint.timestamp,
        value: dataPoint.totalVolume,
      ));
      if (_waterUsageHistory.length > _maxHistoryPoints) {
        _waterUsageHistory.removeAt(0);
      }
      
      print('[PROVIDER] ✓ Added to history - Flow points: ${_flowRateHistory.length}, Water points: ${_waterUsageHistory.length}, Live points: ${_liveDataHistory.length}');
      
      notifyListeners();
    } catch (e) {
      print('[PROVIDER] ✗ Error handling pump data: $e');
      print('[PROVIDER] Data received: $data');
    }
  }

  /// Parse moisture value from string or number
  double _parseMoisture(dynamic value) {
    if (value == null) return 0.0;
    
    if (value is num) {
      return value.toDouble();
    }
    
    if (value is String) {
      // Remove any non-numeric characters except decimal point
      // Handles formats like "0 %", "45.5%", "30", etc.
      final cleaned = value.replaceAll(RegExp(r'[^0-9.]'), '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    
    return 0.0;
  }

  /// Handle moisture data from WebSocket
  void _handleMoistureData(Map<String, dynamic> data) {
    try {
      print('Processing moisture data: $data');
      
      final now = DateTime.now();
      
      if (data.containsKey('moisture')) {
        _soilMoisture = _parseMoisture(data['moisture']);
        print('Soil moisture updated: $_soilMoisture%');
        
        // Add to moisture history
        _moistureHistory.add(ChartDataPoint(
          timestamp: now,
          value: _soilMoisture,
        ));
        if (_moistureHistory.length > _maxHistoryPoints) {
          _moistureHistory.removeAt(0);
        }
      }
      
      // Also handle flow_rate and total_flow from live_data payload
      // This updates the display immediately when data comes in
      if (data.containsKey('flow_rate')) {
        _flowRate = (data['flow_rate'] as num?)?.toDouble() ?? 0.0;
        
        // Track peak flow rate
        if (_flowRate > _peakFlowRate) {
          _peakFlowRate = _flowRate;
        }
      }
      if (data.containsKey('total_flow')) {
        final newTotal = (data['total_flow'] as num?)?.toDouble() ?? 0.0;
        _totalWaterUsed = newTotal;
        
        // Update today's usage (assuming total_flow is today's cumulative)
        if (newTotal > _todayUsage) {
          _todayUsage = newTotal;
        }
      }
      if (data.containsKey('pump_status')) {
        final status = data['pump_status']?.toString().toUpperCase() ?? 'OFF';
        _pumpStatus = status == 'ON';
      }
      
      if (data.containsKey('temperature')) {
        _temperature = (data['temperature'] as num?)?.toDouble() ?? 0.0;
        
        // Add to temperature history
        _temperatureHistory.add(ChartDataPoint(
          timestamp: now,
          value: _temperature,
        ));
        if (_temperatureHistory.length > _maxHistoryPoints) {
          _temperatureHistory.removeAt(0);
        }
      }
      if (data.containsKey('humidity')) {
        _humidity = (data['humidity'] as num?)?.toDouble() ?? 0.0;
      }
      // Backend automation_status format
      if (data.containsKey('enabled')) {
        _automationEnabled = data['enabled'] as bool? ?? false;
      }
      
      _lastMoistureUpdate = DateTime.now();
      notifyListeners();
    } catch (e) {
      print('Error handling moisture data: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  /// Turn pump ON
  Future<String> turnPumpOn() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      bool success = false;
      
      // Use MQTT direct connection if in MQTT mode
      if (_connectionMode == 'mqtt') {
        if (!_isMqttConnected) {
          _isLoading = false;
          notifyListeners();
          return 'MQTT not connected';
        }
        success = await _mqttService.turnPumpOn();
      } else {
        // Use backend API (works for both 'api' and 'websocket' modes)
        if (!_isBackendConnected) {
          // Try to connect to backend first
          await checkBackendConnection();
          if (!_isBackendConnected) {
            _isLoading = false;
            notifyListeners();
            return 'Backend not connected';
          }
        }
        final response = await ApiService.turnPumpOn();
        success = response['status'] == 'success';
      }
      
      if (success) {
        _pumpStatus = true;
        _isLoading = false;
        notifyListeners();
        return 'Pump turned ON successfully';
      } else {
        _isLoading = false;
        notifyListeners();
        return 'Failed to turn pump ON';
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return 'Error: ${e.toString()}';
    }
  }

  /// Turn pump OFF
  Future<String> turnPumpOff() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      bool success = false;
      
      // Use MQTT direct connection if in MQTT mode
      if (_connectionMode == 'mqtt') {
        if (!_isMqttConnected) {
          _isLoading = false;
          notifyListeners();
          return 'MQTT not connected';
        }
        success = await _mqttService.turnPumpOff();
      } else {
        // Use backend API (works for both 'api' and 'websocket' modes)
        if (!_isBackendConnected) {
          // Try to connect to backend first
          await checkBackendConnection();
          if (!_isBackendConnected) {
            _isLoading = false;
            notifyListeners();
            return 'Backend not connected';
          }
        }
        final response = await ApiService.turnPumpOff();
        success = response['status'] == 'success';
      }
      
      if (success) {
        _pumpStatus = false;
        _isLoading = false;
        notifyListeners();
        return 'Pump turned OFF successfully';
      } else {
        _isLoading = false;
        notifyListeners();
        return 'Failed to turn pump OFF';
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return 'Error: ${e.toString()}';
    }
  }

  /// Toggle automation
  Future<String> toggleAutomation({required bool enable}) async {
    if (!_isBackendConnected) {
      return 'Backend not connected';
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.toggleAutomation(enable: enable);
      _automationEnabled = enable;
      _isLoading = false;
      notifyListeners();
      return response['message'] ?? 
        (enable ? 'Automation enabled' : 'Automation disabled');
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return 'Error: ${e.toString()}';
    }
  }

  /// Update moisture threshold
  Future<String> updateMoistureThreshold(double threshold) async {
    if (!_isBackendConnected) {
      return 'Backend not connected';
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.updateMoistureThreshold(threshold: threshold);
      _minMoistureThreshold = threshold;
      _isLoading = false;
      notifyListeners();
      return response['message'] ?? 'Threshold updated successfully';
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return 'Error: ${e.toString()}';
    }
  }

  /// Update dual moisture thresholds (min and max)
  Future<String> updateDualThresholds({
    required double minThreshold,
    required double maxThreshold,
  }) async {
    if (!_isBackendConnected) {
      return 'Backend not connected';
    }

    if (minThreshold >= maxThreshold) {
      return 'Min threshold must be less than max threshold';
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.updateDualThresholds(
        minThreshold: minThreshold,
        maxThreshold: maxThreshold,
      );
      _minMoistureThreshold = minThreshold;
      _maxMoistureThreshold = maxThreshold;
      _isLoading = false;
      notifyListeners();
      return response['message'] ?? 'Thresholds updated successfully';
    } catch (e) {
      // Fallback: Try updating min threshold only (for older backend versions)
      print('[PROVIDER] Dual threshold API not available, using single threshold');
      return await updateMoistureThreshold(minThreshold);
    }
  }

  /// Update soil status based on moisture and thresholds
  void updateSoilStatus() {
    if (_soilMoisture < _minMoistureThreshold) {
      _soilStatus = "dry";
    } else if (_soilMoisture > _maxMoistureThreshold) {
      _soilStatus = "wet";
    } else {
      _soilStatus = "optimal";
    }
    notifyListeners();
  }

  /// Get pump action history from backend
  Future<List<Map<String, dynamic>>> getActionHistory({int limit = 50}) async {
    if (!_isBackendConnected) {
      print('[PROVIDER] Backend not connected, cannot fetch action history');
      return [];
    }

    try {
      final response = await ApiService.getActionHistory(limit: limit);
      final actions = response['actions'] as List? ?? [];
      return actions.map((action) => action as Map<String, dynamic>).toList();
    } catch (e) {
      print('[PROVIDER] Error fetching action history: $e');
      return [];
    }
  }

  /// Load automation status from backend
  Future<void> loadAutomationStatus() async {
    if (!_isBackendConnected) return;

    try {
      final response = await ApiService.getAutomationStatus();
      print('Automation status response: $response');
      
      // Backend returns: {automation_enabled: bool, moisture_threshold: num, current_moisture: num}
      _automationEnabled = response['automation_enabled'] ?? false;
      
      // Load thresholds if available (dual threshold support)
      if (response['min_threshold'] != null) {
        _minMoistureThreshold = (response['min_threshold'] as num).toDouble();
      }
      if (response['max_threshold'] != null) {
        _maxMoistureThreshold = (response['max_threshold'] as num).toDouble();
      }
      
      // Backward compatibility: single threshold
      if (response['moisture_threshold'] != null) {
        _minMoistureThreshold = (response['moisture_threshold'] as num).toDouble();
      }
      if (response.containsKey('threshold')) {
        _minMoistureThreshold = (response['threshold'] as num?)?.toDouble() ?? 30.0;
      }
      
      // Load current moisture if available
      if (response['current_moisture'] != null) {
        _soilMoisture = (response['current_moisture'] as num).toDouble();
        _lastMoistureUpdate = DateTime.now();
        print('Loaded current moisture from backend: $_soilMoisture%');
      }
      if (response.containsKey('last_moisture')) {
        _soilMoisture = (response['last_moisture'] as num?)?.toDouble() ?? 0.0;
      }
      
      // Update soil status
      updateSoilStatus();
      
      notifyListeners();
    } catch (e) {
      print('Error loading automation status: $e');
    }
  }

  /// Load historical data
  Future<void> loadHistoricalData({String range = 'day'}) async {
    if (!_isBackendConnected) return;

    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.getHistoricalData(range: range);
      if (response.containsKey('data') && response['data'] is List) {
        _historicalData = List<Map<String, dynamic>>.from(response['data']);
      }
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Load daily water usage statistics
  Future<void> loadDailyStats() async {
    if (!_isBackendConnected) return;

    try {
      final response = await ApiService.getDailyStats();
      _todayUsage = (response['today_usage'] as num?)?.toDouble() ?? 0.0;
      _yesterdayUsage = (response['yesterday_usage'] as num?)?.toDouble() ?? 0.0;
      _changePercent = (response['change_percent'] as num?)?.toDouble() ?? 0.0;
      _peakFlowRate = (response['peak_flow_rate'] as num?)?.toDouble() ?? 0.0;
      _lastStatsUpdate = DateTime.now();
      
      print('Daily stats loaded: Today=$_todayUsage L, Yesterday=$_yesterdayUsage L, Change=$_changePercent%');
      notifyListeners();
    } catch (e) {
      print('Error loading daily stats: $e');
    }
  }

  /// Refresh all data
  Future<void> refreshAll() async {
    await checkBackendConnection();
    if (_isBackendConnected) {
      await loadAutomationStatus();
      await loadHistoricalData();
      await loadDailyStats();
    }
  }

  /// Clear historical data
  void clearHistory() {
    _liveDataHistory.clear();
    _flowRateHistory.clear();
    _waterUsageHistory.clear();
    _moistureHistory.clear();
    _temperatureHistory.clear();
    notifyListeners();
  }
  
  /// Get data for specific time range
  List<ChartDataPoint> getFlowRateForRange(Duration duration) {
    final cutoff = DateTime.now().subtract(duration);
    return _flowRateHistory
        .where((point) => point.timestamp.isAfter(cutoff))
        .toList();
  }
  
  List<ChartDataPoint> getWaterUsageForRange(Duration duration) {
    final cutoff = DateTime.now().subtract(duration);
    return _waterUsageHistory
        .where((point) => point.timestamp.isAfter(cutoff))
        .toList();
  }
  
  List<ChartDataPoint> getMoistureForRange(Duration duration) {
    final cutoff = DateTime.now().subtract(duration);
    return _moistureHistory
        .where((point) => point.timestamp.isAfter(cutoff))
        .toList();
  }
  
  List<ChartDataPoint> getTemperatureForRange(Duration duration) {
    final cutoff = DateTime.now().subtract(duration);
    return _temperatureHistory
        .where((point) => point.timestamp.isAfter(cutoff))
        .toList();
  }
  
  /// Dispose resources
  @override
  void dispose() {
    _wsService.disconnect();
    _mqttService.disconnect();
    super.dispose();
  }
  
  /// Get MQTT connection info (for debugging)
  Map<String, dynamic> getMqttInfo() {
    return _mqttService.getConnectionInfo();
  }
}

