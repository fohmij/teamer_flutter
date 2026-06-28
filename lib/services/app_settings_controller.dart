import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:teamer/services/app_settings_service.dart';

class AppSettingsController extends ValueNotifier<AppSettings> {
  AppSettingsController() : super(AppSettings.defaults);

  final AppSettingsService _settingsService = AppSettingsService.instance;

  Future<void> load() async {
    value = await _settingsService.getSettings();
  }

  Future<void> setThemeMode(String themeMode) async {
    await _settingsService.updateThemeMode(themeMode);
    value = value.copyWith(themeMode: themeMode);
  }

  Future<void> setMinGamesForFullWeight(int minGames) async {
    await _settingsService.updateMinGamesForFullWeight(minGames);
    value = value.copyWith(minGamesForFullWeight: minGames);
  }

  ThemeMode get flutterThemeMode {
    switch (value.themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}

final appSettingsController = AppSettingsController();
