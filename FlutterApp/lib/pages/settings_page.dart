import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/irrigation_provider.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../services/theme_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Backend URL controllers
  late TextEditingController _backendUrlController;
  late TextEditingController _websocketUrlController;
  
  // Settings state
  String selectedTheme = 'light';
  bool _isTesting = false;
  double? _tempThreshold; // Temporary threshold while dragging
  
  @override
  void initState() {
    super.initState();
    _backendUrlController = TextEditingController(text: ApiService.baseUrl);
    _websocketUrlController = TextEditingController(text: WebSocketService.serverUrl);
    
    // Load current theme
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final themeService = Provider.of<ThemeService>(context, listen: false);
      setState(() {
        selectedTheme = themeService.currentTheme;
      });
    });
  }
  
  @override
  void dispose() {
    _backendUrlController.dispose();
    _websocketUrlController.dispose();
    super.dispose();
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
        backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _saveBackendUrl() async {
    final newUrl = _backendUrlController.text.trim();
    if (newUrl.isEmpty) {
      _showSnackBar('Please enter a valid URL', isError: true);
      return;
    }
    
    // Validate URL format
    if (!newUrl.startsWith('http://') && !newUrl.startsWith('https://')) {
      _showSnackBar('URL must start with http:// or https://', isError: true);
      return;
    }
    
    ApiService.setBaseUrl(newUrl);
    _showSnackBar('Backend URL updated to: $newUrl');
  }
  
  Future<void> _saveWebSocketUrl() async {
    final newUrl = _websocketUrlController.text.trim();
    if (newUrl.isEmpty) {
      _showSnackBar('Please enter a valid WebSocket URL', isError: true);
      return;
    }
    
    // Validate WebSocket URL format
    if (!newUrl.startsWith('ws://') && !newUrl.startsWith('wss://')) {
      _showSnackBar('WebSocket URL must start with ws:// or wss://', isError: true);
      return;
    }
    
    WebSocketService.setServerUrl(newUrl);
    _showSnackBar('WebSocket URL updated. Restart app to reconnect.');
  }
  
  Future<void> _testConnection() async {
    setState(() => _isTesting = true);
    
    try {
      final isReachable = await ApiService.isBackendReachable();
      
      if (isReachable) {
        _showSnackBar('✓ Backend connection successful!');
      } else {
        _showSnackBar('✗ Backend not reachable. Check URL and ensure backend is running.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Connection failed: ${e.toString()}', isError: true);
    } finally {
      setState(() => _isTesting = false);
    }
  }
  
  void _autoDetectIP() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Auto-Detect Network IP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Common configurations:'),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.computer),
              title: const Text('Localhost (same device)'),
              subtitle: const Text('http://localhost:8000'),
              onTap: () {
                setState(() {
                  _backendUrlController.text = 'http://localhost:8000';
                  _websocketUrlController.text = 'ws://localhost:8000/ws';
                });
                Navigator.pop(context);
                _showSnackBar('Set to localhost');
              },
            ),
            ListTile(
              leading: const Icon(Icons.phone_android),
              title: const Text('Android Emulator'),
              subtitle: const Text('http://10.0.2.2:5000'),
              onTap: () {
                setState(() {
                  _backendUrlController.text = 'http://10.0.2.2:5000';
                  _websocketUrlController.text = 'ws://10.0.2.2:5000/ws';
                });
                Navigator.pop(context);
                _showSnackBar('Set to Android emulator');
              },
            ),
            ListTile(
              leading: const Icon(Icons.wifi),
              title: const Text('Network (Custom IP)'),
              subtitle: const Text('Enter your computer\'s IP address'),
              onTap: () {
                Navigator.pop(context);
                _showCustomIPDialog();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  void _showCustomIPDialog() {
    final ipController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Network IP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your computer\'s IP address:'),
            const SizedBox(height: 16),
            TextField(
              controller: ipController,
              decoration: const InputDecoration(
                hintText: '10.124.122.189',
                labelText: 'IP Address',
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 8),
            const Text(
              'Example: 10.124.122.189 (WiFi "Wifi" network)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final ip = ipController.text.trim();
              if (ip.isNotEmpty) {
                setState(() {
                  _backendUrlController.text = 'http://$ip:5000';
                  _websocketUrlController.text = 'ws://$ip:5000/ws';
                });
                Navigator.pop(context);
                _showSnackBar('URLs updated to: $ip');
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _clearAllHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All History?'),
        content: const Text(
          'This will clear all flow rate, moisture, and temperature history data. '
          'This action cannot be undone.\n\n'
          'Current data will be preserved in charts until new data arrives.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear History'),
          ),
        ],
      ),
    );
    
    if (confirmed == true && mounted) {
      final provider = Provider.of<IrrigationProvider>(context, listen: false);
      provider.clearHistory();
      _showSnackBar('✓ All history data cleared');
    }
  }
  
  void _runDiagnostic() async {
    final provider = Provider.of<IrrigationProvider>(context, listen: false);
    
    // Show progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            const Text('Running Diagnostic...'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Testing all system components'),
          ],
        ),
      ),
    );
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Run checks
    final backendOk = provider.isBackendConnected;
    final websocketOk = provider.isWebSocketConnected;
    final sensorsOk = provider.lastMoistureUpdate != null;
    final pumpOk = provider.lastPumpUpdate != null;
    final allOk = backendOk && websocketOk && sensorsOk && pumpOk;
    
    Navigator.pop(context);
    
    // Show results
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              allOk ? Icons.check_circle : Icons.warning,
              color: allOk ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
            ),
            const SizedBox(width: 12),
            Text(allOk ? 'All Systems OK' : 'Issues Detected'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCheckItem('Backend Connection', backendOk),
            _buildCheckItem('WebSocket Stream', websocketOk),
            _buildCheckItem('Sensor Data', sensorsOk),
            _buildCheckItem('Pump Data', pumpOk),
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
  
  Widget _buildCheckItem(String label, bool status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            status ? Icons.check_circle : Icons.error,
            color: status ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Consumer<IrrigationProvider>(
      builder: (context, provider, child) {
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'System Settings',
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Configure your irrigation system',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),

              // Backend Connection Settings
              Card(
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
                              color: const Color(0xFF3B82F6).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.cloud,
                              color: Color(0xFF3B82F6),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Backend Connection',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Backend URL
                      Text(
                        'Backend URL',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: isDark ? const Color(0xFFCBD5E1) : Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _backendUrlController,
                              decoration: InputDecoration(
                                hintText: 'http://localhost:8000',
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.content_copy, size: 18),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: _backendUrlController.text));
                                    _showSnackBar('URL copied to clipboard');
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _saveBackendUrl,
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // WebSocket URL
                      Text(
                        'WebSocket URL',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: isDark ? const Color(0xFFCBD5E1) : Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _websocketUrlController,
                              decoration: InputDecoration(
                                hintText: 'ws://localhost:8000/ws',
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.content_copy, size: 18),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: _websocketUrlController.text));
                                    _showSnackBar('URL copied to clipboard');
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _saveWebSocketUrl,
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Connection Status
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark 
                              ? const Color(0xFF334155)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Backend Status:'),
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: provider.isBackendConnected 
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFFEF4444),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      provider.isBackendConnected ? 'Connected' : 'Disconnected',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: provider.isBackendConnected 
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFFEF4444),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('WebSocket Status:'),
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: provider.isWebSocketConnected 
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFFEF4444),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      provider.isWebSocketConnected ? 'Live' : 'Offline',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: provider.isWebSocketConnected 
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFFEF4444),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Action buttons
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _isTesting ? null : _testConnection,
                            icon: _isTesting 
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.wifi_find, size: 18),
                            label: Text(_isTesting ? 'Testing...' : 'Test Connection'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              foregroundColor: Colors.white,
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _autoDetectIP,
                            icon: const Icon(Icons.settings_ethernet, size: 18),
                            label: const Text('Quick Setup'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Automation Settings
              Card(
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
                              Icons.settings_suggest,
                              color: Color(0xFF10B981),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Automation Settings',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Moisture Threshold',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Irrigation triggers when below ${provider.moistureThreshold.toInt()}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${(_tempThreshold ?? provider.moistureThreshold).toInt()}%',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Slider(
                        value: _tempThreshold ?? provider.moistureThreshold,
                        min: 10,
                        max: 70,
                        divisions: 60,
                        label: '${(_tempThreshold ?? provider.moistureThreshold).toInt()}%',
                        onChanged: (value) {
                          // Update temporary state for smooth dragging
                          setState(() {
                            _tempThreshold = value;
                          });
                        },
                        onChangeEnd: (value) async {
                          // Save to backend when user releases slider
                          setState(() {
                            _tempThreshold = null; // Clear temp value
                          });
                          await provider.updateMoistureThreshold(value);
                          _showSnackBar('Threshold updated to ${value.toInt()}%');
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info, size: 18, color: Color(0xFF3B82F6)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Current Moisture: ${provider.soilMoisture.toStringAsFixed(1)}%',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Data Management
              Card(
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
                              color: const Color(0xFFF59E0B).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.storage,
                              color: Color(0xFFF59E0B),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Data Management',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      _buildDataRow('Flow Rate History', '${provider.flowRateHistory.length} points'),
                      const SizedBox(height: 8),
                      _buildDataRow('Moisture History', '${provider.moistureHistory.length} points'),
                      const SizedBox(height: 8),
                      _buildDataRow('Temperature History', '${provider.temperatureHistory.length} points'),
                      const SizedBox(height: 8),
                      _buildDataRow('Water Usage History', '${provider.waterUsageHistory.length} points'),
                      const SizedBox(height: 16),
                      
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark 
                              ? const Color(0xFF334155)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 18),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Maximum 288 points per metric (24 hours at 5-min intervals)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      OutlinedButton.icon(
                        onPressed: _clearAllHistory,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Clear All History'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Display Preferences
              Card(
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
                              color: const Color(0xFF8B5CF6).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.palette,
                              color: Color(0xFF8B5CF6),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Display Preferences',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      Text(
                        'Application Theme',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: isDark ? const Color(0xFFCBD5E1) : Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Consumer<ThemeService>(
                        builder: (context, themeService, child) {
                          return DropdownButtonFormField<String>(
                            value: themeService.currentTheme,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'light',
                                child: Row(
                                  children: [
                                    Icon(Icons.light_mode, size: 18),
                                    SizedBox(width: 12),
                                    Text('Light'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'dark',
                                child: Row(
                                  children: [
                                    Icon(Icons.dark_mode, size: 18),
                                    SizedBox(width: 12),
                                    Text('Dark'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'auto',
                                child: Row(
                                  children: [
                                    Icon(Icons.brightness_auto, size: 18),
                                    SizedBox(width: 12),
                                    Text('Auto (System)'),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                themeService.setTheme(value);
                                _showSnackBar('Theme changed to: ${value == 'auto' ? 'System' : value}');
                              }
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // System Information
              Card(
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
                              color: const Color(0xFF0EA5E9).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.info,
                              color: Color(0xFF0EA5E9),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'System Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      _buildInfoRow('App Version:', '1.0.0'),
                      const SizedBox(height: 12),
                      _buildInfoRow('Device ID:', 'GROUP6_ESP32_01'),
                      const SizedBox(height: 12),
                      _buildInfoRow('Backend URL:', ApiService.baseUrl),
                      const SizedBox(height: 12),
                      _buildInfoRow('Data Points:', '${provider.flowRateHistory.length} collected'),
                      const SizedBox(height: 12),
                      _buildInfoRow('Last Update:', provider.lastPumpUpdate != null 
                          ? _formatTimestamp(provider.lastPumpUpdate!)
                          : 'Never'),
                      const SizedBox(height: 24),
                      
                      ElevatedButton.icon(
                        onPressed: _runDiagnostic,
                        icon: const Icon(Icons.troubleshoot, size: 18),
                        label: const Text('Run System Diagnostic'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // About
              Card(
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
                              Icons.water_drop,
                              color: Color(0xFF10B981),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'About AquaLink',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      _buildInfoRow('Project:', 'AquaLink Smart Irrigation'),
                      const SizedBox(height: 8),
                      _buildInfoRow('Group:', 'IFS325/353 Group 6'),
                      const SizedBox(height: 8),
                      _buildInfoRow('University:', 'University of the Western Cape'),
                      const SizedBox(height: 8),
                      _buildInfoRow('Year:', '2025'),
                      const SizedBox(height: 24),
                      
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          TextButton.icon(
                            onPressed: () => _showDocumentation(context),
                            icon: const Icon(Icons.description, size: 18),
                            label: const Text('Documentation'),
                          ),
                          TextButton.icon(
                            onPressed: () => _showAboutDialog(context),
                            icon: const Icon(Icons.help, size: 18),
                            label: const Text('Help & Support'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final theme = Theme.of(context);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium,
        ),
        Flexible(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
  
  Widget _buildDataRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF3B82F6),
          ),
        ),
      ],
    );
  }
  
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
  
  void _showDocumentation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Documentation'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quick Start Guide',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 12),
              _buildDocItem('1. Start Backend', 'cd backend && python backend_fastapi4.py'),
              _buildDocItem('2. Start Mock ESP32', 'cd backend && python mock_esp32.py'),
              _buildDocItem('3. Configure URLs', 'Use Quick Setup for network access'),
              _buildDocItem('4. Enable Automation', 'Set moisture threshold in Automation page'),
              _buildDocItem('5. Create Schedules', 'Add timed irrigation schedules'),
              const SizedBox(height: 16),
              const Text(
                'For detailed documentation, see the README files in the backend folder.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
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
  
  Widget _buildDocItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              description,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'AquaLink Smart Irrigation',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(
        Icons.water_drop,
        size: 48,
        color: Color(0xFF3B82F6),
      ),
      children: [
        const SizedBox(height: 16),
        const Text(
          'A smart irrigation system using ESP32, MQTT, and real-time sensor data for automated water management.',
        ),
        const SizedBox(height: 16),
        const Text(
          'Developed by IFS325/353 Group 6\nUniversity of the Western Cape\n2025',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
