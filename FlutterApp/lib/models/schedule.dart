/// Model for irrigation schedule
class IrrigationSchedule {
  final int id;
  final String day;
  final String time;
  final int duration; // in minutes

  IrrigationSchedule({
    required this.id,
    required this.day,
    required this.time,
    required this.duration,
  });

  /// Create from JSON (backend response)
  factory IrrigationSchedule.fromJson(Map<String, dynamic> json) {
    return IrrigationSchedule(
      id: json['id'] as int,
      day: json['day'] as String,
      time: json['time'] as String,
      duration: json['duration'] as int,
    );
  }

  /// Convert to JSON (for API requests)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'day': day,
      'time': time,
      'duration': duration,
    };
  }

  /// Get display name for day
  String get dayDisplay {
    return day[0].toUpperCase() + day.substring(1);
  }

  /// Get formatted time display
  String get timeDisplay {
    try {
      // Try to parse and format time
      if (time.contains('AM') || time.contains('PM')) {
        return time; // Already formatted
      } else {
        // Convert 24h to 12h format
        final parts = time.split(':');
        if (parts.length == 2) {
          int hour = int.parse(parts[0]);
          int minute = int.parse(parts[1]);
          final period = hour >= 12 ? 'PM' : 'AM';
          hour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
          return '$hour:${minute.toString().padLeft(2, '0')} $period';
        }
      }
    } catch (e) {
      // Return original if parsing fails
    }
    return time;
  }

  /// Get schedule description
  String get description {
    return '$dayDisplay at $timeDisplay for $duration min';
  }

  @override
  String toString() {
    return 'IrrigationSchedule(id: $id, day: $day, time: $time, duration: $duration)';
  }
}

/// Response model for schedule list API (Backend V5)
class ScheduleListResponse {
  final bool schedulingEnabled;
  final List<IrrigationSchedule> jobs;
  final int count;

  ScheduleListResponse({
    required this.schedulingEnabled,
    required this.jobs,
    required this.count,
  });

  factory ScheduleListResponse.fromJson(Map<String, dynamic> json) {
    final jobsList = json['jobs'] as List? ?? [];
    return ScheduleListResponse(
      schedulingEnabled: json['scheduling_enabled'] as bool? ?? false,
      jobs: jobsList.map((j) => IrrigationSchedule.fromJson(j as Map<String, dynamic>)).toList(),
      count: json['count'] as int? ?? 0,
    );
  }
}


