import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  const AppSettings({this.deliveryApproachNotifyMinutes = 5});

  final int deliveryApproachNotifyMinutes;

  AppSettings copyWith({int? deliveryApproachNotifyMinutes}) {
    return AppSettings(
      deliveryApproachNotifyMinutes:
          deliveryApproachNotifyMinutes ?? this.deliveryApproachNotifyMinutes,
    );
  }
}

class AppSettingsNotifier extends Notifier<AppSettings> {
  static const _key = 'app_settings_approach_minutes_v1';

  @override
  AppSettings build() {
    Future.microtask(_load);
    return const AppSettings();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final minutes = prefs.getInt(_key);
    if (minutes != null) {
      state = state.copyWith(deliveryApproachNotifyMinutes: minutes);
    }
  }

  Future<void> setApproachMinutes(int minutes) async {
    final clamped = minutes.clamp(1, 30);
    state = state.copyWith(deliveryApproachNotifyMinutes: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, clamped);
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);
