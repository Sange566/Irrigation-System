import 'package:flutter/material.dart';

class AlertService extends ChangeNotifier {
  static final AlertService _instance = AlertService._internal();
  factory AlertService() => _instance;
  AlertService._internal();

  int _unreadCount = 2; // Default unread count

  int get unreadCount => _unreadCount;

  void updateUnreadCount(int count) {
    _unreadCount = count;
    notifyListeners();
  }

  void markAsRead() {
    if (_unreadCount > 0) {
      _unreadCount--;
      notifyListeners();
    }
  }

  void markAllAsRead() {
    _unreadCount = 0;
    notifyListeners();
  }
}
