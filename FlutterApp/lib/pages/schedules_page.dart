import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/schedule_provider.dart';
import '../widgets/connection_status.dart';

class SchedulesPage extends StatefulWidget {
  const SchedulesPage({super.key});

  @override
  State<SchedulesPage> createState() => _SchedulesPageState();
}

class _SchedulesPageState extends State<SchedulesPage> {
  String selectedFrequency = 'everyday';
  int selectedDuration = 10;
  DateTime? selectedDate;
  TimeOfDay selectedTime = const TimeOfDay(hour: 8, minute: 0);
  
  // Schedule form controllers
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  
  final List<String> _days = [
    'everyday', 'monday', 'tuesday', 'wednesday',
    'thursday', 'friday', 'saturday', 'sunday'
  ];

  @override
  void initState() {
    super.initState();
    _timeController.text = '08:00';
    _updateTimeDisplay();
    
    // Load schedules from backend
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ScheduleProvider>(context, listen: false);
      provider.loadSchedules();
      // Auto-enable scheduling if it's disabled
      _checkAndEnableScheduling();
    });
  }
  
  // Auto-enable scheduling if disabled
  Future<void> _checkAndEnableScheduling() async {
    final provider = Provider.of<ScheduleProvider>(context, listen: false);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!provider.schedulingEnabled && mounted) {
      // Silently enable scheduling
      await provider.toggleScheduling(true);
    }
  }
  
  void _updateTimeDisplay() {
    _timeController.text = '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
  }
  
  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: const TimePickerThemeData(
              backgroundColor: Colors.white,
              hourMinuteShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              dayPeriodBorderSide: BorderSide(color: Color(0xFF3B82F6)),
              dayPeriodColor: Color(0xFF3B82F6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              dayPeriodTextColor: Colors.white,
              dayPeriodShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              hourMinuteColor: Color(0xFFEFF6FF),
              hourMinuteTextColor: Color(0xFF3B82F6),
              dialHandColor: Color(0xFF3B82F6),
              dialBackgroundColor: Color(0xFFEFF6FF),
              hourMinuteTextStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              helpTextStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != selectedTime) {
      setState(() {
        selectedTime = picked;
        _updateTimeDisplay();
      });
    }
  }
  
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF3B82F6),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF3B82F6),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        _dateController.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  @override
  void dispose() {
    _timeController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              message.contains('Error') || message.contains('not reachable') 
                ? Icons.error : Icons.check_circle, 
              color: Colors.white, 
              size: 20
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        duration: const Duration(seconds: 3),
        backgroundColor: message.contains('Error') || message.contains('not reachable')
          ? Colors.red : Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _addSchedule() async {
    // Validation
    if (_timeController.text.isEmpty) {
      _showSnackBar('Please select a time');
      return;
    }
    
    if (selectedDuration < 1) {
      _showSnackBar('Duration must be at least 1 minute');
      return;
    }

    final provider = Provider.of<ScheduleProvider>(context, listen: false);
    
    // Ensure scheduling is enabled before adding
    if (!provider.schedulingEnabled) {
      _showSnackBar('Enabling scheduling...');
      try {
        await provider.toggleScheduling(true);
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        _showSnackBar('Failed to enable scheduling: ${e.toString()}');
        return;
      }
    }
    
    // Format time consistently as HH:MM in 24-hour format
    final timeString = _timeController.text.trim();
    
    // Validate time format
    if (!RegExp(r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$').hasMatch(timeString)) {
      _showSnackBar('Invalid time format. Please use HH:MM (e.g., 08:00 or 14:30)');
      return;
    }
    
    print('Adding schedule: day=$selectedFrequency, time=$timeString, duration=$selectedDuration');
    
    try {
      final message = await provider.addSchedule(
        day: selectedFrequency,
        time: timeString,
        duration: selectedDuration,
      );
      
      _showSnackBar(message);
      
      // Reset form only if successful
      if (!message.contains('Error')) {
        setState(() {
          selectedFrequency = 'everyday';
          selectedDuration = 10;
          selectedTime = const TimeOfDay(hour: 8, minute: 0);
          selectedDate = null;
          _updateTimeDisplay();
          _dateController.clear();
        });
      }
    } catch (e) {
      _showSnackBar('Error adding schedule: ${e.toString()}');
      print('Exception adding schedule: $e');
    }
  }
  
  void _removeSchedule(int jobId) async {
    final provider = Provider.of<ScheduleProvider>(context, listen: false);
    final message = await provider.removeSchedule(jobId);
    _showSnackBar(message);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with Backend Status & Schedule Toggle
        // Responsive layout for mobile vs desktop
        if (isMobile) ...[
          // Mobile Layout: Stack vertically
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                'Irrigation Schedules',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                ),
                overflow: TextOverflow.visible,
                softWrap: false,
              ),
              const SizedBox(height: 8),
              // Status
              Consumer<ScheduleProvider>(
                builder: (context, provider, child) {
                  return Text(
                    provider.schedulingEnabled 
                      ? 'Scheduling active • ${provider.scheduleCount} schedules'
                      : 'Scheduling disabled',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              // Controls row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Scheduling Toggle
                  Consumer<ScheduleProvider>(
                    builder: (context, provider, child) {
                      return Row(
                        children: [
                          Text(
                            'Enable',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            value: provider.schedulingEnabled,
                            onChanged: (value) async {
                              final message = await provider.toggleScheduling(value);
                              _showSnackBar(message);
                            },
                          ),
                        ],
                      );
                    },
                  ),
                  // Connection Status
                  const ConnectionStatusWidget(),
                ],
              ),
            ],
          ),
        ] else ...[
          // Desktop Layout: Horizontal
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Irrigation Schedules',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Consumer<ScheduleProvider>(
                      builder: (context, provider, child) {
                        return Text(
                          provider.schedulingEnabled 
                            ? 'Scheduling active • ${provider.scheduleCount} schedules'
                            : 'Scheduling disabled',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.black54,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  // Scheduling Toggle
                  Consumer<ScheduleProvider>(
                    builder: (context, provider, child) {
                      return Row(
                        children: [
                          Text(
                            'Enable Scheduling',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            value: provider.schedulingEnabled,
                            onChanged: (value) async {
                              final message = await provider.toggleScheduling(value);
                              _showSnackBar(message);
                            },
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  // Backend Connection Status
                  const ConnectionStatusWidget(),
                ],
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),

        // Schedule Form Card - ADD NEW SCHEDULE
        _buildScheduleFormCard(theme),
        const SizedBox(height: 24),
        
        // Active Schedules List - FROM BACKEND
        _buildActiveSchedulesList(theme),
      ],
    );
  }


  // Build Schedule Form Card - REAL BACKEND INTEGRATION
  Widget _buildScheduleFormCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Consumer<ScheduleProvider>(
          builder: (context, provider, child) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.add_alarm,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Add New Schedule',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Day Selection
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Frequency (Day)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedFrequency,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.calendar_today, size: 20, color: Color(0xFF3B82F6)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      items: _days.map((day) {
                        return DropdownMenuItem(
                          value: day,
                          child: Text(
                            day == 'everyday' ? 'Every Day' : day[0].toUpperCase() + day.substring(1),
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedFrequency = value!;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Optional Date Input (for one-time schedules)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date (Optional - leave empty for recurring)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _selectDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 20, color: Color(0xFF3B82F6)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                selectedDate != null
                                    ? '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}'
                                    : 'Select date (or leave empty for recurring)',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: selectedDate != null ? Colors.black87 : Colors.grey[600],
                                ),
                              ),
                            ),
                            if (selectedDate != null)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  setState(() {
                                    selectedDate = null;
                                    _dateController.clear();
                                  });
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Time Input with Picker
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start Time',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _selectTime,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, size: 20, color: Color(0xFF3B82F6)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _timeController.text.isNotEmpty
                                    ? _timeController.text
                                    : 'Select time',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Duration Slider
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Duration: $selectedDuration minutes',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: selectedDuration.toDouble(),
                      min: 5,
                      max: 60,
                      divisions: 11,
                      label: '$selectedDuration min',
                      onChanged: (value) {
                        setState(() {
                          selectedDuration = value.round();
                        });
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('5 min', style: theme.textTheme.bodySmall),
                        Text('60 min', style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Add Schedule Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: provider.isLoading ? null : _addSchedule,
                    icon: provider.isLoading 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.add, size: 18),
                    label: Text(provider.isLoading ? 'Adding...' : 'Add Schedule'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  
  // Build Active Schedules List - REAL BACKEND DATA
  Widget _buildActiveSchedulesList(ThemeData theme) {
    return Consumer<ScheduleProvider>(
      builder: (context, provider, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.schedule,
                        color: Color(0xFF10B981),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Active Schedules',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    if (provider.isLoading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () => provider.loadSchedules(),
                        tooltip: 'Refresh schedules',
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Schedules List
                if (provider.schedules.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.event_busy,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No schedules added yet',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add your first schedule above',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...provider.schedules.map((schedule) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF10B981).withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Schedule Icon
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.access_alarm,
                              color: Color(0xFF10B981),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          
                          // Schedule Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  schedule.dayDisplay,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${schedule.timeDisplay} • ${schedule.duration} min',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          // Delete Button
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _confirmRemoveSchedule(schedule),
                            tooltip: 'Remove schedule',
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }
  
  // Confirm schedule removal
  void _confirmRemoveSchedule(schedule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Schedule'),
        content: Text('Remove schedule for ${schedule.dayDisplay} at ${schedule.timeDisplay}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _removeSchedule(schedule.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

