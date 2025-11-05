import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

/// API Service for schedule management
class ScheduleApiService {
  static String get _baseUrl => ApiService.baseUrl;
  static const Duration timeout = Duration(seconds: 10);

  /// Add new schedule
  static Future<Map<String, dynamic>> addSchedule({
    required String day,
    required String time,
    required int duration,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/schedule/add'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'day': day,
          'time': time,
          'duration': duration,
        }),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Failed to add schedule');
      }
    } catch (e) {
      throw Exception('Error adding schedule: ${e.toString()}');
    }
  }

  /// Get all schedules
  static Future<Map<String, dynamic>> getSchedules() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/schedule/list'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to fetch schedules: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching schedules: ${e.toString()}');
    }
  }

  /// Remove schedule
  static Future<Map<String, dynamic>> removeSchedule(int jobId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/schedule/remove'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'job_id': jobId}),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Failed to remove schedule');
      }
    } catch (e) {
      throw Exception('Error removing schedule: ${e.toString()}');
    }
  }

  /// Toggle scheduling on/off
  static Future<Map<String, dynamic>> toggleScheduling(bool enable) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/schedule/toggle'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'enable': enable}),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Failed to toggle scheduling');
      }
    } catch (e) {
      throw Exception('Error toggling scheduling: ${e.toString()}');
    }
  }
}

