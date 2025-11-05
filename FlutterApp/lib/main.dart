import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'pages/dashboard_page.dart';
import 'pages/automation_page.dart';
import 'pages/analytics_page.dart';
import 'pages/schedules_page.dart';
import 'pages/alerts_page.dart';
import 'pages/settings_page.dart';
import 'pages/not_found_page.dart';
import 'widgets/layout.dart';
import 'services/alert_service.dart';
import 'services/theme_service.dart';
import 'services/platform_config.dart';
import 'providers/irrigation_provider.dart';
import 'providers/schedule_provider.dart';

void main() {
  // Initialize platform-specific configuration (API and WebSocket URLs)
  // When running on a physical device, pass your laptop/desktop IP via --dart-define:
  // flutter run --dart-define=BACKEND_HOST=172.30.68.74

  const backendHost = String.fromEnvironment('BACKEND_HOST', defaultValue: '');

  if (backendHost.isNotEmpty) {
    PlatformConfig.initializeForPhysicalDevice(backendHost);
  } else {
    PlatformConfig.initialize();
  }

  runApp(const AquaLinkApp());
}

class AquaLinkApp extends StatelessWidget {
  const AquaLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AlertService()),
        ChangeNotifierProvider(create: (context) => ThemeService()),
        ChangeNotifierProvider(create: (context) => IrrigationProvider()..initialize()),
        ChangeNotifierProvider(create: (context) => ScheduleProvider()),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          return MaterialApp.router(
            title: 'AquaLink - Smart Irrigation',
            theme: themeService.currentThemeData,
            debugShowCheckedModeBanner: false,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}

final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return AppLayout(child: child);
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const DashboardPage(),
        ),
        GoRoute(
          path: '/automation',
          builder: (context, state) => const AutomationPage(),
        ),
        GoRoute(
          path: '/schedules',
          builder: (context, state) => const SchedulesPage(),
        ),
        GoRoute(
          path: '/analytics',
          builder: (context, state) => const AnalyticsPage(),
        ),
        GoRoute(
          path: '/alerts',
          builder: (context, state) => const AlertsPage(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) => const NotFoundPage(),
);

