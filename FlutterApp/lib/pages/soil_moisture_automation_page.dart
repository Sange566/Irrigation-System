import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/irrigation_provider.dart';

/// Soil Moisture Automation Page with Dual Threshold Control
/// Implements min/max thresholds for automatic irrigation control
class SoilMoistureAutomationPage extends StatefulWidget {
  const SoilMoistureAutomationPage({super.key});

  @override
  State<SoilMoistureAutomationPage> createState() => _SoilMoistureAutomationPageState();
}

class _SoilMoistureAutomationPageState extends State<SoilMoistureAutomationPage> {
  // Automation state
  bool _automationEnabled = false;
  double _minThreshold = 25.0; // Critical Low
  double _maxThreshold = 60.0; // Critical High
  
  // UI state
  bool _isLoading = false;
  String? _lastCommand;
  DateTime? _lastCommandTime;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _initializeFromProvider();
  }

  /// Load saved preferences
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _minThreshold = prefs.getDouble('min_moisture_threshold') ?? 25.0;
      _maxThreshold = prefs.getDouble('max_moisture_threshold') ?? 60.0;
      _automationEnabled = prefs.getBool('automation_enabled') ?? false;
    });
  }

  /// Save preferences
  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('min_moisture_threshold', _minThreshold);
    await prefs.setDouble('max_moisture_threshold', _maxThreshold);
    await prefs.setBool('automation_enabled', _automationEnabled);
  }

  /// Initialize from provider
  void _initializeFromProvider() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<IrrigationProvider>(context, listen: false);
      setState(() {
        _automationEnabled = provider.automationEnabled;
      });
    });
  }

  /// Toggle automation
  Future<void> _toggleAutomation() async {
    final provider = Provider.of<IrrigationProvider>(context, listen: false);
    
    setState(() {
      _isLoading = true;
    });

    try {
      final newState = !_automationEnabled;
      await provider.toggleAutomation(enable: newState);
      
      setState(() {
        _automationEnabled = newState;
        _isLoading = false;
      });
      
      await _savePreferences();
      _showMessage(newState ? 'Automation enabled' : 'Automation disabled', isError: false);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showMessage('Failed to toggle automation', isError: true);
    }
  }

  /// Save thresholds
  Future<void> _saveThresholds() async {
    if (_minThreshold >= _maxThreshold) {
      _showMessage('Min threshold must be less than max threshold', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _savePreferences();
      
      // Send both thresholds to the backend
      final provider = Provider.of<IrrigationProvider>(context, listen: false);
      final message = await provider.updateDualThresholds(
        minThreshold: _minThreshold,
        maxThreshold: _maxThreshold,
      );
      
      setState(() {
        _isLoading = false;
      });
      
      _showMessage(message, isError: false);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showMessage('Failed to save thresholds: ${e.toString()}', isError: true);
    }
  }

  /// Check automation logic and send commands if needed
  void _checkAutomationLogic(double currentMoisture, IrrigationProvider provider) {
    if (!_automationEnabled) return;
    
    // Prevent repeated commands within 30 seconds
    if (_lastCommandTime != null && 
        DateTime.now().difference(_lastCommandTime!) < const Duration(seconds: 30)) {
      return;
    }

    String? commandToSend;
    
    if (currentMoisture < _minThreshold && _lastCommand != 'ON') {
      commandToSend = 'ON';
      print('[AUTOMATION] Moisture $currentMoisture% < Min $_minThreshold% → Turning pump ON');
    } else if (currentMoisture > _maxThreshold && _lastCommand != 'OFF') {
      commandToSend = 'OFF';
      print('[AUTOMATION] Moisture $currentMoisture% > Max $_maxThreshold% → Turning pump OFF');
    }

    if (commandToSend != null) {
      _sendCommand(commandToSend, provider);
    }
  }

  /// Send MQTT command via backend
  Future<void> _sendCommand(String command, IrrigationProvider provider) async {
    try {
      if (command == 'ON') {
        await provider.turnPumpOn();
      } else {
        await provider.turnPumpOff();
      }
      
      setState(() {
        _lastCommand = command;
        _lastCommandTime = DateTime.now();
      });
      
      _showMessage('Pump turned $command', isError: false);
    } catch (e) {
      print('[AUTOMATION] Failed to send command: $e');
    }
  }

  /// Get soil status label
  String _getSoilStatus(double moisture) {
    if (moisture < _minThreshold) {
      return 'Dry';
    } else if (moisture > _maxThreshold) {
      return 'Wet';
    } else {
      return 'Optimal';
    }
  }

  /// Get soil status color
  Color _getSoilStatusColor(double moisture) {
    if (moisture < _minThreshold) {
      return const Color(0xFFDC2626); // Red
    } else if (moisture > _maxThreshold) {
      return const Color(0xFF2563EB); // Blue
    } else {
      return const Color(0xFF16A34A); // Green
    }
  }

  /// Show message
  void _showMessage(String message, {required bool isError}) {
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
        backgroundColor: isError 
            ? const Color(0xFFDC2626) 
            : const Color(0xFF16A34A),
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

    return Consumer<IrrigationProvider>(
      builder: (context, provider, child) {
        final currentMoisture = provider.soilMoisture;
        final pumpStatus = provider.pumpStatus;
        final soilStatus = _getSoilStatus(currentMoisture);
        final statusColor = _getSoilStatusColor(currentMoisture);

        // Check automation logic when moisture changes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkAutomationLogic(currentMoisture, provider);
        });

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(theme, isDark),
              const SizedBox(height: 32),

              // Automation Toggle Card
              _buildAutomationToggle(theme, isDark),
              const SizedBox(height: 24),

              // Current Status Card
              _buildCurrentStatusCard(
                theme, 
                isDark, 
                currentMoisture, 
                pumpStatus, 
                soilStatus, 
                statusColor,
              ),
              const SizedBox(height: 24),

              // Threshold Settings Card
              _buildThresholdSettings(theme, isDark, currentMoisture),
              const SizedBox(height: 24),

              // Info Card
              _buildInfoCard(theme, isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Soil Moisture Automation',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 28,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Automated irrigation based on dual moisture thresholds',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildAutomationToggle(ThemeData theme, bool isDark) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            // Icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _automationEnabled 
                    ? const Color(0xFF3B82F6).withOpacity(0.1)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _automationEnabled ? Icons.auto_mode : Icons.block,
                color: _automationEnabled 
                    ? const Color(0xFF3B82F6)
                    : const Color(0xFF9CA3AF),
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Automation Mode',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _automationEnabled 
                        ? 'System will control pump automatically'
                        : 'Manual control only',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark 
                          ? const Color(0xFF9CA3AF) 
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            // Toggle Switch
            _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Switch(
                    value: _automationEnabled,
                    onChanged: (_) => _toggleAutomation(),
                    activeColor: const Color(0xFF3B82F6),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStatusCard(
    ThemeData theme,
    bool isDark,
    double currentMoisture,
    bool pumpStatus,
    String soilStatus,
    Color statusColor,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Status',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 24),
            
            // Moisture Reading
            Row(
              children: [
                Expanded(
                  child: _buildStatusItem(
                    icon: Icons.water_drop,
                    label: 'Soil Moisture',
                    value: '${currentMoisture.toStringAsFixed(1)}%',
                    color: const Color(0xFF3B82F6),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatusItem(
                    icon: Icons.thermostat,
                    label: 'Soil Status',
                    value: soilStatus,
                    color: statusColor,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Pump Status
            Row(
              children: [
                Expanded(
                  child: _buildStatusItem(
                    icon: pumpStatus ? Icons.power : Icons.power_off,
                    label: 'Pump Status',
                    value: pumpStatus ? 'ON' : 'OFF',
                    color: pumpStatus 
                        ? const Color(0xFF16A34A) 
                        : const Color(0xFF6B7280),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatusItem(
                    icon: Icons.access_time,
                    label: 'Last Update',
                    value: _formatLastUpdate(),
                    color: const Color(0xFF9CA3AF),
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            
            // Visual moisture indicator
            const SizedBox(height: 24),
            _buildMoistureIndicator(currentMoisture, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isDark 
                        ? const Color(0xFF9CA3AF) 
                        : const Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoistureIndicator(double currentMoisture, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Moisture Range',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark 
                    ? const Color(0xFF9CA3AF) 
                    : const Color(0xFF6B7280),
              ),
            ),
            Text(
              '${currentMoisture.toStringAsFixed(1)}%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3B82F6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Stack(
          children: [
            // Background track
            Container(
              height: 12,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFDC2626), // Red (Dry)
                    Color(0xFFFBBF24), // Yellow
                    Color(0xFF16A34A), // Green (Optimal)
                    Color(0xFFFBBF24), // Yellow
                    Color(0xFF2563EB), // Blue (Wet)
                  ],
                ),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            // Current position indicator
            Positioned(
              left: (currentMoisture / 100) * 
                  (MediaQuery.of(context).size.width - 96) - 6,
              top: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF3B82F6),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '0% (Dry)',
              style: TextStyle(
                fontSize: 10,
                color: isDark 
                    ? const Color(0xFF9CA3AF) 
                    : const Color(0xFF6B7280),
              ),
            ),
            Text(
              '50% (Optimal)',
              style: TextStyle(
                fontSize: 10,
                color: isDark 
                    ? const Color(0xFF9CA3AF) 
                    : const Color(0xFF6B7280),
              ),
            ),
            Text(
              '100% (Wet)',
              style: TextStyle(
                fontSize: 10,
                color: isDark 
                    ? const Color(0xFF9CA3AF) 
                    : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildThresholdSettings(
    ThemeData theme,
    bool isDark,
    double currentMoisture,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Threshold Settings',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveThresholds,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save, size: 18),
                  label: const Text('Save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Min Threshold Slider
            _buildThresholdSlider(
              label: 'Minimum Threshold (Critical Low)',
              value: _minThreshold,
              color: const Color(0xFFDC2626),
              icon: Icons.arrow_downward,
              description: 'Pump will turn ON when moisture drops below this level',
              onChanged: (value) {
                setState(() {
                  _minThreshold = value;
                  if (_minThreshold >= _maxThreshold) {
                    _maxThreshold = _minThreshold + 5;
                  }
                });
              },
              isDark: isDark,
            ),
            const SizedBox(height: 32),
            
            // Max Threshold Slider
            _buildThresholdSlider(
              label: 'Maximum Threshold (Critical High)',
              value: _maxThreshold,
              color: const Color(0xFF2563EB),
              icon: Icons.arrow_upward,
              description: 'Pump will turn OFF when moisture rises above this level',
              onChanged: (value) {
                setState(() {
                  _maxThreshold = value;
                  if (_maxThreshold <= _minThreshold) {
                    _minThreshold = _maxThreshold - 5;
                  }
                });
              },
              isDark: isDark,
            ),
            
            // Current position indicator
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF3B82F6).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFF3B82F6),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      currentMoisture < _minThreshold
                          ? 'Current moisture is BELOW minimum → Pump should be ON'
                          : currentMoisture > _maxThreshold
                              ? 'Current moisture is ABOVE maximum → Pump should be OFF'
                              : 'Current moisture is OPTIMAL → No action needed',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark 
                            ? const Color(0xFFE5E7EB) 
                            : const Color(0xFF1F2937),
                        fontWeight: FontWeight.w500,
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
  }

  Widget _buildThresholdSlider({
    required String label,
    required double value,
    required Color color,
    required IconData icon,
    required String description,
    required ValueChanged<double> onChanged,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark 
                          ? const Color(0xFFE5E7EB) 
                          : const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${value.toInt()}%',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 8,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
            activeTrackColor: color,
            inactiveTrackColor: color.withOpacity(0.2),
            thumbColor: color,
            overlayColor: color.withOpacity(0.2),
          ),
          child: Slider(
            value: value,
            min: 0,
            max: 100,
            divisions: 100,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: TextStyle(
            fontSize: 12,
            color: isDark 
                ? const Color(0xFF9CA3AF) 
                : const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(ThemeData theme, bool isDark) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: const Color(0xFFF0FDF4),
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
                    color: const Color(0xFF16A34A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline,
                    color: Color(0xFF16A34A),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'How It Works',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: const Color(0xFF15803D),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoItem(
              '1',
              'System monitors soil moisture in real-time from Group 2 sensors',
            ),
            const SizedBox(height: 12),
            _buildInfoItem(
              '2',
              'When moisture < Min Threshold: Pump turns ON automatically',
            ),
            const SizedBox(height: 12),
            _buildInfoItem(
              '3',
              'When moisture > Max Threshold: Pump turns OFF automatically',
            ),
            const SizedBox(height: 12),
            _buildInfoItem(
              '4',
              'Within range: Pump maintains current state (no repeated commands)',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Color(0xFF16A34A),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF15803D),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  String _formatLastUpdate() {
    if (_lastCommandTime == null) {
      return 'N/A';
    }
    final diff = DateTime.now().difference(_lastCommandTime!);
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${diff.inHours}h ago';
    }
  }
}

