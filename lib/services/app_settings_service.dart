import 'package:sqflite/sqflite.dart';
import 'package:teamer/database/database_services.dart';

class AppSettings {
  final String themeMode;
  final int minGamesForFullWeight;

  const AppSettings({
    required this.themeMode,
    required this.minGamesForFullWeight,
  });

  static const defaults = AppSettings(
    themeMode: 'system',
    minGamesForFullWeight: 5,
  );

  AppSettings copyWith({
    String? themeMode,
    int? minGamesForFullWeight,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      minGamesForFullWeight:
          minGamesForFullWeight ?? this.minGamesForFullWeight,
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
    final themeMode = await _getString('themeMode') ?? AppSettings.defaults.themeMode;
    final minGames = await _getInt('minGamesForFullWeight') ??
        AppSettings.defaults.minGamesForFullWeight;

    return AppSettings(
      themeMode: themeMode,
      minGamesForFullWeight: minGames,
    );
  }

  Future<void> updateThemeMode(String themeMode) async {
    await _setString('themeMode', themeMode);
  }

  Future<void> updateMinGamesForFullWeight(int value) async {
    await _setString('minGamesForFullWeight', value.clamp(0, 999).toString());
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
