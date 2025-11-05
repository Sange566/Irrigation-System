import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

/// Service for fetching analytics and statistics data
class AnalyticsService {
  static String get _baseUrl => ApiService.baseUrl;
  static const Duration timeout = Duration(seconds: 10);

  /// Get daily statistics
  static Future<Map<String, dynamic>> getDailyStats() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/daily_stats'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get daily stats');
      }
    } catch (e) {
      throw Exception('Error fetching daily stats: $e');
    }
  }

  /// Get historical telemetry data for charts
  static Future<Map<String, dynamic>> getHistoricalData({
    required String range,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/data?range=$range'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get historical data');
      }
    } catch (e) {
      throw Exception('Error fetching historical data: $e');
    }
  }

  /// Get action history for trigger analysis
  static Future<Map<String, dynamic>> getActionHistory({
    int limit = 100,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/action_history?limit=$limit'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get action history');
      }
    } catch (e) {
      throw Exception('Error fetching action history: $e');
    }
  }

  /// Get automation status for current metrics
  static Future<Map<String, dynamic>> getAutomationStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/automation_status'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get automation status');
      }
    } catch (e) {
      throw Exception('Error fetching automation status: $e');
    }
  }
}

