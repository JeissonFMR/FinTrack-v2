import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kAutoRegisterKey = 'auto_register_enabled';

class AutoRegisterPrefNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return true; // Default: ON
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(kAutoRegisterKey) ?? true;
  }

  Future<void> toggle() async {
    final next = !state;
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kAutoRegisterKey, next);
  }
}

final autoRegisterEnabledProvider =
    NotifierProvider<AutoRegisterPrefNotifier, bool>(AutoRegisterPrefNotifier.new);
