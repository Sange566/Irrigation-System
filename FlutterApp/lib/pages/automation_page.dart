import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/irrigation_provider.dart';

class AutomationPage extends StatefulWidget {
  const AutomationPage({super.key});

  @override
  State<AutomationPage> createState() => _AutomationPageState();
}

class _AutomationPageState extends State<AutomationPage> {
  bool automationEnabled = true;
  double minMoistureThreshold = 25.0;
  double maxMoistureThreshold = 60.0;
  double currentMoisture = 45.0;
  int minDuration = 5;
  int maxDuration = 30;
  List<Map<String, dynamic>> recentActions = [];
  bool loadingHistory = false;

  @override
  void initState() {
    super.initState();
    // Load initial data from provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<IrrigationProvider>(context, listen: false);
      
      // Load from provider immediately
      setState(() {
        automationEnabled = provider.automationEnabled;
        minMoistureThreshold = provider.minMoistureThreshold;
        maxMoistureThreshold = provider.maxMoistureThreshold;
        currentMoisture = provider.soilMoisture;
      });
      
      // Reload automation status to get latest moisture data
      provider.loadAutomationStatus();
      
      // Load recent action history
      _loadActionHistory();
      
      // Listen for updates
      provider.addListener(_onProviderUpdate);
    });
  }
  
  void _onProviderUpdate() {
    final provider = Provider.of<IrrigationProvider>(context, listen: false);
    if (mounted) {
      setState(() {
        currentMoisture = provider.soilMoisture;
        automationEnabled = provider.automationEnabled;
        minMoistureThreshold = provider.minMoistureThreshold;
        maxMoistureThreshold = provider.maxMoistureThreshold;
      });
    }
  }

  Future<void> _loadActionHistory() async {
    setState(() {
      loadingHistory = true;
    });

    try {
      final provider = Provider.of<IrrigationProvider>(context, listen: false);
      final history = await provider.getActionHistory(limit: 10);
      
      if (mounted) {
        setState(() {
          recentActions = history;
          loadingHistory = false;
        });
      }
    } catch (e) {
      print('[AUTOMATION] Error loading action history: $e');
      if (mounted) {
        setState(() {
          loadingHistory = false;
        });
      }
    }
  }
  
  @override
  void dispose() {
    final provider = Provider.of<IrrigationProvider>(context, listen: false);
    provider.removeListener(_onProviderUpdate);
    super.dispose();
  }

  void _toggleAutomation() async {
    final provider = Provider.of<IrrigationProvider>(context, listen: false);
    
    final newState = !automationEnabled;
    final message = await provider.toggleAutomation(enable: newState);
    
    setState(() {
      automationEnabled = newState;
    });
    
    _showSnackBar(message);
  }

  void _saveSettings() async {
    final provider = Provider.of<IrrigationProvider>(context, listen: false);
    
    // Validate thresholds
    if (maxMoistureThreshold <= minMoistureThreshold) {
      _showSnackBar('Max threshold must be greater than min threshold', isError: true);
      return;
    }
    
    // Save dual moisture thresholds to backend
    final message = await provider.updateDualThresholds(
      minThreshold: minMoistureThreshold,
      maxThreshold: maxMoistureThreshold,
    );
    
    _showSnackBar(message);
    
    // Reload action history after settings change
    _loadActionHistory();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error : Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: isError
            ? Colors.red[700]
            : Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Text(
          'Soil Moisture Automation',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 25.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Smart irrigation powered by real-time soil data from Group 2',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            fontSize: 13.6,
          ),
        ),
        const SizedBox(height: 32),

        // Automation Toggle Card
        _buildAutomationToggleCard(theme, isDark),
        const SizedBox(height: 24),

        // Metrics Cards Row
        _buildMetricsCards(theme, isDark),
        const SizedBox(height: 24),

        // 24-Hour Moisture Trends Chart
        _build24HourTrendsCard(theme, isDark),
        const SizedBox(height: 24),

        // Weather Forecast Integration
        _buildWeatherForecastCard(theme, isDark),
        const SizedBox(height: 24),

        // Automation Settings
        _buildAutomationSettingsCard(theme, isDark),
        const SizedBox(height: 24),

        // Recent Automated Irrigation
        _buildRecentIrrigationCard(theme, isDark),
      ],
    );
  }

  Widget _buildAutomationToggleCard(ThemeData theme, bool isDark) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.settings_suggest,
                    color: Color(0xFF3B82F6),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Soil Moisture Automation',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Enable to automatically irrigate based on soil moisture data',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          fontSize: 11.9,
                        ),
                      ),
                    ],
                  ),
                ),
                // Toggle Switch
                GestureDetector(
                  onTap: _toggleAutomation,
                  child: Container(
                    width: 56,
                    height: 28,
                    decoration: BoxDecoration(
                      color: automationEnabled ? const Color(0xFF3B82F6) : const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 200),
                      alignment: automationEnabled ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (automationEnabled) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16.8, vertical: 16.8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: Color(0xFF15803D),
                      fontSize: 11.9,
                      fontWeight: FontWeight.w400,
                    ),
                    children: [
                      const TextSpan(text: 'Current soil moisture: '),
                      TextSpan(
                        text: '${currentMoisture.toInt()}%',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const TextSpan(text: ' • Range: '),
                      TextSpan(
                        text: '${minMoistureThreshold.toInt()}%-${maxMoistureThreshold.toInt()}%',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(
                        text: currentMoisture < minMoistureThreshold
                            ? ' (TOO DRY - Pump will turn ON)'
                            : currentMoisture > maxMoistureThreshold
                                ? ' (TOO WET - Pump will turn OFF)'
                                : ' (OPTIMAL)',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: currentMoisture < minMoistureThreshold
                              ? const Color(0xFFDC2626)
                              : currentMoisture > maxMoistureThreshold
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsCards(ThemeData theme, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 768) {
          return Row(
            children: [
              Expanded(child: _buildSoilMoistureCard(theme, isDark)),
              const SizedBox(width: 24),
              Expanded(child: _buildTemperatureCard(theme, isDark)),
              const SizedBox(width: 24),
              Expanded(child: _buildWeatherSyncCard(theme, isDark)),
            ],
          );
        } else {
          return Column(
            children: [
              _buildSoilMoistureCard(theme, isDark),
              const SizedBox(height: 16),
              _buildTemperatureCard(theme, isDark),
              const SizedBox(height: 16),
              _buildWeatherSyncCard(theme, isDark),
            ],
          );
        }
      },
    );
  }

  Widget _buildSoilMoistureCard(ThemeData theme, bool isDark) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.settings_suggest,
                    color: Color(0xFF3B82F6),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Soil Moisture',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          fontSize: 11.9,
                        ),
                      ),
                      Text(
                        '${currentMoisture.toInt()}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 25.5,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(9999),
              child: SizedBox(
                height: 8,
                child: Stack(
                  children: [
                    Container(color: const Color(0xFFE5E7EB)),
                    FractionallySizedBox(
                      widthFactor: currentMoisture / 100,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFFB923C), Color(0xFF4ADE80), Color(0xFF60A5FA)],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Labels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Dry',
                  style: TextStyle(
                    fontSize: 10.2,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                ),
                Text(
                  'Optimal',
                  style: TextStyle(
                    fontSize: 10.2,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                ),
                Text(
                  'Wet',
                  style: TextStyle(
                    fontSize: 10.2,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemperatureCard(ThemeData theme, bool isDark) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.thermostat,
                    color: Color(0xFFF97316),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Temperature',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          fontSize: 11.9,
                        ),
                      ),
                      const Text(
                        '28°C',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 25.5,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Optimal range: 22-30°C',
              style: TextStyle(
                fontSize: 11.9,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '✓ Within optimal range',
              style: TextStyle(
                fontSize: 11.9,
                color: Color(0xFF16A34A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherSyncCard(ThemeData theme, bool isDark) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEFCE8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.wb_sunny,
                    color: Color(0xFFEAB308),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weather Sync',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          fontSize: 11.9,
                        ),
                      ),
                      const Text(
                        'Active',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 25.5,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Connected to Group 2',
              style: TextStyle(
                fontSize: 11.9,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
              ),
            ),
            Text(
              'weather station',
              style: TextStyle(
                fontSize: 11.9,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Humidity: 68% • Wind: 12',
              style: TextStyle(
                fontSize: 11.9,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
            ),
            Text(
              'km/h',
              style: TextStyle(
                fontSize: 11.9,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _build24HourTrendsCard(ThemeData theme, bool isDark) {
    return Consumer<IrrigationProvider>(
      builder: (context, provider, child) {
        return Card(
          elevation: 1,
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
                        const Icon(
                          Icons.timeline,
                          color: Color(0xFF3B82F6),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '24-Hour Moisture Trends',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.6,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Last updated: Just now',
                      style: TextStyle(
                        fontSize: 11.9,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Interactive chart with real data
                SizedBox(
                  height: 300,
                  child: _RealMoistureChart(
                    provider: provider,
                    minThreshold: minMoistureThreshold,
                    maxThreshold: maxMoistureThreshold,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Color(0xFFDC2626),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'MIN threshold at ${minMoistureThreshold.toInt()}% - Pump turns ON when moisture drops below',
                            style: TextStyle(
                              fontSize: 11.9,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2563EB),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'MAX threshold at ${maxMoistureThreshold.toInt()}% - Pump turns OFF when moisture rises above',
                            style: TextStyle(
                              fontSize: 11.9,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWeatherForecastCard(ThemeData theme, bool isDark) {
    return Consumer<IrrigationProvider>(
      builder: (context, provider, child) {
        return Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.thermostat,
                      color: Color(0xFFF97316),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Temperature Trends - Last 24 Hours',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Real temperature chart
                SizedBox(
                  height: 250,
                  child: _RealTemperatureChart(
                    provider: provider,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(height: 16),
                // Legend
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF97316),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Current Temperature: ${provider.temperature.toStringAsFixed(1)}°C',
                      style: TextStyle(
                        fontSize: 11.9,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAutomationSettingsCard(ThemeData theme, bool isDark) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Automation Settings',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.6,
                  ),
                ),
                ElevatedButton(
                  onPressed: _saveSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(fontSize: 13.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Min Moisture Threshold Slider
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.water_drop, size: 16, color: Color(0xFFDC2626)),
                    const SizedBox(width: 8),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 11.9,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF374151),
                        ),
                        children: [
                          const TextSpan(text: 'Minimum (Critical Low): '),
                          TextSpan(
                            text: '${minMoistureThreshold.toInt()}%',
                            style: const TextStyle(color: Color(0xFFDC2626)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SliderTheme(
                  data: const SliderThemeData(
                    trackHeight: 8,
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10),
                    overlayShape: RoundSliderOverlayShape(overlayRadius: 20),
                    activeTrackColor: Color(0xFFDC2626),
                    inactiveTrackColor: Color(0xFFFECACA),
                    thumbColor: Color(0xFFDC2626),
                  ),
                  child: Slider(
                    value: minMoistureThreshold,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    onChanged: (value) {
                      setState(() {
                        minMoistureThreshold = value;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pump turns ON when soil moisture drops below this level',
                  style: TextStyle(
                    fontSize: 11.9,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Max Moisture Threshold Slider
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.water_drop, size: 16, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 11.9,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF374151),
                        ),
                        children: [
                          const TextSpan(text: 'Maximum (Critical High): '),
                          TextSpan(
                            text: '${maxMoistureThreshold.toInt()}%',
                            style: const TextStyle(color: Color(0xFF2563EB)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SliderTheme(
                  data: const SliderThemeData(
                    trackHeight: 8,
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10),
                    overlayShape: RoundSliderOverlayShape(overlayRadius: 20),
                    activeTrackColor: Color(0xFF2563EB),
                    inactiveTrackColor: Color(0xFFBFDBFE),
                    thumbColor: Color(0xFF2563EB),
                  ),
                  child: Slider(
                    value: maxMoistureThreshold,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    onChanged: (value) {
                      setState(() {
                        maxMoistureThreshold = value;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pump turns OFF when soil moisture rises above this level',
                  style: TextStyle(
                    fontSize: 11.9,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Duration Settings
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Minimum Duration (minutes)',
                        style: TextStyle(
                          fontSize: 11.9,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: minDuration.toString(),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() {
                            minDuration = int.tryParse(value) ?? 5;
                          });
                        },
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Maximum Duration (minutes)',
                        style: TextStyle(
                          fontSize: 11.9,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: maxDuration.toString(),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() {
                            maxDuration = int.tryParse(value) ?? 30;
                          });
                        },
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentIrrigationCard(ThemeData theme, bool isDark) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Automated Irrigation',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.6,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _loadActionHistory,
                  tooltip: 'Refresh history',
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (loadingHistory)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (recentActions.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(Icons.history, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No automated irrigation events yet',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          fontSize: 13.6,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...recentActions
                  .where((action) => action['trigger'] == 'automation')
                  .take(5)
                  .map((action) => Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _buildRealIrrigationHistoryItem(action, isDark),
                      ))
                  .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildRealIrrigationHistoryItem(Map<String, dynamic> action, bool isDark) {
    final timestamp = DateTime.parse(action['timestamp']);
    final timeStr = _formatTimestamp(timestamp);
    final details = action['details'] as Map<String, dynamic>? ?? {};
    final moisture = details['moisture']?.toString() ?? 'N/A';
    final minThreshold = details['min_threshold']?.toString() ?? details['threshold']?.toString() ?? minMoistureThreshold.toInt().toString();
    final maxThreshold = details['max_threshold']?.toString() ?? maxMoistureThreshold.toInt().toString();
    final actionType = action['action']?.toString() ?? 'UNKNOWN';
    final reason = details['reason']?.toString() ?? '';
    
    String triggerText;
    if (reason == 'moisture_below_minimum') {
      triggerText = 'Moisture < $minThreshold%';
    } else if (reason == 'moisture_above_maximum') {
      triggerText = 'Moisture ≥ $maxThreshold%';
    } else if (reason == 'moisture_at_or_below_threshold') {
      triggerText = 'Moisture ≤ $minThreshold%';
    } else if (reason == 'moisture_above_threshold') {
      triggerText = 'Moisture > $minThreshold%';
    } else {
      triggerText = 'Auto trigger';
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: actionType == 'ON' ? const Color(0xFFDCFCE7) : const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              actionType == 'ON' ? Icons.power : Icons.power_off,
              color: actionType == 'ON' ? const Color(0xFF16A34A) : const Color(0xFF3B82F6),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  timeStr,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.6,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pump ${actionType} • $triggerText',
                  style: const TextStyle(
                    fontSize: 11.9,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$moisture%',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 20.4,
                  color: actionType == 'ON' ? const Color(0xFFDC2626) : const Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Moisture',
                style: TextStyle(
                  fontSize: 11.9,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inDays == 0) {
      // Today
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

}

// Custom painter for moisture chart
class _MoistureChartPainter extends CustomPainter {
  final double currentMoisture;
  final double threshold;

  _MoistureChartPainter(this.currentMoisture, this.threshold);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Draw grid lines
    paint
      ..color = const Color(0xFFF0F0F0)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Horizontal grid lines
    for (int i = 0; i <= 5; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Vertical grid lines
    for (int i = 0; i <= 6; i++) {
      final x = size.width * i / 6;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw Y-axis labels - clean horizontal labels like in the image
    final yLabels = ['0', '15', '30', '45'];
    for (int i = 0; i < yLabels.length; i++) {
      textPainter.text = TextSpan(
        text: yLabels[i],
        style: const TextStyle(
          color: Color(0xFF9CA3AF),
          fontSize: 12,
        ),
      );
      textPainter.layout();
      final y = size.height * i / 3;
      textPainter.paint(
        canvas,
        Offset(0, y - textPainter.height / 2),
      );
    }

    // Draw X-axis labels
    final xLabels = ['00:00', '04:00', '08:00', '12:00', '16:00', '20:00', '24:00'];
    for (int i = 0; i < xLabels.length; i++) {
      textPainter.text = TextSpan(
        text: xLabels[i],
        style: const TextStyle(
          color: Color(0xFF9CA3AF),
          fontSize: 12,
        ),
      );
      textPainter.layout();
      final x = size.width * i / 6;
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height - textPainter.height),
      );
    }

    // Draw moisture curve with exact pattern from image
    paint
      ..color = const Color(0xFF3B82F6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final points = _generateExactMoisturePoints(size);
    path.moveTo(points[0].dx, points[0].dy);
    for (var point in points) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);

    // Fill area under curve
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();
    
    paint
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF3B82F6).withOpacity(0.18),
          const Color(0xFF3B82F6).withOpacity(0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, paint);
  }

  List<Offset> _generateExactMoisturePoints(Size size) {
    // Exact pattern from the image: starts at 35%, dips to ~33%, rises to 45%, drops to 40%, rises to 45%
    final moistureValues = [35, 33, 35, 38, 42, 45, 44, 42, 40, 40, 42, 45];
    final points = <Offset>[];
    
    for (int i = 0; i < moistureValues.length; i++) {
      final x = size.width * i / (moistureValues.length - 1);
      final y = size.height * (1 - moistureValues[i] / 45); // Scale to 0-45 range to match Y-axis
      points.add(Offset(x, y.clamp(0, size.height)));
    }
    return points;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Custom painter for weather forecast
class _WeatherForecastPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Draw grid lines
    paint
      ..color = const Color(0xFFF0F0F0)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Horizontal grid lines
    for (int i = 0; i <= 5; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Vertical grid lines
    for (int i = 0; i <= 7; i++) {
      final x = size.width * i / 7;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw left Y-axis labels (0, 8, 16, 24, 32)
    final leftYLabels = ['0', '8', '16', '24', '32'];
    for (int i = 0; i < leftYLabels.length; i++) {
      textPainter.text = TextSpan(
        text: leftYLabels[i],
        style: const TextStyle(
          color: Color(0xFF9CA3AF),
          fontSize: 12,
        ),
      );
      textPainter.layout();
      final y = size.height * i / 4;
      textPainter.paint(
        canvas,
        Offset(0, y - textPainter.height / 2),
      );
    }

    // Draw right Y-axis labels (0, 20, 40, 60, 80)
    final rightYLabels = ['0', '20', '40', '60', '80'];
    for (int i = 0; i < rightYLabels.length; i++) {
      textPainter.text = TextSpan(
        text: rightYLabels[i],
        style: const TextStyle(
          color: Color(0xFF9CA3AF),
          fontSize: 12,
        ),
      );
      textPainter.layout();
      final y = size.height * i / 4;
      textPainter.paint(
        canvas,
        Offset(size.width - textPainter.width, y - textPainter.height / 2),
      );
    }

    // Draw X-axis labels (days)
    final xLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    for (int i = 0; i < xLabels.length; i++) {
      textPainter.text = TextSpan(
        text: xLabels[i],
        style: const TextStyle(
          color: Color(0xFF9CA3AF),
          fontSize: 12,
        ),
      );
      textPainter.layout();
      final x = size.width * (i + 0.5) / 7;
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height - textPainter.height),
      );
    }

    // Draw blue line (humidity) with exact values from image
    paint
      ..color = const Color(0xFF3B82F6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    final humidityValues = [70, 60, 70, 65, 75, 70, 70]; // Blue line values (humidity)
    const days = 7;
    final humidityPath = Path();
    
    for (int i = 0; i < days; i++) {
      final x = size.width * (i + 0.5) / days;
      final y = size.height * (1 - humidityValues[i] / 80); // Scale to 0-80 range (right Y-axis)
      if (i == 0) {
        humidityPath.moveTo(x, y);
      } else {
        humidityPath.lineTo(x, y);
      }
    }
    canvas.drawPath(humidityPath, paint);

    // Draw orange line (temperature) with exact values from image
    paint
      ..color = const Color(0xFFF97316)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    final temperatureValues = [26, 24, 28, 27, 26, 28, 28]; // Orange line values (temperature)
    final temperaturePath = Path();
    
    for (int i = 0; i < days; i++) {
      final x = size.width * (i + 0.5) / days;
      final y = size.height * (1 - temperatureValues[i] / 32); // Scale to 0-32 range (left Y-axis)
      if (i == 0) {
        temperaturePath.moveTo(x, y);
      } else {
        temperaturePath.lineTo(x, y);
      }
    }
    canvas.drawPath(temperaturePath, paint);

    // Draw data points as circles
    paint.style = PaintingStyle.fill;
    
    // Blue circles for humidity
    paint.color = const Color(0xFF3B82F6);
    for (int i = 0; i < days; i++) {
      final x = size.width * (i + 0.5) / days;
      final y = size.height * (1 - humidityValues[i] / 80);
      canvas.drawCircle(Offset(x, y), 3, paint);
    }

    // Orange circles for temperature
    paint.color = const Color(0xFFF97316);
    for (int i = 0; i < days; i++) {
      final x = size.width * (i + 0.5) / days;
      final y = size.height * (1 - temperatureValues[i] / 32);
      canvas.drawCircle(Offset(x, y), 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Interactive Moisture Chart Widget
class _InteractiveMoistureChart extends StatefulWidget {
  final double currentMoisture;
  final double threshold;

  const _InteractiveMoistureChart({
    required this.currentMoisture,
    required this.threshold,
  });

  @override
  State<_InteractiveMoistureChart> createState() => _InteractiveMoistureChartState();
}

class _InteractiveMoistureChartState extends State<_InteractiveMoistureChart> {
  double? hoverX;
  int? hoverIndex;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final localPosition = box.globalToLocal(event.position);
        final chartWidth = box.size.width;
        final xPosition = localPosition.dx;
        
        // Calculate which data point is closest
        final moistureValues = [35, 33, 35, 38, 42, 45, 44, 42, 40, 40, 42, 45];
        
        final segmentWidth = chartWidth / (moistureValues.length - 1);
        final index = (xPosition / segmentWidth).round().clamp(0, moistureValues.length - 1);
        
        setState(() {
          hoverX = xPosition;
          hoverIndex = index;
        });
      },
      onExit: (event) {
        setState(() {
          hoverX = null;
          hoverIndex = null;
        });
      },
      child: Stack(
        children: [
          CustomPaint(
            painter: _MoistureChartPainter(widget.currentMoisture, widget.threshold),
            size: const Size(double.infinity, 300),
          ),
          if (hoverX != null && hoverIndex != null)
            Positioned(
              left: hoverX! - 50,
              top: 20,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFF3B82F6)),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getTimeLabel(hoverIndex!),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    Text(
                      'moisture: ${_getMoistureValue(hoverIndex!)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (hoverX != null)
            Positioned(
              left: hoverX! - 0.5,
              top: 0,
              bottom: 0,
              child: Container(
                width: 1,
                decoration: const BoxDecoration(
                  color: Color(0xFF3B82F6),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getTimeLabel(int index) {
    final timeLabels = ['00:00', '04:00', '08:00', '12:00', '16:00', '20:00', '24:00'];
    final moistureValues = [35, 33, 35, 38, 42, 45, 44, 42, 40, 40, 42, 45];
    final segmentSize = moistureValues.length / timeLabels.length;
    final timeIndex = (index / segmentSize).floor().clamp(0, timeLabels.length - 1);
    return timeLabels[timeIndex];
  }

  int _getMoistureValue(int index) {
    final moistureValues = [35, 33, 35, 38, 42, 45, 44, 42, 40, 40, 42, 45];
    return moistureValues[index.clamp(0, moistureValues.length - 1)];
  }
}

// Real Temperature Chart Widget - Uses Actual Data from Provider
class _RealTemperatureChart extends StatelessWidget {
  final IrrigationProvider provider;
  final bool isDark;

  const _RealTemperatureChart({required this.provider, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final temperatureData = provider.getTemperatureForRange(const Duration(hours: 24));
    
    if (temperatureData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.thermostat_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('Collecting temperature data...', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
            const SizedBox(height: 8),
            Text('Data from ESP32 sensors', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            const SizedBox(height: 16),
            const CircularProgressIndicator(strokeWidth: 2),
          ],
        ),
      );
    }
    
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                return Text('${date.hour}:00', style: const TextStyle(fontSize: 12));
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text('${value.toInt()}°', style: const TextStyle(fontSize: 12)),
            ),
          ),
        ),
        minX: temperatureData.first.milliseconds.toDouble(),
        maxX: temperatureData.last.milliseconds.toDouble(),
        minY: 0,
        maxY: 40,
        lineBarsData: [
          LineChartBarData(
            spots: temperatureData.map((point) => FlSpot(point.milliseconds.toDouble(), point.value)).toList(),
            isCurved: true,
            color: const Color(0xFFF97316),
            barWidth: 2,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: const Color(0xFFF97316).withOpacity(0.1)),
          ),
        ],
      ),
    );
  }
}

// Interactive Weather Chart Widget
class _InteractiveWeatherChart extends StatefulWidget {
  const _InteractiveWeatherChart();

  @override
  State<_InteractiveWeatherChart> createState() => _InteractiveWeatherChartState();
}

class _InteractiveWeatherChartState extends State<_InteractiveWeatherChart> {
  double? hoverX;
  int? hoverIndex;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final localPosition = box.globalToLocal(event.position);
        final chartWidth = box.size.width;
        final xPosition = localPosition.dx;
        
        // Calculate which data point is closest
        const days = 7;
        final segmentWidth = chartWidth / days;
        final index = (xPosition / segmentWidth).round().clamp(0, days - 1);
        
        setState(() {
          hoverX = xPosition;
          hoverIndex = index;
        });
      },
      onExit: (event) {
        setState(() {
          hoverX = null;
          hoverIndex = null;
        });
      },
      child: Stack(
        children: [
          CustomPaint(
            painter: _WeatherForecastPainter(),
            size: const Size(double.infinity, 250),
          ),
          if (hoverX != null && hoverIndex != null)
            Positioned(
              left: hoverX! - 60,
              top: 20,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFF3B82F6)),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getDayLabel(hoverIndex!),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    Text(
                      'Temperature (°C): ${_getTemperatureValue(hoverIndex!)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFF97316),
                      ),
                    ),
                    Text(
                      'Humidity (%): ${_getHumidityValue(hoverIndex!)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (hoverX != null)
            Positioned(
              left: hoverX! - 0.5,
              top: 0,
              bottom: 0,
              child: Container(
                width: 1,
                decoration: const BoxDecoration(
                  color: Color(0xFF3B82F6),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getDayLabel(int index) {
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return dayLabels[index.clamp(0, dayLabels.length - 1)];
  }

  int _getTemperatureValue(int index) {
    const temperatureValues = [26, 24, 28, 27, 26, 28, 28];
    return temperatureValues[index.clamp(0, temperatureValues.length - 1)];
  }

  int _getHumidityValue(int index) {
    const humidityValues = [70, 60, 70, 65, 75, 70, 70];
    return humidityValues[index.clamp(0, humidityValues.length - 1)];
  }
}

// ============================================
// NEW: Real Moisture Chart Using Actual Data
// ============================================

class _RealMoistureChart extends StatelessWidget {
  final IrrigationProvider provider;
  final double minThreshold;
  final double maxThreshold;
  final bool isDark;

  const _RealMoistureChart({
    required this.provider,
    required this.minThreshold,
    required this.maxThreshold,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final moistureData = provider.getMoistureForRange(const Duration(hours: 24));
    
    if (moistureData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.water_drop_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Collecting moisture data...',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Data will appear as it\'s received from sensors',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      );
    }
    
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 15,
          verticalInterval: null,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFF0F0F0),
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFF0F0F0),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 4 * 3600 * 1000,  // 4 hours in milliseconds
              getTitlesWidget: (value, meta) {
                final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    '${date.hour.toString().padLeft(2, '0')}:00',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 15,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFF0F0F0),
          ),
        ),
        minX: moistureData.first.milliseconds.toDouble(),
        maxX: moistureData.last.milliseconds.toDouble(),
        minY: 0,
        maxY: 100,  // Moisture is 0-100%
        lineBarsData: [
          // Min threshold line (red dashed)
          LineChartBarData(
            spots: [
              FlSpot(moistureData.first.milliseconds.toDouble(), minThreshold),
              FlSpot(moistureData.last.milliseconds.toDouble(), minThreshold),
            ],
            isCurved: false,
            color: const Color(0xFFDC2626),
            barWidth: 2,
            dotData: const FlDotData(show: false),
            dashArray: [5, 5],
          ),
          // Max threshold line (blue dashed)
          LineChartBarData(
            spots: [
              FlSpot(moistureData.first.milliseconds.toDouble(), maxThreshold),
              FlSpot(moistureData.last.milliseconds.toDouble(), maxThreshold),
            ],
            isCurved: false,
            color: const Color(0xFF2563EB),
            barWidth: 2,
            dotData: const FlDotData(show: false),
            dashArray: [5, 5],
          ),
          // Moisture line
          LineChartBarData(
            spots: moistureData.map((point) {
              return FlSpot(
                point.milliseconds.toDouble(),
                point.value,
              );
            }).toList(),
            isCurved: true,
            color: const Color(0xFF3B82F6),
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF3B82F6).withOpacity(0.18),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                final date = DateTime.fromMillisecondsSinceEpoch(barSpot.x.toInt());
                return LineTooltipItem(
                  '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}\n',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  children: [
                    TextSpan(
                      text: 'Moisture: ${barSpot.y.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}

