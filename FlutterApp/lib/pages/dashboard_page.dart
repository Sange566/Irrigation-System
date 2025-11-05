import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../widgets/circular_progress.dart';
import '../providers/irrigation_provider.dart';
import '../providers/schedule_provider.dart';
import '../widgets/real_time_chart.dart';
import '../widgets/connection_status.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool isPumpActive = false;
  double flowRate = 0.0;  // Start at 0, update from backend
  double totalUsage = 0.0;  // Start at 0, update from backend
  final double dailyGoal = 150; // Daily water usage goal in liters
  Timer? _statusTimer;  // Removed _timer for simulation
  bool isBackendConnected = false;
  String? scheduleStatus;
  String? startTime;
  String? endTime;

  @override
  void initState() {
    super.initState();
    // Removed _startSimulation() - no more dummy data!
    _startStatusPolling();
    
    // Listen to irrigation provider for real-time updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<IrrigationProvider>(context, listen: false);
      provider.addListener(_onProviderUpdate);
      // Initial load
      _onProviderUpdate();
      
      // Load schedule data
      final scheduleProvider = Provider.of<ScheduleProvider>(context, listen: false);
      scheduleProvider.loadSchedules();
    });
  }
  
  void _onProviderUpdate() {
    final provider = Provider.of<IrrigationProvider>(context, listen: false);
    if (mounted) {
      setState(() {
        // Get ALL data from backend provider - NO dummy data
        isPumpActive = provider.pumpStatus;
        isBackendConnected = provider.isBackendConnected;
        flowRate = provider.flowRate;
        totalUsage = provider.todayUsage; // Changed to use daily usage instead of total
        // Update connection status
      });
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    final provider = Provider.of<IrrigationProvider>(context, listen: false);
    provider.removeListener(_onProviderUpdate);
    super.dispose();
  }

  // Removed _startSimulation() - all data now comes from backend!

  void _togglePump() async {
    final provider = Provider.of<IrrigationProvider>(context, listen: false);
    
    if (!provider.isBackendConnected) {
      _showSnackBar('Backend not reachable');
      return;
    }

    try {
      String message;
      if (isPumpActive) {
        message = await provider.turnPumpOff();
      } else {
        message = await provider.turnPumpOn();
      }
      
      _showSnackBar(message);
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
    }
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

  // Start status polling every 5 seconds for connection check
  void _startStatusPolling() {
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      final provider = Provider.of<IrrigationProvider>(context, listen: false);
      provider.checkBackendConnection();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const successColor = Color(0xFF10B981);
    final primaryBlue = theme.colorScheme.primary;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with Backend Status
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Irrigation Dashboard',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Monitor and control your smart irrigation system',
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            // Backend Connection Status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isBackendConnected 
                  ? const Color(0xFF10B981).withOpacity(0.1)
                  : const Color(0xFFEF4444).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isBackendConnected 
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isBackendConnected 
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isBackendConnected ? 'Connected' : 'Offline',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isBackendConnected 
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Pump Control Card (Redesigned with Green Background when Active)
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isPumpActive ? successColor.withOpacity(0.15) : null,
              border: isPumpActive ? Border.all(color: successColor.withOpacity(0.3), width: 2) : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Use MediaQuery for better mobile detection
                  final isMobile = MediaQuery.of(context).size.width < 600;
                  
                  if (isMobile) {
                    // Mobile: Stack layout to prevent overflow
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon and Title Row
                        Row(
                          children: [
                            Icon(
                              Icons.power_settings_new,
                              size: 24,
                              color: isPumpActive 
                                ? successColor 
                                : (isDark ? const Color(0xFF64748B) : const Color(0xFF475569)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Pump Control',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            // Active/Inactive Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isPumpActive 
                                  ? successColor 
                                  : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isPumpActive ? 'Active' : 'Inactive',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Description
                        Text(
                          'Monitor and control irrigation pump',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Button - Full width on mobile
                        SizedBox(
                          width: double.infinity,
                          child: isPumpActive
                            ? ElevatedButton.icon(
                                onPressed: isBackendConnected ? () => _confirmPumpToggle() : null,
                                icon: const Icon(Icons.stop, size: 16),
                                label: const Text('Stop Pump'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEF4444),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              )
                            : ElevatedButton.icon(
                                onPressed: isBackendConnected ? () => _confirmPumpToggle() : null,
                                icon: const Icon(Icons.play_arrow, size: 16),
                                label: const Text('Start Pump'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: successColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                        ),
                      ],
                    );
                  } else {
                    // Desktop/Tablet: Horizontal layout
                    return Row(
                      children: [
                        Icon(
                          Icons.power_settings_new,
                          size: 28,
                          color: isPumpActive 
                            ? successColor 
                            : (isDark ? const Color(0xFF64748B) : const Color(0xFF475569)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 12,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    'Pump Control',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 20,
                                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isPumpActive 
                                        ? successColor 
                                        : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          isPumpActive ? 'Active' : 'Inactive',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Monitor and control irrigation pump',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (isPumpActive)
                          ElevatedButton.icon(
                            onPressed: isBackendConnected ? () => _confirmPumpToggle() : null,
                            icon: const Icon(Icons.stop, size: 18),
                            label: const Text('Stop Pump'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: isBackendConnected ? () => _confirmPumpToggle() : null,
                            icon: const Icon(Icons.play_arrow, size: 18),
                            label: const Text('Start Pump'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: successColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                      ],
                    );
                  }
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Daily Water Usage Card with Icon Badge - Auto-Updating!
        Consumer<IrrigationProvider>(
          builder: (context, usageProvider, child) {
            final currentUsage = usageProvider.todayUsage;
            final remaining = (dailyGoal - currentUsage).clamp(0, dailyGoal);
            
            return Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.water_drop,
                                color: primaryBlue,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Daily Water Usage',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 20),
                          color: primaryBlue,
                          onPressed: () => _refreshData(),
                          tooltip: 'Refresh data',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: CircularProgress(
                        value: currentUsage,
                        max: dailyGoal,
                        size: 240,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Daily stats comparison
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildStatChip(
                          'Yesterday',
                          '${usageProvider.yesterdayUsage.toStringAsFixed(1)} L',
                          Icons.history,
                          Colors.grey.shade600,
                        ),
                        const SizedBox(width: 12),
                        _buildStatChip(
                          'Change',
                          '${usageProvider.changePercent >= 0 ? '+' : ''}${usageProvider.changePercent.toStringAsFixed(1)}%',
                          usageProvider.changePercent >= 0 ? Icons.trending_up : Icons.trending_down,
                          usageProvider.changePercent >= 0 ? Colors.orange : Colors.green,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: primaryBlue,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Target: ${dailyGoal.toInt()}L/day • Remaining: ${remaining.toStringAsFixed(1)}L',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: primaryBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),

        // Real-time Metrics - 2x2 Grid Layout (All Platforms) - Auto-Updating!
        Consumer<IrrigationProvider>(
          builder: (context, provider, child) {
            // Use provider data directly for real-time updates
            final currentFlowRate = provider.flowRate;
            final currentTotalUsage = provider.todayUsage;
            final currentMoisture = provider.soilMoisture;
            final currentChangePercent = provider.changePercent;
            
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildMetricCard('Flow Rate', currentFlowRate.toStringAsFixed(1), 'L/min', 'Normal vs yesterday', Icons.speed, const Color(0xFF3B82F6), isDark, context)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildMetricCard('Total Water Used', currentTotalUsage.toStringAsFixed(1), 'liters', '${currentChangePercent >= 0 ? '+' : ''}${currentChangePercent.toStringAsFixed(1)}% vs yesterday', Icons.water, const Color(0xFF3B82F6), isDark, context)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildMetricCard('Soil Moisture', currentMoisture.toStringAsFixed(0), '%', '${currentMoisture >= 50 ? 'Optimal' : 'Low'} level', Icons.water_drop, const Color(0xFF10B981), isDark, context)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildMetricCard('Peak Flow', provider.peakFlowRate.toStringAsFixed(1), 'L/min', 'Today\'s maximum', Icons.waves, const Color(0xFF3B82F6), isDark, context)),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),

        // Quick Actions Section (Horizontal Layout)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Common tasks and system controls',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 768) {
                  // Desktop/Tablet: Horizontal layout
                  return Row(
                    children: [
                      Expanded(
                        child: _buildQuickActionCard(
                          'Start Irrigation',
                          'Quick timed watering',
                          Icons.play_circle_outline,
                          const Color(0xFF3B82F6),
                          () => _showIrrigationOptions(context),
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildQuickActionCard(
                          'View Schedule',
                          'Manage irrigation timings',
                          Icons.calendar_today_outlined,
                          const Color(0xFF0EA5E9),
                          () => _showScheduleInfo(context),
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildQuickActionCard(
                          'System Health',
                          'Check sensor status',
                          Icons.show_chart,
                          const Color(0xFF10B981),
                          () => _showSystemHealth(context),
                          isDark,
                        ),
                      ),
                    ],
                  );
                } else {
                  // Mobile: Vertical layout
                  return Column(
                    children: [
                      _buildQuickActionCard(
                        'Start Irrigation',
                        'Quick timed watering',
                        Icons.play_circle_outline,
                        const Color(0xFF3B82F6),
                        () => _showIrrigationOptions(context),
                        isDark,
                      ),
                      const SizedBox(height: 12),
                      _buildQuickActionCard(
                        'View Schedule',
                        'Manage irrigation timings',
                        Icons.calendar_today_outlined,
                        const Color(0xFF0EA5E9),
                        () => _showScheduleInfo(context),
                        isDark,
                      ),
                      const SizedBox(height: 12),
                      _buildQuickActionCard(
                        'System Health',
                        'Check sensor status',
                        Icons.show_chart,
                        const Color(0xFF10B981),
                        () => _showSystemHealth(context),
                        isDark,
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Today's Schedule Preview with Better Styling
        Consumer<ScheduleProvider>(
          builder: (context, scheduleProvider, child) {
            // Get today's schedules (everyday + current day)
            final now = DateTime.now();
            final today = ['everyday', _getDayName(now.weekday)];
            final todaysSchedules = scheduleProvider.schedules
                .where((s) => today.contains(s.day.toLowerCase()))
                .toList();
            todaysSchedules.sort((a, b) => a.time.compareTo(b.time));
            
            return Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.schedule,
                                color: Color(0xFFF59E0B),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Today\'s Schedule',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: (scheduleProvider.schedulingEnabled 
                                ? const Color(0xFF10B981) 
                                : const Color(0xFF6B7280)).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            scheduleProvider.schedulingEnabled ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: scheduleProvider.schedulingEnabled 
                                  ? const Color(0xFF10B981) 
                                  : const Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // Show today's schedules
                    if (todaysSchedules.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334155) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No schedules for today. Tap Quick Actions to create one.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...todaysSchedules.take(3).map((schedule) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF334155) : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF3B82F6).withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${schedule.day.toUpperCase()} @ ${schedule.time}',
                                      style: theme.textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF3B82F6),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Duration: ${schedule.duration} minutes',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.access_time,
                                color: const Color(0xFF3B82F6),
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      )),
                    
                    if (todaysSchedules.length > 3)
                      TextButton(
                        onPressed: () => _navigateToSchedules(context),
                        child: Text('View all ${todaysSchedules.length} schedules'),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark 
                ? const Color(0xFF0EA5E9).withOpacity(0.15)
                : const Color(0xFF0EA5E9).withOpacity(0.05),
            border: Border.all(
              color: const Color(0xFF0EA5E9).withOpacity(isDark ? 0.3 : 0.2),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'System Status',
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isBackendConnected 
                        ? 'Backend connected • Live WebSocket data'
                        : 'Backend offline • Waiting for connection',
                      style: theme.textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isBackendConnected 
                    ? const Color(0xFF0EA5E9).withOpacity(0.2)
                    : const Color(0xFF6B7280).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isBackendConnected ? 'Live' : 'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    color: isBackendConnected ? const Color(0xFF0EA5E9) : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper method to confirm pump toggle with dialog
  void _confirmPumpToggle() {
    const errorRed = Color(0xFFEF4444);
    const successColor = Color(0xFF10B981);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isPumpActive ? Icons.pause_circle : Icons.play_circle,
              color: isPumpActive ? errorRed : successColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isPumpActive ? 'Pause Irrigation System?' : 'Start Irrigation System?',
                style: const TextStyle(fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(
          isPumpActive
              ? 'This will temporarily stop all irrigation activities. You can resume anytime from the dashboard.'
              : 'This will start the irrigation system. Water will flow according to the current settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _togglePump();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isPumpActive ? errorRed : successColor,
            ),
            child: Text(isPumpActive ? 'Pause System' : 'Start System'),
          ),
        ],
      ),
    );
  }

  // Refresh data method
  Future<void> _refreshData() async {
    _showSnackBar('Refreshing water usage data...');
    final provider = Provider.of<IrrigationProvider>(context, listen: false);
    await provider.refreshAll();
    await provider.loadDailyStats();
    if (mounted) {
      final currentUsage = provider.todayUsage;
      _showSnackBar('Water usage data updated: ${currentUsage.toStringAsFixed(1)}L / ${dailyGoal.toInt()}L');
    }
  }

  // Build modern metric card matching image design - Responsive
  Widget _buildMetricCard(String title, String value, String unit, String comparison, IconData icon, Color iconColor, bool isDark, BuildContext context) {
    // Determine comparison color
    Color comparisonColor = const Color(0xFF64748B); // Default gray
    if (comparison.contains('+')) {
      comparisonColor = const Color(0xFF10B981); // Green for positive
    } else if (comparison.contains('-') && !comparison.contains('yesterday')) {
      comparisonColor = const Color(0xFFEF4444); // Red for negative
    }
    
    // Determine if card is clickable
    final isClickable = title == 'Flow Rate' || title == 'Total Water Used';
    
    // Responsive sizing based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    // Adjust padding, font sizes for mobile
    final cardPadding = isMobile ? 12.0 : 20.0;
    final titleFontSize = isMobile ? 12.0 : 14.0;
    final valueFontSize = isMobile ? 24.0 : 32.0;
    final unitFontSize = isMobile ? 13.0 : 16.0;
    final comparisonFontSize = isMobile ? 11.0 : 13.0;
    final iconSize = isMobile ? 18.0 : 22.0;
    final iconPadding = isMobile ? 8.0 : 10.0;
    final spacing = isMobile ? 10.0 : 16.0;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: isClickable ? () {
          if (title == 'Flow Rate') {
            _showFlowRateDetails(context, Theme.of(context), const Color(0xFF3B82F6), const Color(0xFF10B981));
          } else if (title == 'Total Water Used') {
            _showWaterUsageHistory(context, Theme.of(context), const Color(0xFF3B82F6), const Color(0xFF10B981));
          }
        } : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and Icon Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: EdgeInsets.all(iconPadding),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: iconColor,
                      size: iconSize,
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacing),
              // Value
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: valueFontSize,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    unit,
                    style: TextStyle(
                      fontSize: unitFontSize,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              SizedBox(height: isMobile ? 8 : 12),
              // Comparison
              Text(
                comparison,
                style: TextStyle(
                  fontSize: comparisonFontSize,
                  fontWeight: FontWeight.w500,
                  color: comparisonColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build Quick Action Card matching image design
  Widget _buildQuickActionCard(String title, String subtitle, IconData icon, Color iconColor, VoidCallback onTap, bool isDark) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Icon on left
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Show Flow Rate Details Dialog
  void _showFlowRateDetails(BuildContext context, ThemeData theme, Color primaryBlue, Color successColor) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Consumer<IrrigationProvider>(
                builder: (context, provider, child) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primaryBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.speed, color: primaryBlue),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Real-Time Flow Rate',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const ConnectionIndicator(),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const RealTimeStatsCard(),
                      const SizedBox(height: 24),
                      const Text(
                        'Last Hour - Live Data from ESP32',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const SizedBox(
                        height: 250,
                        child: RealTimeFlowChart(
                          timeRange: Duration(hours: 1),
                          height: 250,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Show Water Usage History Dialog - REAL-TIME DATA
  void _showWaterUsageHistory(BuildContext context, ThemeData theme, Color primaryBlue, Color successColor) {
    const accentGreen = Color(0xFF059669);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Consumer<IrrigationProvider>(
                builder: (context, provider, child) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: accentGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.water, color: accentGreen),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Water Usage - Real-Time',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const ConnectionIndicator(),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _StatTile(
                              label: 'Current Total',
                              value: provider.totalWaterUsed.toStringAsFixed(1),
                              unit: 'L',
                              color: accentGreen,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _StatTile(
                              label: 'Data Points',
                              value: provider.liveDataHistory.length.toString(),
                              unit: 'pts',
                              color: primaryBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Last 24 Hours - Live Oracle DB Data',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const SizedBox(
                        height: 250,
                        child: RealTimeWaterUsageChart(
                          timeRange: Duration(hours: 24),
                          height: 250,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Show Irrigation Options - With Duration Selection!
  void _showIrrigationOptions(BuildContext context) {
    final provider = Provider.of<IrrigationProvider>(context, listen: false);
    final scheduleProvider = Provider.of<ScheduleProvider>(context, listen: false);
    
    if (!provider.isBackendConnected) {
      _showSnackBar('Backend not connected. Please check connection.');
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.play_circle_outline, color: Color(0xFF3B82F6)),
            SizedBox(width: 12),
            Expanded(child: Text('Start Quick Irrigation')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select irrigation duration',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.timer, color: Color(0xFF3B82F6)),
              ),
              title: Text('10 Minutes'),
              subtitle: Text('Quick watering session'),
              onTap: () async {
                Navigator.pop(context);
                await _startTimedIrrigation(10, scheduleProvider);
              },
            ),
            Divider(),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.timer, color: Color(0xFF10B981)),
              ),
              title: Text('15 Minutes'),
              subtitle: Text('Standard irrigation'),
              onTap: () async {
                Navigator.pop(context);
                await _startTimedIrrigation(15, scheduleProvider);
              },
            ),
            Divider(),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFFF59E0B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.timer, color: Color(0xFFF59E0B)),
              ),
              title: Text('30 Minutes'),
              subtitle: Text('Extended watering'),
              onTap: () async {
                Navigator.pop(context);
                await _startTimedIrrigation(30, scheduleProvider);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  // Start timed irrigation (creates a one-time schedule)
  Future<void> _startTimedIrrigation(int duration, ScheduleProvider scheduleProvider) async {
    final provider = Provider.of<IrrigationProvider>(context, listen: false);
    
    try {
      // Turn pump ON immediately
      await provider.turnPumpOn();
      _showSnackBar('Irrigation started for $duration minutes');
      
      // Schedule auto-off after duration using a Timer
      Future.delayed(Duration(minutes: duration), () async {
        await provider.turnPumpOff();
        if (mounted) {
          _showSnackBar('Irrigation completed ($duration minutes)');
        }
      });
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
    }
  }

  // Show Schedule Info - Shows Popup with Actual Schedules!
  void _showScheduleInfo(BuildContext context) {
    final scheduleProvider = Provider.of<ScheduleProvider>(context, listen: false);
    final now = DateTime.now();
    final today = ['everyday', _getDayName(now.weekday)];
    final todaysSchedules = scheduleProvider.schedules
        .where((s) => today.contains(s.day.toLowerCase()))
        .toList();
    todaysSchedules.sort((a, b) => a.time.compareTo(b.time));
    
    // Capture parent context before showing dialog
    final parentContext = context;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.calendar_today, color: Color(0xFF0EA5E9)),
            SizedBox(width: 12),
            Expanded(child: Text('Today\'s Irrigation Schedule')),
          ],
        ),
        content: todaysSchedules.isEmpty
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
                SizedBox(height: 16),
                Text(
                  'No schedules for today',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  'Create a schedule to automate your irrigation',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _navigateToSchedules(parentContext);
                  },
                  icon: Icon(Icons.add),
                  label: Text('Create Schedule'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scheduled for today:',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                SizedBox(height: 16),
                ...todaysSchedules.map((schedule) => Container(
                  margin: EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Color(0xFF3B82F6).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, color: Color(0xFF3B82F6), size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              schedule.time,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: Color(0xFF3B82F6),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '${schedule.duration} minutes • ${schedule.day}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
                SizedBox(height: 8),
                Text(
                  'Scheduling: ${scheduleProvider.schedulingEnabled ? "Enabled ✓" : "Disabled"}',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheduleProvider.schedulingEnabled ? Color(0xFF10B981) : Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          if (todaysSchedules.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _navigateToSchedules(parentContext);
              },
              child: Text('Manage Schedules'),
            ),
        ],
      ),
    );
  }
  
  // Navigate to Schedules Page
  void _navigateToSchedules(BuildContext context) {
    // Navigate to schedules route using GoRouter
    context.go('/schedules');
  }
  
  // Helper to get day name from weekday number
  String _getDayName(int weekday) {
    const days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    return days[weekday - 1];
  }

  // Show System Health
  void _showSystemHealth(BuildContext context) {
    final provider = Provider.of<IrrigationProvider>(context, listen: false);
    const successColor = Color(0xFF10B981);
    const warningColor = Color(0xFFF59E0B);
    const errorColor = Color(0xFFEF4444);
    
    // Determine system health status
    final backendStatus = provider.isBackendConnected;
    final websocketStatus = provider.isWebSocketConnected;
    final hasSensorData = provider.lastMoistureUpdate != null;
    final hasPumpData = provider.lastPumpUpdate != null;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.health_and_safety, color: Color(0xFF10B981)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'System Health Check',
                style: TextStyle(fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(
              'Backend Connection:', 
              backendStatus ? 'Connected' : 'Disconnected',
              color: backendStatus ? successColor : errorColor,
            ),
            _buildDetailRow(
              'WebSocket Stream:', 
              websocketStatus ? 'Live' : 'Offline',
              color: websocketStatus ? successColor : errorColor,
            ),
            _buildDetailRow(
              'Moisture Sensor:', 
              hasSensorData ? 'Active (${provider.soilMoisture.toStringAsFixed(1)}%)' : 'No Data',
              color: hasSensorData ? successColor : warningColor,
            ),
            _buildDetailRow(
              'Flow Sensor:', 
              hasPumpData ? 'Active (${provider.flowRate.toStringAsFixed(1)} L/min)' : 'No Data',
              color: hasPumpData ? successColor : warningColor,
            ),
            _buildDetailRow(
              'Pump Status:', 
              isPumpActive ? 'Running' : 'Stopped', 
              color: isPumpActive ? successColor : Colors.grey[600],
            ),
            _buildDetailRow(
              'Data Points Collected:', 
              '${provider.flowRateHistory.length}',
              color: provider.flowRateHistory.length > 0 ? successColor : warningColor,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (backendStatus && websocketStatus) 
                    ? successColor.withOpacity(0.1)
                    : errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    (backendStatus && websocketStatus) ? Icons.check_circle : Icons.warning,
                    color: (backendStatus && websocketStatus) ? successColor : errorColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (backendStatus && websocketStatus)
                          ? 'All systems operational'
                          : 'System issues detected',
                      style: TextStyle(
                        color: (backendStatus && websocketStatus) ? successColor : errorColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Build detail row for dialogs
  Widget _buildDetailRow(String label, String value, {Color? color}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium,
          ),
          Text(
            value,
            style: TextStyle(
              color: color ?? (isDark ? Colors.white : Colors.black87),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Build stat chip helper for daily statistics
  Widget _buildStatChip(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Widget for stat tiles in dialogs
class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 14,
                    color: color.withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}



