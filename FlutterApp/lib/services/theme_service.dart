import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'selected_theme';
  
  String _currentTheme = 'light';
  
  String get currentTheme => _currentTheme;
  
  ThemeData get currentThemeData {
    switch (_currentTheme) {
      case 'dark':
        return AppTheme.darkTheme;
      case 'light':
      default:
        return AppTheme.lightTheme;
    }
  }
  
  ThemeService() {
    _loadTheme();
  }
  
  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentTheme = prefs.getString(_themeKey) ?? 'light';
      notifyListeners();
    } catch (e) {
      // If there's an error, default to light theme
      _currentTheme = 'light';
    }
  }
  
  Future<void> setTheme(String theme) async {
    if (_currentTheme != theme) {
      _currentTheme = theme;
      notifyListeners();
      
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_themeKey, theme);
      } catch (e) {
        // Handle error silently
      }
    }
  }
  
  bool get isDarkMode => _currentTheme == 'dark';
  bool get isLightMode => _currentTheme == 'light';
  bool get isAutoMode => _currentTheme == 'auto';
}
