import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/alert_service.dart';

class AppLayout extends StatelessWidget {
  final Widget child;

  const AppLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).uri.path;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0EA5E9),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            // AquaLink Logo
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: Image.asset(
                  'assets/AquaLink logo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 16),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'AquaLink',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'FS325/353 Irrigation System',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Consumer<AlertService>(
            builder: (context, alertService, child) {
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => context.go('/alerts'),
                  ),
                  if (alertService.unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        child: Text(
                          alertService.unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // Desktop sidebar
          if (MediaQuery.of(context).size.width >= 768)
            _DesktopSidebar(currentRoute: currentRoute),
          
          // Main content
          Expanded(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 24,
                  bottom: MediaQuery.of(context).size.width < 768 ? 80 : 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: child,
                ),
              ),
            ),
          ),
        ],
      ),
      // Mobile bottom navigation
      bottomNavigationBar: MediaQuery.of(context).size.width < 768
          ? _MobileBottomNav(currentRoute: currentRoute)
          : null,
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  final String currentRoute;

  const _DesktopSidebar({required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _NavItem(
            icon: Icons.home,
            label: 'Home',
            route: '/',
            isActive: currentRoute == '/',
            onTap: () => context.go('/'),
          ),
          _NavItem(
            icon: Icons.settings_suggest,
            label: 'Automation',
            route: '/automation',
            isActive: currentRoute == '/automation',
            onTap: () => context.go('/automation'),
          ),
          _NavItem(
            icon: Icons.calendar_today,
            label: 'Schedules',
            route: '/schedules',
            isActive: currentRoute == '/schedules',
            onTap: () => context.go('/schedules'),
          ),
          _NavItem(
            icon: Icons.bar_chart,
            label: 'Analytics',
            route: '/analytics',
            isActive: currentRoute == '/analytics',
            onTap: () => context.go('/analytics'),
          ),
          _NavItem(
            icon: Icons.notifications,
            label: 'Alerts',
            route: '/alerts',
            isActive: currentRoute == '/alerts',
            onTap: () => context.go('/alerts'),
          ),
          _NavItem(
            icon: Icons.settings,
            label: 'Settings',
            route: '/settings',
            isActive: currentRoute == '/settings',
            onTap: () => context.go('/settings'),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isActive ? theme.colorScheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isActive ? Colors.white : (isDark ? const Color(0xFFE2E8F0) : Colors.black87),
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isActive ? Colors.white : (isDark ? const Color(0xFFE2E8F0) : Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileBottomNav extends StatelessWidget {
  final String currentRoute;

  const _MobileBottomNav({required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : Colors.grey[300]!, 
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MobileNavItem(
                icon: Icons.home,
                label: 'Home',
                isActive: currentRoute == '/',
                onTap: () => context.go('/'),
              ),
              _MobileNavItem(
                icon: Icons.settings_suggest,
                label: 'Automation',
                isActive: currentRoute == '/automation',
                onTap: () => context.go('/automation'),
              ),
              _MobileNavItem(
                icon: Icons.calendar_today,
                label: 'Schedules',
                isActive: currentRoute == '/schedules',
                onTap: () => context.go('/schedules'),
              ),
              _MobileNavItem(
                icon: Icons.bar_chart,
                label: 'Analytics',
                isActive: currentRoute == '/analytics',
                onTap: () => context.go('/analytics'),
              ),
              _MobileNavItem(
                icon: Icons.notifications,
                label: 'Alerts',
                isActive: currentRoute == '/alerts',
                onTap: () => context.go('/alerts'),
              ),
              _MobileNavItem(
                icon: Icons.settings,
                label: 'Settings',
                isActive: currentRoute == '/settings',
                onTap: () => context.go('/settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _MobileNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 20,
            color: isActive 
                ? theme.colorScheme.primary 
                : (isDark ? const Color(0xFF94A3B8) : Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive 
                  ? theme.colorScheme.primary 
                  : (isDark ? const Color(0xFF94A3B8) : Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }
}

