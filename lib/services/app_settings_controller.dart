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

  Future<void> setWhatsAppGroupLink(String groupLink) async {
    final trimmedLink = groupLink.trim();
    await _settingsService.updateWhatsAppGroupLink(trimmedLink);
    value = value.copyWith(whatsAppGroupLink: trimmedLink);
  }

  Future<void> setBlockedWords(List<String> blockedWords) async {
    final cleanedWords = <String>[];
    final normalizedWords = <String>{};

    for (final word in blockedWords) {
      final cleanedWord = word.trim();
      if (cleanedWord.isEmpty) continue;

      final normalizedWord = cleanedWord.toLowerCase();
      if (!normalizedWords.add(normalizedWord)) continue;

      cleanedWords.add(cleanedWord);
    }

    await _settingsService.updateBlockedWords(cleanedWords);
    value = value.copyWith(blockedWords: cleanedWords);
  }

  Future<WeeklyReminder> addWeeklyReminder({
    required String name,
    required int weekday,
    required int hour,
    required int minute,
    bool playSound = true,
    bool enableVibration = true,
  }) async {
    final reminder = WeeklyReminder(
      id: _nextReminderId(),
      name: name.trim(),
      weekday: weekday.clamp(1, 7).toInt(),
      hour: hour.clamp(0, 23).toInt(),
      minute: minute.clamp(0, 59).toInt(),
      playSound: playSound,
      enableVibration: enableVibration,
    );

    final reminders = [...value.weeklyReminders, reminder];
    await _saveWeeklyReminders(reminders);
    return reminder;
  }

  Future<void> updateWeeklyReminder(WeeklyReminder reminder) async {
    final updatedReminder = reminder.copyWith(name: reminder.name.trim());
    final reminders = value.weeklyReminders
        .map((item) => item.id == reminder.id ? updatedReminder : item)
        .toList();

    await _saveWeeklyReminders(reminders);
  }

  Future<void> removeWeeklyReminder(int reminderId) async {
    final reminders = value.weeklyReminders
        .where((reminder) => reminder.id != reminderId)
        .toList();

    await _saveWeeklyReminders(reminders);
  }

  Future<void> _saveWeeklyReminders(List<WeeklyReminder> reminders) async {
    final sortedReminders = List<WeeklyReminder>.from(reminders)
      ..sort((a, b) {
        final weekdayCompare = a.weekday.compareTo(b.weekday);
        if (weekdayCompare != 0) return weekdayCompare;

        final hourCompare = a.hour.compareTo(b.hour);
        if (hourCompare != 0) return hourCompare;

        final minuteCompare = a.minute.compareTo(b.minute);
        if (minuteCompare != 0) return minuteCompare;

        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    await _settingsService.updateWeeklyReminders(sortedReminders);
    value = value.copyWith(weeklyReminders: sortedReminders);
  }

  int _nextReminderId() {
    const firstReminderId = 10000;

    if (value.weeklyReminders.isEmpty) return firstReminderId;

    final highestId = value.weeklyReminders
        .map((reminder) => reminder.id)
        .reduce((a, b) => a > b ? a : b);

    return highestId + 1;
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
