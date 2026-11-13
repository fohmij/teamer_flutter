// VERSION 2026-11-13 (EXPORT/IMPORT): Portable Komplett-Backups, alte Statistik-Backups bleiben lesbar.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:teamer/database/database_services.dart';
import 'package:teamer/services/app_settings_service.dart';

enum StatsBackupKind { manual, automatic, beforeRestore }

class StatsBackup {
  final String fileName;
  final DateTime createdAt;
  final StatsBackupKind kind;
  final int playerCount;
  final int gameCount;
  final int formatVersion;

  const StatsBackup({
    required this.fileName,
    required this.createdAt,
    required this.kind,
    required this.playerCount,
    required this.gameCount,
    this.formatVersion = 1,
  });

  bool get includesAppData => formatVersion >= 2;

  String get typeLabel {
    switch (kind) {
      case StatsBackupKind.manual:
        return 'Manuell';
      case StatsBackupKind.automatic:
        return 'Automatisch';
      case StatsBackupKind.beforeRestore:
        return 'Vor Wiederherstellung';
    }
  }
}

class StatsBackupService {
  StatsBackupService._();

  static final StatsBackupService instance = StatsBackupService._();

  static const int _formatVersion = 2;
  static const int _maxAutomaticBackups = 12;
  static const int _maxEventImageBytes = 20 * 1024 * 1024;
  static final RegExp _backupFilePattern = RegExp(
    r'^(manual|automatic|before_restore)_[0-9_]+\.json$',
  );

  static const List<String> _playerColumns = [
    'id', 'name', 'status', 'position', 'team',
    'winRate', 'wins', 'losses', 'attendance',
  ];
  static const List<String> _gameColumns = [
    'id', 'name', 'teamA', 'teamB', 'teamBWon',
  ];
  static const List<String> _eventColumns = [
    'id', 'title', 'imagePath', 'markdownText', 'link',
  ];
  static const List<String> _settingColumns = ['key', 'value'];
  static const Set<String> _allowedImageExtensions = {
    '.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp',
    '.heic', '.heif', '.avif',
  };

  // Backups und Wiederherstellungen dürfen nicht gleichzeitig laufen.
  Future<void> _previousOperation = Future<void>.value();

  Future<T> _exclusive<T>(Future<T> Function() operation) async {
    final previous = _previousOperation;
    final completed = Completer<void>();
    _previousOperation = completed.future;
    await previous;
    try {
      return await operation();
    } finally {
      completed.complete();
    }
  }

  Future<Directory> _backupDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(documents.path, 'stats_backups'));
    await directory.create(recursive: true);
    return directory;
  }

  Future<_BackupSnapshot> _readCurrentData() async {
    // Diese Tabellen werden in älteren Installationen erst bei Bedarf erstellt.
    await AppSettingsService.instance.ensureSettingsTable();
    await DatabaseService.instance.getEventData();

    final db = await DatabaseService.instance.database;
    final snapshot = await db.transaction((txn) async {
      final players = await txn.query('player', orderBy: 'id');
      final games = await txn.query('games', orderBy: 'id');
      final settings = await txn.query('app_settings', orderBy: 'key');
      final events = await txn.query('event_data', orderBy: 'id');
      return _BackupSnapshot(
        formatVersion: _formatVersion,
        players: players.map((r) => Map<String, Object?>.from(r)).toList(),
        games: games.map((r) => Map<String, Object?>.from(r)).toList(),
        settings: settings.map((r) => Map<String, Object?>.from(r)).toList(),
        event: events.isEmpty ? null : Map<String, Object?>.from(events.first),
      );
    });

    final event = snapshot.event;
    if (event == null) {
      throw const FormatException('Eventdaten konnten nicht gesichert werden.');
    }
    final imagePath = event['imagePath'] as String;
    if (!imagePath.startsWith('assets/')) {
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw FileSystemException('Das Eventbild fehlt und kann nicht gesichert werden.', imagePath);
      }
      if (await imageFile.length() > _maxEventImageBytes) {
        throw const FormatException('Das Eventbild ist für ein Backup zu groß (max. 20 MB).');
      }
      final extension = p.extension(imagePath).toLowerCase();
      if (!_allowedImageExtensions.contains(extension)) {
        throw const FormatException('Das Eventbild hat ein nicht unterstütztes Dateiformat.');
      }
      final bytes = await imageFile.readAsBytes();
      snapshot.eventImage = {'extension': extension, 'base64': base64Encode(bytes)};
      // Geräteabhängige absolute Pfade dürfen NICHT im Backup stehen.
      event['imagePath'] = 'backup:event_image';
    }
    return snapshot;
  }

  Future<StatsBackup> createManualBackup() => _exclusive(() async {
    final snapshot = await _readCurrentData();
    return _writeBackup(snapshot, StatsBackupKind.manual);
  });

  /// Maximal eine automatische Sicherung pro Monat beim App-Start.
  Future<StatsBackup?> createMonthlyBackupIfNeeded() => _exclusive(() async {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final fileName = 'automatic_${now.year}_$month.json';
    final directory = await _backupDirectory();
    final monthlyFile = File(p.join(directory.path, fileName));

    if (await monthlyFile.exists()) {
      try {
        await _readAndValidateBackup(monthlyFile);
        return null;
      } catch (_) {
        // Defekte Sicherung aufheben, aber nicht als gültige Monatskopie zählen.
        await monthlyFile.rename(
          '${monthlyFile.path}.corrupt_${now.microsecondsSinceEpoch}',
        );
      }
    }

    final snapshot = await _readCurrentData();
    if (snapshot.players.isEmpty && snapshot.games.isEmpty) return null;
    final backup = await _writeBackup(
      snapshot,
      StatsBackupKind.automatic,
      fileName: fileName,
    );
    try {
      await _pruneAutomaticBackups();
    } catch (_) {
      // Ein Aufräumfehler macht das neue Backup nicht ungültig.
    }
    return backup;
  });

  Future<StatsBackup> _writeBackup(
    _BackupSnapshot snapshot,
    StatsBackupKind kind, {
    String? fileName,
  }) async {
    final now = DateTime.now();
    final backupName = fileName ??
        '${_kindToString(kind)}_${now.microsecondsSinceEpoch}.json';
    final payload = <String, Object?>{
      'formatVersion': _formatVersion,
      'createdAt': now.toIso8601String(),
      'kind': _kindToString(kind),
      'playerCount': snapshot.players.length,
      'gameCount': snapshot.games.length,
      'players': snapshot.players,
      'games': snapshot.games,
      'settings': snapshot.settings,
      'event': snapshot.event,
      'eventImage': snapshot.eventImage,
    };
    final directory = await _backupDirectory();
    await _writeAtomically(File(p.join(directory.path, backupName)), utf8.encode(jsonEncode(payload)));
    return StatsBackup(
      fileName: backupName,
      createdAt: now,
      kind: kind,
      playerCount: snapshot.players.length,
      gameCount: snapshot.games.length,
      formatVersion: _formatVersion,
    );
  }

  Future<void> _writeAtomically(File target, List<int> bytes) async {
    final temporary = File('${target.path}.tmp');
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(target.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<List<StatsBackup>> listBackups() async {
    final directory = await _backupDirectory();
    final backups = <StatsBackup>[];
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is! File) continue;
      final name = p.basename(entry.path);
      if (!_backupFilePattern.hasMatch(name)) continue;
      try {
        // Nicht nur den Header, sondern den ganzen Inhalt prüfen.
        final checked = await _readAndValidateBackup(entry);
        backups.add(_parseMetadata(name, checked.payload));
      } catch (_) {
        // Beschädigte Backups nicht zur Wiederherstellung anbieten.
      }
    }
    backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return backups;
  }

  Future<void> _pruneAutomaticBackups() async {
    final automatic = (await listBackups())
        .where((backup) => backup.kind == StatsBackupKind.automatic);
    for (final backup in automatic.skip(_maxAutomaticBackups)) {
      await (await _fileForBackup(backup)).delete();
    }
  }

  Future<File> _fileForBackup(StatsBackup backup) async {
    if (!_backupFilePattern.hasMatch(backup.fileName)) {
      throw const FormatException('Ungültiger Backup-Dateiname.');
    }
    final directory = await _backupDirectory();
    return File(p.join(directory.path, backup.fileName));
  }

  Future<void> deleteBackup(StatsBackup backup) => _exclusive(() async {
    final file = await _fileForBackup(backup);
    if (await file.exists()) await file.delete();
  });

  /// Exportiert unverändert die gewählte Sicherung, nicht nur einen Dateipfad
  /// aus dem privaten App-Speicher. Die UI speichert die Bytes über den Picker.
  Future<Uint8List> exportBackupBytes(StatsBackup backup) => _exclusive(() async {
    final file = await _fileForBackup(backup);
    final bytes = await file.readAsBytes();
    _decodeAndValidate(bytes);
    return bytes;
  });

  /// Nimmt externe Sicherungen beliebiger Dateinamen entgegen. Importieren
  /// allein verändert noch keine Spieler, Spiele oder Einstellungen.
  Future<StatsBackup> importBackupBytes(Uint8List bytes) => _exclusive(() async {
    final checked = _decodeAndValidate(bytes);
    final json = Map<String, dynamic>.from(checked.payload);
    // Importierte automatische Sicherungen als manuelle Kopien behalten.
    json['kind'] = 'manual';
    final directory = await _backupDirectory();
    var suffix = DateTime.now().microsecondsSinceEpoch;
    File destination;
    do {
      destination = File(p.join(directory.path, 'manual_$suffix.json'));
      suffix++;
    } while (await destination.exists());
    await _writeAtomically(destination, utf8.encode(jsonEncode(json)));
    return _parseMetadata(p.basename(destination.path), json);
  });

  /// Erst vollständige Validierung, dann Rückfall-Backup und DB-Transaktion.
  Future<void> restoreBackup(StatsBackup backup) => _exclusive(() async {
    final file = await _fileForBackup(backup);
    final snapshot = (await _readAndValidateBackup(file)).snapshot;
    final before = await _readCurrentData();
    await _writeBackup(before, StatsBackupKind.beforeRestore);

    File? createdImageFile;
    final db = await DatabaseService.instance.database;
    try {
      final image = snapshot.eventImage;
      if (image != null) {
        final documents = await getApplicationDocumentsDirectory();
        final directory = Directory(p.join(documents.path, 'event'));
        await directory.create(recursive: true);
        final extension = image['extension'] as String;
        final bytes = base64Decode(image['base64'] as String);
        createdImageFile = File(p.join(
          directory.path,
          'event_restored_${DateTime.now().microsecondsSinceEpoch}$extension',
        ));
        await createdImageFile.writeAsBytes(bytes, flush: true);
      }

      await db.transaction((txn) async {
        await txn.delete('games');
        await txn.delete('player');
        for (final player in snapshot.players) {
          await txn.insert('player', player);
        }
        for (final game in snapshot.games) {
          await txn.insert('games', game);
        }

        if (snapshot.formatVersion >= 2) {
          await txn.delete('app_settings');
          for (final setting in snapshot.settings) {
            await txn.insert('app_settings', setting);
          }
          await txn.delete('event_data');
          final event = Map<String, Object?>.from(snapshot.event!);
          if (createdImageFile != null) {
            event['imagePath'] = createdImageFile.path;
          }
          await txn.insert('event_data', event);
        }
      });
    } catch (_) {
      if (createdImageFile != null && await createdImageFile.exists()) {
        await createdImageFile.delete();
      }
      rethrow;
    }
  });

  Future<_CheckedBackup> _readAndValidateBackup(File file) async {
    return _decodeAndValidate(await file.readAsBytes());
  }

  _CheckedBackup _decodeAndValidate(List<int> bytes) {
    if (bytes.length > 40 * 1024 * 1024) {
      throw const FormatException('Die Backup-Datei ist zu groß (max. 40 MB).');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      throw const FormatException('Die gewählte Datei ist kein gültiges JSON-Backup.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Backup hat kein gültiges Format.');
    }
    final metadata = _parseMetadata('import', decoded);
    final rawPlayers = decoded['players'];
    final rawGames = decoded['games'];
    if (rawPlayers is! List || rawGames is! List) {
      throw const FormatException('Spieler oder Spiele fehlen im Backup.');
    }

    final players = <Map<String, Object?>>[];
    final playerIds = <int>{};
    for (final entry in rawPlayers) {
      final row = _validatePlayerRow(entry);
      if (!playerIds.add(row['id'] as int)) {
        throw const FormatException('Doppelte Spieler-ID im Backup.');
      }
      players.add(row);
    }
    final games = <Map<String, Object?>>[];
    final gameIds = <int>{};
    for (final entry in rawGames) {
      final row = _validateGameRow(entry);
      if (!gameIds.add(row['id'] as int)) {
        throw const FormatException('Doppelte Spiel-ID im Backup.');
      }
      games.add(row);
    }
    if (players.length != metadata.playerCount || games.length != metadata.gameCount) {
      throw const FormatException('Die Backup-Anzahlen stimmen nicht überein.');
    }

    final settings = <Map<String, Object?>>[];
    Map<String, Object?>? event;
    Map<String, String>? eventImage;
    if (metadata.includesAppData) {
      final rawSettings = decoded['settings'];
      if (rawSettings is! List) {
        throw const FormatException('Einstellungen fehlen im Backup.');
      }
      final keys = <String>{};
      for (final entry in rawSettings) {
        final row = _validateSettingRow(entry);
        if (!keys.add(row['key'] as String)) {
          throw const FormatException('Doppelter Einstellungsschlüssel im Backup.');
        }
        settings.add(row);
      }
      event = _validateEventRow(decoded['event']);
      if ((event['imagePath'] as String) == 'backup:event_image') {
        final rawImage = decoded['eventImage'];
        if (rawImage is! Map ||
            rawImage['extension'] is! String ||
            rawImage['base64'] is! String) {
          throw const FormatException('Das Eventbild fehlt im Backup.');
        }
        final extension = rawImage['extension'] as String;
        if (!_allowedImageExtensions.contains(extension)) {
          throw const FormatException('Ungültiges Eventbild-Dateiformat.');
        }
        try {
          final encodedImage = rawImage['base64'] as String;
          if (encodedImage.length > ((_maxEventImageBytes + 2) ~/ 3) * 4 + 8) {
            throw const FormatException('Ungültige Eventbild-Größe.');
          }
          final imageBytes = base64Decode(encodedImage);
          if (imageBytes.isEmpty || imageBytes.length > _maxEventImageBytes) {
            throw const FormatException('Ungültige Eventbild-Größe.');
          }
        } on FormatException {
          throw const FormatException('Beschädigtes Eventbild im Backup.');
        }
        eventImage = {
          'extension': extension,
          'base64': rawImage['base64'] as String,
        };
      } else if (!(event['imagePath'] as String).startsWith('assets/')) {
        // Kein alter absoluter Pfad darf auf einem anderen Gerät genutzt werden.
        throw const FormatException('Das Backup enthält einen geräteabhängigen Eventbild-Pfad.');
      }
    }
    return _CheckedBackup(
      payload: decoded,
      snapshot: _BackupSnapshot(
        formatVersion: metadata.formatVersion,
        players: players,
        games: games,
        settings: settings,
        event: event,
        eventImage: eventImage,
      ),
    );
  }

  StatsBackup _parseMetadata(String fileName, Map<String, dynamic> json) {
    final version = json['formatVersion'];
    if (version != 1 && version != _formatVersion) {
      throw const FormatException('Nicht unterstützte Backup-Version.');
    }
    final date = DateTime.tryParse(json['createdAt']?.toString() ?? '');
    final kind = _kindFromString(json['kind']);
    final playerCount = json['playerCount'];
    final gameCount = json['gameCount'];
    if (date == null || kind == null || playerCount is! int ||
        gameCount is! int || playerCount < 0 || gameCount < 0) {
      throw const FormatException('Ungültige Backup-Metadaten.');
    }
    return StatsBackup(
      fileName: fileName,
      createdAt: date,
      kind: kind,
      playerCount: playerCount,
      gameCount: gameCount,
      formatVersion: version as int,
    );
  }

  Map<String, Object?> _validatePlayerRow(Object? entry) {
    if (entry is! Map) {
      throw const FormatException('Ungültiger Spieler-Datensatz.');
    }
    final row = Map<String, Object?>.from(entry);
    if (!_playerColumns.every(row.containsKey) ||
        row['id'] is! int || (row['id'] as int) < 1 ||
        row['name'] is! String || row['status'] is! int ||
        row['position'] is! int || row['team'] is! int ||
        row['winRate'] is! num || !(row['winRate'] as num).isFinite ||
        row['wins'] is! int || row['losses'] is! int ||
        row['attendance'] is! int) {
      throw const FormatException('Spielerdaten im Backup sind beschädigt.');
    }
    return {for (final key in _playerColumns) key: row[key]};
  }

  Map<String, Object?> _validateGameRow(Object? entry) {
    if (entry is! Map) {
      throw const FormatException('Ungültiger Spiel-Datensatz.');
    }
    final row = Map<String, Object?>.from(entry);
    if (!_gameColumns.every(row.containsKey) ||
        row['id'] is! int || (row['id'] as int) < 1 ||
        row['name'] is! String || row['teamA'] is! String ||
        row['teamB'] is! String || row['teamBWon'] is! int) {
      throw const FormatException('Spieldaten im Backup sind beschädigt.');
    }
    return {for (final key in _gameColumns) key: row[key]};
  }

  Map<String, Object?> _validateSettingRow(Object? entry) {
    if (entry is! Map) {
      throw const FormatException('Ungültige Einstellung.');
    }
    final row = Map<String, Object?>.from(entry);
    if (!_settingColumns.every(row.containsKey) ||
        row['key'] is! String || (row['key'] as String).isEmpty ||
        row['value'] is! String) {
      throw const FormatException('Einstellungen im Backup sind beschädigt.');
    }
    return {for (final key in _settingColumns) key: row[key]};
  }

  Map<String, Object?> _validateEventRow(Object? entry) {
    if (entry is! Map) {
      throw const FormatException('Eventdaten fehlen im Backup.');
    }
    final row = Map<String, Object?>.from(entry);
    if (!_eventColumns.every(row.containsKey) ||
        row['id'] != 1 || row['title'] is! String ||
        row['imagePath'] is! String || row['markdownText'] is! String ||
        row['link'] is! String) {
      throw const FormatException('Eventdaten im Backup sind beschädigt.');
    }
    return {for (final key in _eventColumns) key: row[key]};
  }

  String _kindToString(StatsBackupKind kind) {
    switch (kind) {
      case StatsBackupKind.manual:
        return 'manual';
      case StatsBackupKind.automatic:
        return 'automatic';
      case StatsBackupKind.beforeRestore:
        return 'before_restore';
    }
  }

  StatsBackupKind? _kindFromString(Object? value) {
    switch (value) {
      case 'manual':
        return StatsBackupKind.manual;
      case 'automatic':
        return StatsBackupKind.automatic;
      case 'before_restore':
        return StatsBackupKind.beforeRestore;
      default:
        return null;
    }
  }
}

class _CheckedBackup {
  final Map<String, dynamic> payload;
  final _BackupSnapshot snapshot;
  const _CheckedBackup({required this.payload, required this.snapshot});
}

class _BackupSnapshot {
  final int formatVersion;
  final List<Map<String, Object?>> players;
  final List<Map<String, Object?>> games;
  final List<Map<String, Object?>> settings;
  final Map<String, Object?>? event;
  Map<String, String>? eventImage;

  _BackupSnapshot({
    required this.formatVersion,
    required this.players,
    required this.games,
    this.settings = const [],
    this.event,
    this.eventImage,
  });
}
