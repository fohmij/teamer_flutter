import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:teamer/database/database_services.dart';

class WeeklyReminder {
  final int id;
  final String name;
  final int weekday;
  final int hour;
  final int minute;
  final bool playSound;
  final bool enableVibration;

  const WeeklyReminder({
    required this.id,
    required this.name,
    required this.weekday,
    required this.hour,
    required this.minute,
    this.playSound = true,
    this.enableVibration = true,
  });

  WeeklyReminder copyWith({
    int? id,
    String? name,
    int? weekday,
    int? hour,
    int? minute,
    bool? playSound,
    bool? enableVibration,
  }) {
    return WeeklyReminder(
      id: id ?? this.id,
      name: name ?? this.name,
      weekday: weekday ?? this.weekday,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      playSound: playSound ?? this.playSound,
      enableVibration: enableVibration ?? this.enableVibration,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'weekday': weekday,
      'hour': hour,
      'minute': minute,
      'playSound': playSound,
      'enableVibration': enableVibration,
    };
  }

  factory WeeklyReminder.fromJson(Map<String, dynamic> json) {
    return WeeklyReminder(
      id: (json['id'] as num).toInt(),
      name: json['name'].toString(),
      weekday: (json['weekday'] as num).toInt().clamp(1, 7).toInt(),
      hour: (json['hour'] as num).toInt().clamp(0, 23).toInt(),
      minute: (json['minute'] as num).toInt().clamp(0, 59).toInt(),
      // Alte gespeicherte Reminder hatten diese Felder noch nicht.
      // Deshalb bleiben Ton und Vibration dort standardmäßig aktiviert.
      playSound: json['playSound'] is bool ? json['playSound'] as bool : true,
      enableVibration: json['enableVibration'] is bool
          ? json['enableVibration'] as bool
          : true,
    );
  }
}

class AppSettings {
  final String themeMode;
  final int minGamesForFullWeight;
  final String whatsAppGroupLink;
  final List<String> blockedWords;
  final List<WeeklyReminder> weeklyReminders;

  const AppSettings({
    required this.themeMode,
    required this.minGamesForFullWeight,
    required this.whatsAppGroupLink,
    required this.blockedWords,
    required this.weeklyReminders,
  });

  static const defaults = AppSettings(
    themeMode: 'system',
    minGamesForFullWeight: 5,
    whatsAppGroupLink: '',
    blockedWords: ['ich', 'nicht', 'da', 'stimmabgaben'],
    weeklyReminders: [],
  );

  AppSettings copyWith({
    String? themeMode,
    int? minGamesForFullWeight,
    String? whatsAppGroupLink,
    List<String>? blockedWords,
    List<WeeklyReminder>? weeklyReminders,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      minGamesForFullWeight:
          minGamesForFullWeight ?? this.minGamesForFullWeight,
      whatsAppGroupLink: whatsAppGroupLink ?? this.whatsAppGroupLink,
      blockedWords: blockedWords ?? this.blockedWords,
      weeklyReminders: weeklyReminders ?? this.weeklyReminders,
    );
  }
}

class AppSettingsService {
  static final AppSettingsService instance = AppSettingsService._constructor();

  AppSettingsService._constructor();

  static const String _settingsTableName = 'app_settings';
  static const String _settingsKeyColumnName = 'key';
  static const String _settingsValueColumnName = 'value';

  Future<Database> get _database => DatabaseService.instance.database;

  Future<void> ensureSettingsTable() async {
    final db = await _database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_settingsTableName(
        $_settingsKeyColumnName TEXT PRIMARY KEY,
        $_settingsValueColumnName TEXT NOT NULL
      )
    ''');
  }

  Future<AppSettings> getSettings() async {
    await ensureSettingsTable();

    final themeMode =
        await _getString('themeMode') ?? AppSettings.defaults.themeMode;
    final minGames = await _getInt('minGamesForFullWeight') ??
        AppSettings.defaults.minGamesForFullWeight;
    final whatsAppGroupLink = await _getString('whatsAppGroupLink') ??
        AppSettings.defaults.whatsAppGroupLink;
    final blockedWordsRaw = await _getString('blockedWords');
    final remindersRaw = await _getString('weeklyReminders');

    return AppSettings(
      themeMode: themeMode,
      minGamesForFullWeight: minGames,
      whatsAppGroupLink: whatsAppGroupLink,
      blockedWords: _decodeBlockedWords(blockedWordsRaw),
      weeklyReminders: _decodeWeeklyReminders(remindersRaw),
    );
  }

  Future<void> updateThemeMode(String themeMode) async {
    await _setString('themeMode', themeMode);
  }

  Future<void> updateMinGamesForFullWeight(int value) async {
    await _setString('minGamesForFullWeight', value.clamp(0, 999).toString());
  }

  Future<void> updateWhatsAppGroupLink(String value) async {
    await _setString('whatsAppGroupLink', value.trim());
  }

  Future<void> updateBlockedWords(List<String> blockedWords) async {
    final cleanedWords = _cleanBlockedWords(blockedWords);
    await _setString('blockedWords', jsonEncode(cleanedWords));
  }

  Future<void> updateWeeklyReminders(List<WeeklyReminder> reminders) async {
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

    await _setString(
      'weeklyReminders',
      jsonEncode(sortedReminders.map((reminder) => reminder.toJson()).toList()),
    );
  }

  List<String> _decodeBlockedWords(String? rawValue) {
    if (rawValue == null) {
      return List<String>.from(AppSettings.defaults.blockedWords);
    }

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! List) {
        return List<String>.from(AppSettings.defaults.blockedWords);
      }

      return _cleanBlockedWords(decoded.map((value) => value.toString()));
    } catch (_) {
      return List<String>.from(AppSettings.defaults.blockedWords);
    }
  }

  List<WeeklyReminder> _decodeWeeklyReminders(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! List) return const [];

      final reminders = <WeeklyReminder>[];
      final usedIds = <int>{};

      for (final value in decoded) {
        if (value is! Map) continue;

        try {
          final reminder = WeeklyReminder.fromJson(
            Map<String, dynamic>.from(value),
          );

          if (reminder.name.trim().isEmpty || !usedIds.add(reminder.id)) {
            continue;
          }

          reminders.add(reminder);
        } catch (_) {
          // Ungültige einzelne Einträge werden übersprungen.
        }
      }

      reminders.sort((a, b) {
        final weekdayCompare = a.weekday.compareTo(b.weekday);
        if (weekdayCompare != 0) return weekdayCompare;

        final hourCompare = a.hour.compareTo(b.hour);
        if (hourCompare != 0) return hourCompare;

        final minuteCompare = a.minute.compareTo(b.minute);
        if (minuteCompare != 0) return minuteCompare;

        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      return reminders;
    } catch (_) {
      return const [];
    }
  }

  List<String> _cleanBlockedWords(Iterable<String> blockedWords) {
    final cleanedWords = <String>[];
    final normalizedWords = <String>{};

    for (final word in blockedWords) {
      final cleanedWord = word.trim();
      if (cleanedWord.isEmpty) continue;

      final normalizedWord = cleanedWord.toLowerCase();
      if (!normalizedWords.add(normalizedWord)) continue;

      cleanedWords.add(cleanedWord);
    }

    return cleanedWords;
  }

  Future<String?> _getString(String key) async {
    final db = await _database;
    final result = await db.query(
      _settingsTableName,
      columns: [_settingsValueColumnName],
      where: '$_settingsKeyColumnName = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return result.first[_settingsValueColumnName] as String?;
  }

  Future<int?> _getInt(String key) async {
    final value = await _getString(key);
    if (value == null) return null;
    return int.tryParse(value);
  }

  Future<void> _setString(String key, String value) async {
    await ensureSettingsTable();
    final db = await _database;
    await db.insert(
      _settingsTableName,
      {
        _settingsKeyColumnName: key,
        _settingsValueColumnName: value,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
