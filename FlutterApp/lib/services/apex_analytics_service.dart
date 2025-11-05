import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for Oracle APEX Analytics API
/// Connects directly to Oracle APEX REST endpoints
class ApexAnalyticsService {
  // Oracle APEX Base URL
  static const String _baseUrl = 'https://oracleapex.com/ords/g3_data';
  static const Duration timeout = Duration(seconds: 15);
  
  // Headers for APEX API
  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// Get telemetry data from APEX
  static Future<Map<String, dynamic>> getTelemetryData({
    String? deviceUid,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      var url = '$_baseUrl/TELEMETRY_DATA/';
      
      // Add query parameters
      final params = <String, String>{};
      if (limit != null) params['limit'] = limit.toString();
      
      if (params.isNotEmpty) {
        url += '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
      }
      
      print('[APEX] Fetching telemetry from: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: _headers,
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('[APEX] ✓ Telemetry data fetched: ${data['items']?.length ?? 0} records');
        return data;
      } else {
        throw Exception('Failed to fetch telemetry: ${response.statusCode}');
      }
    } catch (e) {
      print('[APEX] ✗ Error fetching telemetry: $e');
      throw Exception('Error fetching telemetry data: $e');
    }
  }

  /// Get devices from APEX
  static Future<Map<String, dynamic>> getDevices() async {
    try {
      final url = '$_baseUrl/irrigation/devices/';
      print('[APEX] Fetching devices from: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: _headers,
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('[APEX] ✓ Devices fetched: ${data['items']?.length ?? 0} devices');
        return data;
      } else {
        throw Exception('Failed to fetch devices: ${response.statusCode}');
      }
    } catch (e) {
      print('[APEX] ✗ Error fetching devices: $e');
      throw Exception('Error fetching devices: $e');
    }
  }

  /// Get devices (alternative endpoint)
  static Future<Map<String, dynamic>> getDevicesFinal() async {
    try {
      final url = '$_baseUrl/final/get_devices/';
      print('[APEX] Fetching devices from final endpoint: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: _headers,
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('[APEX] ✓ Devices (final) fetched');
        return data;
      } else {
        throw Exception('Failed to fetch devices (final): ${response.statusCode}');
      }
    } catch (e) {
      print('[APEX] ✗ Error fetching devices (final): $e');
      throw Exception('Error fetching devices (final): $e');
    }
  }

  /// Post alert to APEX
  static Future<Map<String, dynamic>> postAlert({
    required String deviceUid,
    required String alertType,
    required String message,
    required String severity,
    String status = 'new',
  }) async {
    try {
      final url = '$_baseUrl/irrigation/alert/';
      final body = {
        'device_uid': deviceUid,
        'alert_type': alertType,
        'message': message,
        'severity': severity,
        'status': status,
      };
      
      print('[APEX] Posting alert to: $url');
      
      final response = await http.post(
        Uri.parse(url),
        headers: _headers,
        body: json.encode(body),
      ).timeout(timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('[APEX] ✓ Alert posted successfully');
        return json.decode(response.body);
      } else {
        throw Exception('Failed to post alert: ${response.statusCode}');
      }
    } catch (e) {
      print('[APEX] ✗ Error posting alert: $e');
      throw Exception('Error posting alert: $e');
    }
  }

  /// Post audit record to APEX
  static Future<Map<String, dynamic>> postAudit({
    required String deviceUid,
    required String eventType,
    required String description,
    String? source,
  }) async {
    try {
      final url = '$_baseUrl/irrigation/audit/';
      final body = {
        'device_uid': deviceUid,
        'event_type': eventType,
        'description': description,
        'source': source ?? 'flutter_app',
      };
      
      print('[APEX] Posting audit to: $url');
      
      final response = await http.post(
        Uri.parse(url),
        headers: _headers,
        body: json.encode(body),
      ).timeout(timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('[APEX] ✓ Audit posted successfully');
        return json.decode(response.body);
      } else {
        throw Exception('Failed to post audit: ${response.statusCode}');
      }
    } catch (e) {
      print('[APEX] ✗ Error posting audit: $e');
      throw Exception('Error posting audit: $e');
    }
  }

  /// Post schedule to APEX
  static Future<Map<String, dynamic>> postSchedule({
    required String deviceUid,
    required String scheduleType,
    required String scheduleTime,
    required int duration,
    String? days,
  }) async {
    try {
      final url = '$_baseUrl/irrigation/schedule/';
      final body = {
        'device_uid': deviceUid,
        'schedule_type': scheduleType,
        'schedule_time': scheduleTime,
        'duration': duration,
        if (days != null) 'days': days,
      };
      
      print('[APEX] Posting schedule to: $url');
      
      final response = await http.post(
        Uri.parse(url),
        headers: _headers,
        body: json.encode(body),
      ).timeout(timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('[APEX] ✓ Schedule posted successfully');
        return json.decode(response.body);
      } else {
        throw Exception('Failed to post schedule: ${response.statusCode}');
      }
    } catch (e) {
      print('[APEX] ✗ Error posting schedule: $e');
      throw Exception('Error posting schedule: $e');
    }
  }

  /// Post device data to APEX
  static Future<Map<String, dynamic>> postDevice({
    required String deviceUid,
    required String deviceName,
    required String deviceType,
    String? location,
    String status = 'active',
  }) async {
    try {
      final url = '$_baseUrl/final/post_devices/';
      final body = {
        'device_uid': deviceUid,
        'device_name': deviceName,
        'device_type': deviceType,
        if (location != null) 'location': location,
        'status': status,
      };
      
      print('[APEX] Posting device to: $url');
      
      final response = await http.post(
        Uri.parse(url),
        headers: _headers,
        body: json.encode(body),
      ).timeout(timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('[APEX] ✓ Device posted successfully');
        return json.decode(response.body);
      } else {
        throw Exception('Failed to post device: ${response.statusCode}');
      }
    } catch (e) {
      print('[APEX] ✗ Error posting device: $e');
      throw Exception('Error posting device: $e');
    }
  }

  /// Calculate analytics from telemetry data
  static Map<String, dynamic> calculateAnalytics(List<dynamic> telemetryData) {
    if (telemetryData.isEmpty) {
      return {
        'total_water_used': 0.0,
        'avg_flow_rate': 0.0,
        'avg_moisture': 0.0,
        'pump_on_time': 0,
        'pump_off_time': 0,
        'total_records': 0,
      };
    }

    double totalWater = 0.0;
    double totalFlow = 0.0;
    double totalMoisture = 0.0;
    int pumpOnCount = 0;
    int pumpOffCount = 0;
    int flowCount = 0;
    int moistureCount = 0;

    for (var record in telemetryData) {
      // Total volume
      if (record['total_volume'] != null) {
        final volume = _parseDouble(record['total_volume']);
        if (volume > totalWater) totalWater = volume;
      }
      
      // Flow rate
      if (record['flow_rate_lmin'] != null) {
        totalFlow += _parseDouble(record['flow_rate_lmin']);
        flowCount++;
      }
      
      // Moisture
      if (record['moisture'] != null) {
        totalMoisture += _parseDouble(record['moisture']);
        moistureCount++;
      }
      
      // Pump state
      final pumpState = record['pump_state']?.toString().toUpperCase();
      if (pumpState == 'ON') {
        pumpOnCount++;
      } else if (pumpState == 'OFF') {
        pumpOffCount++;
      }
    }

    return {
      'total_water_used': totalWater,
      'avg_flow_rate': flowCount > 0 ? totalFlow / flowCount : 0.0,
      'avg_moisture': moistureCount > 0 ? totalMoisture / moistureCount : 0.0,
      'pump_on_time': pumpOnCount,
      'pump_off_time': pumpOffCount,
      'total_records': telemetryData.length,
    };
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

