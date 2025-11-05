import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class BackendService {
  // Route through ApiService so configuration is centralized
  static String get _baseUrl => ApiService.baseUrl;
  static const Duration timeout = Duration(seconds: 10);

  // Start the irrigation pump
  static Future<Map<String, dynamic>> startPump() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/pump/start'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to start pump: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Backend not reachable: ${e.toString()}');
    }
  }

  // Stop the irrigation pump
  static Future<Map<String, dynamic>> stopPump() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/pump/stop'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to stop pump: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Backend not reachable: ${e.toString()}');
    }
  }

  // Set irrigation schedule
  static Future<Map<String, dynamic>> setSchedule({
    required String date,
    required String startTime,
    required String endTime,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/schedule'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'date': date,
          'start_time': startTime,
          'end_time': endTime,
        }),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to set schedule: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Backend not reachable: ${e.toString()}');
    }
  }

  // Get current system status
  static Future<Map<String, dynamic>> getStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/status'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Convert the response to match expected format
        return {
          'schedule_active': data['schedule_active']?.toString() ?? 'false',
          'start_time': data['start_time']?.toString() ?? 'Not Set',
          'end_time': data['end_time']?.toString() ?? 'Not Set',
        };
      } else {
        throw Exception('Failed to get status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Backend not reachable: ${e.toString()}');
    }
  }

  // Check if backend is reachable
  static Future<bool> isBackendReachable() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/status'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
