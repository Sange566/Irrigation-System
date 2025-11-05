import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/alert_service.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> with AutomaticKeepAliveClientMixin {
  bool lowFlowAlerts = true;
  bool maintenanceReminders = true;
  bool systemStatusUpdates = true;
  
  List<ActionHistoryItem> actionHistory = [];
  bool isLoadingHistory = false;
  String? historyError;
  
  List<AlertItem> alerts = [];
  bool isLoadingAlerts = false;

  @override
  bool get wantKeepAlive => true;
  
  @override
  void initState() {
    super.initState();
    _loadAlerts();
    _loadActionHistory();
  }
  
  Future<void> _loadAlerts() async {
    setState(() {
      isLoadingAlerts = true;
    });
    
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/alerts?limit=20'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final alertsList = data['alerts'] as List<dynamic>;
        
        setState(() {
          alerts = alertsList.map((alert) {
            return AlertItem(
              type: _parseAlertType(alert['type']),
              title: alert['title'] ?? 'Alert',
              timestamp: _formatTimestampForAlert(alert['timestamp']),
              isRead: alert['isRead'] ?? false,
            );
          }).toList();
          isLoadingAlerts = false;
        });
      }
    } catch (e) {
      print('Error loading alerts: $e');
      setState(() {
        // Use default alerts if API fails
        alerts = [
          AlertItem(
            type: AlertType.info,
            title: 'System ready',
            timestamp: DateFormat('yyyy/MM/dd, HH:mm:ss').format(DateTime.now()),
            isRead: true,
          ),
        ];
        isLoadingAlerts = false;
      });
    }
  }
  
  AlertType _parseAlertType(String type) {
    switch (type.toLowerCase()) {
      case 'warning':
        return AlertType.warning;
      case 'success':
        return AlertType.success;
      default:
        return AlertType.info;
    }
  }
  
  String _formatTimestampForAlert(String isoTimestamp) {
    try {
      final dateTime = DateTime.parse(isoTimestamp);
      return DateFormat('yyyy/MM/dd, HH:mm:ss').format(dateTime);
    } catch (e) {
      return isoTimestamp;
    }
  }
  
  Future<void> _loadActionHistory() async {
    setState(() {
      isLoadingHistory = true;
      historyError = null;
    });
    
    try {
      final response = await ApiService.getActionHistory(limit: 50);
      final actions = response['actions'] as List<dynamic>;
      
      setState(() {
        actionHistory = actions.map((action) => ActionHistoryItem.fromJson(action)).toList();
        isLoadingHistory = false;
      });
    } catch (e) {
      setState(() {
        historyError = e.toString();
        isLoadingHistory = false;
      });
      print('Error loading action history: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final unreadCount = alerts.where((alert) => !alert.isRead).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Page Title and Actions
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Alerts',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Row(
              children: [
                if (unreadCount > 0)
                  TextButton(
                    onPressed: () => _showMarkAsReadOptions(context),
                    child: const Text('Mark all as read'),
                  ),
                IconButton(
                  onPressed: () {
                    _loadAlerts();
                    _loadActionHistory();
                  },
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh alerts',
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Alerts List
        _buildAlertsList(context),
        const SizedBox(height: 24),

        // Notification Settings
        _buildNotificationSettings(context),
        const SizedBox(height: 24),

        // Alert History
        _buildAlertHistory(context),
      ],
    );
  }

  Widget _buildAlertsList(BuildContext context) {
    return Card(
      child: Column(
        children: alerts.map((alert) => _buildAlertItem(context, alert)).toList(),
      ),
    );
  }

  Widget _buildAlertItem(BuildContext context, AlertItem alert) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    Color backgroundColor;
    Color iconColor;
    IconData iconData;

    switch (alert.type) {
      case AlertType.warning:
        backgroundColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF0F9FF);
        iconColor = const Color(0xFFF59E0B);
        iconData = Icons.warning_amber_outlined;
        break;
      case AlertType.info:
        backgroundColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF0F9FF);
        iconColor = const Color(0xFF0EA5E9);
        iconData = Icons.info_outline;
        break;
      case AlertType.success:
        backgroundColor = isDark ? const Color(0xFF1E293B) : Colors.white;
        iconColor = const Color(0xFF10B981);
        iconData = Icons.check_circle_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: backgroundColor,
            ),
            child: Icon(
              iconData,
              color: iconColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  alert.timestamp,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFFCBD5E1) : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          if (!alert.isRead)
            TextButton(
              onPressed: () => _markAsRead(alert),
              child: Text(
                'Mark as read',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationSettings(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notification Settings',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),

            _buildNotificationSetting(
              'Low Flow Rate Alerts',
              'Get notified when flow rate drops below threshold',
              lowFlowAlerts,
              (value) {
                setState(() {
                  lowFlowAlerts = value;
                });
              },
            ),
            const SizedBox(height: 20),

            _buildNotificationSetting(
              'Maintenance Reminders',
              'Receive periodic maintenance notifications',
              maintenanceReminders,
              (value) {
                setState(() {
                  maintenanceReminders = value;
                });
              },
            ),
            const SizedBox(height: 20),

            _buildNotificationSetting(
              'System Status Updates',
              'Get notified about system status changes',
              systemStatusUpdates,
              (value) {
                setState(() {
                  systemStatusUpdates = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSetting(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildAlertHistory(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
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
                      Icons.history,
                      color: Color(0xFF3B82F6),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Pump Action History',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                if (!isLoadingHistory)
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadActionHistory,
                    tooltip: 'Refresh history',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Complete record of all pump actions (manual, automation, and scheduled)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 16),
            if (isLoadingHistory)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (historyError != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 8),
                      Text(
                        'Failed to load history',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        historyError!,
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadActionHistory,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (actionHistory.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.history,
                        size: 48,
                        color: isDark ? const Color(0xFF4B5563) : const Color(0xFF9CA3AF),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No action history yet',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Actions will appear here when the pump is controlled',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: actionHistory.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final action = actionHistory[index];
                  return _buildActionHistoryItem(action, isDark);
                },
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActionHistoryItem(ActionHistoryItem action, bool isDark) {
    IconData icon;
    Color iconColor;
    Color backgroundColor;
    
    // Determine icon and color based on action type and trigger
    if (action.action == 'ON') {
      icon = Icons.power;
      iconColor = const Color(0xFF10B981); // Green
      backgroundColor = const Color(0xFFECFDF5);
    } else {
      icon = Icons.power_off;
      iconColor = const Color(0xFFEF4444); // Red
      backgroundColor = const Color(0xFFFEF2F2);
    }
    
    // Get trigger icon
    IconData triggerIcon;
    String triggerLabel;
    switch (action.trigger) {
      case 'manual':
        triggerIcon = Icons.touch_app;
        triggerLabel = 'Manual';
        break;
      case 'automation':
        triggerIcon = Icons.settings_suggest;
        triggerLabel = 'Automation';
        break;
      case 'schedule':
        triggerIcon = Icons.schedule;
        triggerLabel = 'Schedule';
        break;
      default:
        triggerIcon = Icons.info;
        triggerLabel = action.trigger;
    }
    
    // Format the details
    String detailsText = '';
    if (action.details != null) {
      if (action.trigger == 'automation') {
        final moisture = action.details!['moisture'];
        final threshold = action.details!['threshold'];
        if (moisture != null && threshold != null) {
          detailsText = 'Moisture: $moisture% ≤ $threshold%';
        }
      } else if (action.trigger == 'schedule') {
        final scheduleInfo = action.details!['schedule_info'];
        final duration = action.details!['duration'];
        if (scheduleInfo != null) {
          detailsText = scheduleInfo;
        } else if (duration != null) {
          detailsText = 'Duration: $duration min';
        }
      }
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : backgroundColor.withOpacity(0.3),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Pump ${action.action}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(triggerIcon, size: 12, color: const Color(0xFF3B82F6)),
                          const SizedBox(width: 4),
                          Text(
                            triggerLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF3B82F6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTimestamp(action.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                ),
                if (detailsText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    detailsText,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatTimestamp(String isoTimestamp) {
    try {
      final dateTime = DateTime.parse(isoTimestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes} min ago';
      } else if (difference.inDays < 1) {
        return DateFormat('HH:mm').format(dateTime);
      } else if (difference.inDays < 7) {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else {
        return DateFormat('MMM d, HH:mm').format(dateTime);
      }
    } catch (e) {
      return isoTimestamp;
    }
  }

  void _markAsRead(AlertItem alert) {
    if (mounted) {
      setState(() {
        alert.isRead = true;
      });
      // Update the alert service
      Provider.of<AlertService>(context, listen: false).markAsRead();
    }
  }

  void _showMarkAsReadOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Mark Alerts as Read'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Mark all alerts as read'),
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() {
                    for (var alert in alerts) {
                      alert.isRead = true;
                    }
                  });
                  Provider.of<AlertService>(context, listen: false).markAllAsRead();
                  _showSnackBar(context, 'All alerts marked as read');
                },
              ),
              ListTile(
                title: const Text('Mark only warning alerts as read'),
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() {
                    for (var alert in alerts) {
                      if (alert.type == AlertType.warning) {
                        alert.isRead = true;
                      }
                    }
                  });
                  Provider.of<AlertService>(context, listen: false).updateUnreadCount(
                    alerts.where((alert) => !alert.isRead).length
                  );
                  _showSnackBar(context, 'Warning alerts marked as read');
                },
              ),
              ListTile(
                title: const Text('Mark only info alerts as read'),
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() {
                    for (var alert in alerts) {
                      if (alert.type == AlertType.info) {
                        alert.isRead = true;
                      }
                    }
                  });
                  Provider.of<AlertService>(context, listen: false).updateUnreadCount(
                    alerts.where((alert) => !alert.isRead).length
                  );
                  _showSnackBar(context, 'Info alerts marked as read');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF0EA5E9),
      ),
    );
  }
}

class AlertItem {
  final AlertType type;
  final String title;
  final String timestamp;
  bool isRead;

  AlertItem({
    required this.type,
    required this.title,
    required this.timestamp,
    required this.isRead,
  });
}

enum AlertType {
  warning,
  info,
  success,
}

class ActionHistoryItem {
  final String timestamp;
  final String action;
  final String trigger;
  final Map<String, dynamic>? details;

  ActionHistoryItem({
    required this.timestamp,
    required this.action,
    required this.trigger,
    this.details,
  });

  factory ActionHistoryItem.fromJson(Map<String, dynamic> json) {
    return ActionHistoryItem(
      timestamp: json['timestamp'] as String,
      action: json['action'] as String,
      trigger: json['trigger'] as String,
      details: json['details'] as Map<String, dynamic>?,
    );
  }
}

