import 'package:flutter/foundation.dart';
import '../services/schedule_api_service.dart';
import '../models/schedule.dart';

/// Provider for managing irrigation schedules (Backend V5 feature)
class ScheduleProvider with ChangeNotifier {
  // Schedule state
  bool _schedulingEnabled = false;
  List<IrrigationSchedule> _schedules = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  bool get schedulingEnabled => _schedulingEnabled;
  List<IrrigationSchedule> get schedules => List.unmodifiable(_schedules);
  int get scheduleCount => _schedules.length;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  /// Load all schedules from backend
  Future<void> loadSchedules() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ScheduleApiService.getSchedules();
      
      _schedulingEnabled = response['scheduling_enabled'] as bool? ?? false;
      
      final jobsList = response['jobs'] as List? ?? [];
      _schedules = jobsList.map((j) => IrrigationSchedule.fromJson(j as Map<String, dynamic>)).toList();
      
      _isLoading = false;
      print('[SCHEDULE] Loaded ${_schedules.length} schedules, enabled: $_schedulingEnabled');
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      print('[SCHEDULE] Error loading schedules: $e');
      notifyListeners();
    }
  }

  /// Add a new schedule
  Future<String> addSchedule({
    required String day,
    required String time,
    required int duration,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ScheduleApiService.addSchedule(
        day: day,
        time: time,
        duration: duration,
      );
      
      _isLoading = false;
      
      // Reload schedules to get updated list
      await loadSchedules();
      
      return response['message'] ?? 'Schedule added successfully';
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return 'Error: ${e.toString()}';
    }
  }

  /// Remove a schedule
  Future<String> removeSchedule(int jobId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ScheduleApiService.removeSchedule(jobId);
      
      _isLoading = false;
      
      // Reload schedules to get updated list
      await loadSchedules();
      
      return response['message'] ?? 'Schedule removed successfully';
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return 'Error: ${e.toString()}';
    }
  }

  /// Toggle scheduling system
  Future<String> toggleScheduling(bool enable) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ScheduleApiService.toggleScheduling(enable);
      
      _schedulingEnabled = enable;
      _isLoading = false;
      notifyListeners();
      
      return response['message'] ?? 
          (enable ? 'Scheduling enabled' : 'Scheduling disabled');
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return 'Error: ${e.toString()}';
    }
  }

  /// Get schedule by ID
  IrrigationSchedule? getScheduleById(int id) {
    try {
      return _schedules.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get schedules for specific day
  List<IrrigationSchedule> getSchedulesForDay(String day) {
    return _schedules.where((s) => 
      s.day.toLowerCase() == day.toLowerCase() || 
      s.day.toLowerCase() == 'everyday'
    ).toList();
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

