/// Model for live data points from WebSocket
class LiveDataPoint {
  final DateTime timestamp;
  final String pumpState;
  final double flowRate;
  final double waterUsedCycle;
  final double totalVolume;

  LiveDataPoint({
    required this.timestamp,
    required this.pumpState,
    required this.flowRate,
    required this.waterUsedCycle,
    required this.totalVolume,
  });

  /// Create from WebSocket JSON data
  factory LiveDataPoint.fromJson(Map<String, dynamic> json) {
    return LiveDataPoint(
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      // Handle both pump_state and pump_status from backend
      pumpState: (json['pump_state'] ?? json['pump_status'])?.toString() ?? 'OFF',
      // Handle both flow_rate_Lmin and flow_rate from backend
      flowRate: (json['flow_rate_Lmin'] as num?)?.toDouble() ?? 
                (json['flow_rate'] as num?)?.toDouble() ?? 0.0,
      waterUsedCycle: (json['water_used_cycle'] as num?)?.toDouble() ?? 0.0,
      // Handle both total_volume and total_flow from backend
      totalVolume: (json['total_volume'] as num?)?.toDouble() ?? 
                   (json['total_flow'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'pump_state': pumpState,
      'flow_rate_Lmin': flowRate,
      'water_used_cycle': waterUsedCycle,
      'total_volume': totalVolume,
    };
  }

  @override
  String toString() {
    return 'LiveDataPoint(time: $timestamp, pump: $pumpState, flow: $flowRate, total: $totalVolume)';
  }
}

/// Model for chart data points
class ChartDataPoint {
  final DateTime timestamp;
  final double value;

  ChartDataPoint({
    required this.timestamp,
    required this.value,
  });

  /// Get timestamp in milliseconds (for charts)
  int get milliseconds => timestamp.millisecondsSinceEpoch;

  @override
  String toString() {
    return 'ChartDataPoint(time: $timestamp, value: $value)';
  }
}

