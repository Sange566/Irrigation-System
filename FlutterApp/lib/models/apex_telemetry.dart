/// Model for APEX Telemetry Data
class ApexTelemetry {
  final int? id;
  final String? deviceUid;
  final DateTime? timestamp;
  final String? pumpState;
  final double? flowRateLmin;
  final double? totalVolume;
  final double? moisture;
  final double? temperature;
  final double? humidity;

  ApexTelemetry({
    this.id,
    this.deviceUid,
    this.timestamp,
    this.pumpState,
    this.flowRateLmin,
    this.totalVolume,
    this.moisture,
    this.temperature,
    this.humidity,
  });

  factory ApexTelemetry.fromJson(Map<String, dynamic> json) {
    return ApexTelemetry(
      id: json['id'] as int?,
      deviceUid: json['device_uid'] as String?,
      timestamp: json['timestamp'] != null 
          ? DateTime.tryParse(json['timestamp'].toString())
          : null,
      pumpState: json['pump_state'] as String?,
      flowRateLmin: _parseDouble(json['flow_rate_lmin']),
      totalVolume: _parseDouble(json['total_volume']),
      moisture: _parseDouble(json['moisture']),
      temperature: _parseDouble(json['temperature']),
      humidity: _parseDouble(json['humidity']),
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  bool get isPumpOn => pumpState?.toUpperCase() == 'ON';
  
  @override
  String toString() {
    return 'ApexTelemetry(device: $deviceUid, timestamp: $timestamp, pump: $pumpState)';
  }
}

/// Model for APEX Device
class ApexDevice {
  final int? id;
  final String? deviceUid;
  final String? deviceName;
  final String? deviceType;
  final String? location;
  final String? status;
  final DateTime? createdAt;

  ApexDevice({
    this.id,
    this.deviceUid,
    this.deviceName,
    this.deviceType,
    this.location,
    this.status,
    this.createdAt,
  });

  factory ApexDevice.fromJson(Map<String, dynamic> json) {
    return ApexDevice(
      id: json['id'] as int?,
      deviceUid: json['device_uid'] as String?,
      deviceName: json['device_name'] as String?,
      deviceType: json['device_type'] as String?,
      location: json['location'] as String?,
      status: json['status'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  bool get isActive => status?.toLowerCase() == 'active';

  @override
  String toString() {
    return 'ApexDevice(uid: $deviceUid, name: $deviceName, type: $deviceType)';
  }
}

/// Analytics Summary Model
class AnalyticsSummary {
  final double totalWaterUsed;
  final double avgFlowRate;
  final double avgMoisture;
  final int pumpOnTime;
  final int pumpOffTime;
  final int totalRecords;
  final int activeDevices;
  final int totalAlerts;

  AnalyticsSummary({
    required this.totalWaterUsed,
    required this.avgFlowRate,
    required this.avgMoisture,
    required this.pumpOnTime,
    required this.pumpOffTime,
    required this.totalRecords,
    this.activeDevices = 0,
    this.totalAlerts = 0,
  });

  double get pumpOnPercentage {
    final total = pumpOnTime + pumpOffTime;
    if (total == 0) return 0.0;
    return (pumpOnTime / total) * 100;
  }

  double get pumpOffPercentage => 100 - pumpOnPercentage;

  factory AnalyticsSummary.fromAnalytics(Map<String, dynamic> analytics) {
    return AnalyticsSummary(
      totalWaterUsed: (analytics['total_water_used'] as num?)?.toDouble() ?? 0.0,
      avgFlowRate: (analytics['avg_flow_rate'] as num?)?.toDouble() ?? 0.0,
      avgMoisture: (analytics['avg_moisture'] as num?)?.toDouble() ?? 0.0,
      pumpOnTime: analytics['pump_on_time'] as int? ?? 0,
      pumpOffTime: analytics['pump_off_time'] as int? ?? 0,
      totalRecords: analytics['total_records'] as int? ?? 0,
      activeDevices: analytics['active_devices'] as int? ?? 0,
      totalAlerts: analytics['total_alerts'] as int? ?? 0,
    );
  }
}

