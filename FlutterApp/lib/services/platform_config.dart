import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'api_service.dart';
import 'websocket_service.dart';

/// Platform-aware configuration for API and WebSocket URLs
class PlatformConfig {
  /// Initialize platform-specific URLs
  /// 
  /// For Web: Uses localhost
  /// For Android Emulator: Uses 10.0.2.2 (special alias to host machine)
  /// For Physical Device: You need to provide your computer's IP address
  /// 
  /// Example for physical device:
  /// ```dart
  /// PlatformConfig.initialize(physicalDeviceIp: '192.168.1.100');
  /// ```
  static void initialize({String? physicalDeviceIp}) {
    String apiUrl;
    String wsUrl;

    if (kIsWeb) {
      // Web: Use localhost (backend and Flutter running on same machine)
      apiUrl = 'http://localhost:8000';
      wsUrl = 'ws://localhost:8000/ws';
      print('[CONFIG] Platform: Web');
      print('[CONFIG] Using localhost for API and WebSocket');
    } else if (Platform.isAndroid) {
      if (physicalDeviceIp != null && physicalDeviceIp.isNotEmpty) {
        // Physical Android device with provided IP
        apiUrl = 'http://$physicalDeviceIp:8000';
        wsUrl = 'ws://$physicalDeviceIp:8000/ws';
        print('[CONFIG] Platform: Android (Physical Device)');
        print('[CONFIG] Using IP: $physicalDeviceIp');
      } else {
        // Android emulator: Use 10.0.2.2 (special alias to host)
        apiUrl = 'http://10.0.2.2:8000';
        wsUrl = 'ws://10.0.2.2:8000/ws';
        print('[CONFIG] Platform: Android Emulator');
        print('[CONFIG] Using 10.0.2.2 (host machine alias)');
        print('[CONFIG][WARN] To connect a physical Android device, run with --dart-define=BACKEND_HOST=<laptop-ip>');
      }
    } else if (Platform.isIOS) {
      if (physicalDeviceIp != null && physicalDeviceIp.isNotEmpty) {
        // Physical iOS device with provided IP
        apiUrl = 'http://$physicalDeviceIp:8000';
        wsUrl = 'ws://$physicalDeviceIp:8000/ws';
        print('[CONFIG] Platform: iOS (Physical Device)');
        print('[CONFIG] Using IP: $physicalDeviceIp');
      } else {
        // iOS simulator can use localhost
        apiUrl = 'http://localhost:8000';
        wsUrl = 'ws://localhost:8000/ws';
        print('[CONFIG] Platform: iOS Simulator');
        print('[CONFIG] Using localhost');
      }
    } else {
      // Desktop (Windows, macOS, Linux): Use localhost
      apiUrl = 'http://localhost:8000';
      wsUrl = 'ws://localhost:8000/ws';
      print('[CONFIG] Platform: Desktop');
      print('[CONFIG] Using localhost');
    }

    // Set the URLs in the services
    ApiService.setBaseUrl(apiUrl);
    WebSocketService.setServerUrl(wsUrl);

    print('[CONFIG] API URL: $apiUrl');
    print('[CONFIG] WebSocket URL: $wsUrl');
    print('[CONFIG] ✓ Configuration complete');
  }

  /// Quick setup for physical device testing
  /// Call this with your computer's IP address when testing on a physical device
  /// 
  /// To find your IP:
  /// - Windows: Run `ipconfig` and look for IPv4 Address
  /// - Mac/Linux: Run `ifconfig` or `ip addr`
  /// 
  /// Example:
  /// ```dart
  /// PlatformConfig.initializeForPhysicalDevice('192.168.1.100');
  /// ```
  static void initializeForPhysicalDevice(String ipAddress) {
    initialize(physicalDeviceIp: ipAddress);
  }
}

