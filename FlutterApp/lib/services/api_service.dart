import 'dart:convert';
import 'package:http/http.dart' as http;

/// API Service for connecting to FastAPI backend
class ApiService {
  // Backend URL - Update this to match where backend_fastapi5.py is running
  // For localhost: 'http://localhost:8000'
  // For network: 'http://10.124.122.189:8000' (WiFi network "Wifi")
  static String _baseUrl = 'http://10.124.122.189:8000';  // Backend V5 on WiFi network
  static const Duration timeout = Duration(seconds: 10);
  
  /// Get current base URL
  static String get baseUrl => _baseUrl;
  
  /// Set base URL (useful for connecting to backend on network)
  static void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  /// Turn irrigation pump ON
  static Future<Map<String, dynamic>> turnPumpOn() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/control/turn_on'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Backend returns: {status: "success", command: "on"}
        return {
          'message': 'Pump turned ON successfully',
          'status': data['status'],
          'command': data['command'],
        };
      } else {
        throw Exception('Failed to turn pump on: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Backend not reachable: ${e.toString()}');
    }
  }

  /// Turn irrigation pump OFF
  static Future<Map<String, dynamic>> turnPumpOff() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/control/turn_off'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Backend returns: {status: "success", command: "off"}
        return {
          'message': 'Pump turned OFF successfully',
          'status': data['status'],
          'command': data['command'],
        };
      } else {
        throw Exception('Failed to turn pump off: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Backend not reachable: ${e.toString()}');
    }
  }

  /// Toggle automation ON/OFF
  static Future<Map<String, dynamic>> toggleAutomation({required bool enable}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/control/automation_toggle'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'enable': enable}),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Backend returns: {status: "success", automation_enabled: bool}
        return {
          'message': enable ? 'Automation enabled' : 'Automation disabled',
          'status': data['status'],
          'automation_enabled': data['automation_enabled'],
        };
      } else {
        throw Exception('Failed to toggle automation: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Backend not reachable: ${e.toString()}');
    }
  }

  /// Get automation status
  static Future<Map<String, dynamic>> getAutomationStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/automation_status'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get automation status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Backend not reachable: ${e.toString()}');
    }
  }

  /// Get historical data for charts
  /// [range] can be: 'hour', 'day', 'week', 'month'
  static Future<Map<String, dynamic>> getHistoricalData({required String range}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/data?range=$range'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get historical data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Backend not reachable: ${e.toString()}');
    }
  }

  /// Get API documentation
  static Future<Map<String, dynamic>> getApiDocs() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get API docs: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Backend not reachable: ${e.toString()}');
    }
  }

  /// Check if backend is reachable
  static Future<bool> isBackendReachable() async {
    try {
      print('[API] Testing connection to: $baseUrl/');
      final response = await http.get(
        Uri.parse('$baseUrl/'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      print('[API] Response status: ${response.statusCode}');
      print('[API] Response body preview: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}');
      
      if (response.statusCode == 200) {
        print('[API] ✓ Backend is reachable');
        return true;
      } else {
        print('[API] ✗ Backend returned status ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('[API] ✗ Connection error: $e');
      return false;
    }
  }

  /// Get daily water usage statistics
  static Future<Map<String, dynamic>> getDailyStats() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/daily_stats'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get daily stats: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Backend not reachable: ${e.toString()}');
    }
  }

  /// Update moisture threshold for automation (backward compatibility - uses min threshold)
  static Future<Map<String, dynamic>> updateMoistureThreshold({required double threshold}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/automation/threshold'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'min_threshold': threshold}),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to update threshold: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Backend not reachable: ${e.toString()}');
    }
  }

  /// Update dual moisture thresholds (min and max) for automation
  static Future<Map<String, dynamic>> updateDualThresholds({
    required double minThreshold,
    required double maxThreshold,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/automation/threshold'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'min_threshold': minThreshold,
          'max_threshold': maxThreshold,
        }),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to update thresholds: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Backend not reachable: ${e.toString()}');
    }
  }

  /// Get pump action history
  static Future<Map<String, dynamic>> getActionHistory({int limit = 50}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/action_history?limit=$limit'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get action history: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Backend not reachable: ${e.toString()}');
    }
  }

  // ==========================================
  // Schedule Management APIs (Backend V5)
  // ==========================================

  /// Add a new irrigation schedule
  static Future<Map<String, dynamic>> addSchedule({
    required String day,
    required String time,
    required int durationMinutes,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/schedule/add'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'day': day,
          'time': time,
          'duration_minutes': durationMinutes,
        }),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to add schedule: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Backend not reachable: ${e.toString()}');
    }
  }

  /// Get all active schedules
  static Future<Map<String, dynamic>> getSchedules() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/schedule/list'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get schedules: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Backend not reachable: ${e.toString()}');
    }
  }

  /// Remove a schedule by job ID
  static Future<Map<String, dynamic>> removeSchedule({required int jobId}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/schedule/remove'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'job_id': jobId}),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to remove schedule: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Backend not reachable: ${e.toString()}');
    }
  }

  /// Toggle scheduling system on/off
  static Future<Map<String, dynamic>> toggleScheduling({required bool enable}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/schedule/toggle'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'enable': enable}),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to toggle scheduling: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Backend not reachable: ${e.toString()}');
    }
  }
}

