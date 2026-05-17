import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

const _kNotificationsKey = 'notifications_enabled';

class NotificationsPrefNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return true;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_kNotificationsKey) ?? true;
  }

  Future<void> toggle() async {
    final next = !state;
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotificationsKey, next);
    if (next) {
      await NotificationService.instance.requestPermissions();
    }
  }
}

final notificationsEnabledProvider =
    NotifierProvider<NotificationsPrefNotifier, bool>(NotificationsPrefNotifier.new);
