// VERSION 2026-11-12: Manuelle und monatliche Statistik-Backups mit sicherer Wiederherstellung.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:teamer/database/database_services.dart';

enum StatsBackupKind { manual, automatic, beforeRestore }

class StatsBackup {
  final String fileName;
  final DateTime createdAt;
  final StatsBackupKind kind;
  final int playerCount;
  final int gameCount;

  const StatsBackup({
    required this.fileName,
    required this.createdAt,
    required this.kind,
    required this.playerCount,
    required this.gameCount,
  });

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

  static const int _formatVersion = 1;
  static const int _maxAutomaticBackups = 12;
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

  // Sichert parallele Backup-, Lösch- und Wiederherstellungsvorgänge ab.
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

  Future<_StatsSnapshot> _readCurrentStatistics() async {
    final db = await DatabaseService.instance.database;
    return db.transaction((txn) async {
      // Beide Tabellen werden aus demselben konsistenten DB-Stand gelesen.
      final players = await txn.query('player', orderBy: 'id');
      final games = await txn.query('games', orderBy: 'id');
      return _StatsSnapshot(
        players: players.map((row) => Map<String, Object?>.from(row)).toList(),
        games: games.map((row) => Map<String, Object?>.from(row)).toList(),
      );
    });
  }

  Future<StatsBackup> createManualBackup() {
    return _exclusive(() async {
      final snapshot = await _readCurrentStatistics();
      return _writeBackup(snapshot, StatsBackupKind.manual);
    });
  }

  /// Ein Backup pro Kalendermonat beim ersten App-Start/Fortsetzen mit Daten.
  /// Das ist keine Ausführung bei vollständig geschlossener App.
  Future<StatsBackup?> createMonthlyBackupIfNeeded() {
    return _exclusive(() async {
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
          // Eine defekte Sicherung niemals als erfolgreich zählen.
          // Die beschädigte Datei bleibt für eine mögliche Analyse erhalten.
          await monthlyFile.rename(
            '${monthlyFile.path}.corrupt_${now.microsecondsSinceEpoch}',
          );
        }
      }

      final snapshot = await _readCurrentStatistics();
      if (snapshot.players.isEmpty && snapshot.games.isEmpty) return null;

      final backup = await _writeBackup(
        snapshot,
        StatsBackupKind.automatic,
        fileName: fileName,
      );

      // Nur automatische Backups begrenzen, manuelle bleiben erhalten.
      try {
        await _pruneAutomaticBackups();
      } catch (_) {
        // Ein erfolgreich geschriebenes Backup bleibt trotz Aufräumfehler gültig.
      }
      return backup;
    });
  }

  Future<StatsBackup> _writeBackup(
    _StatsSnapshot snapshot,
    StatsBackupKind kind, {
    String? fileName,
  }) async {
    final now = DateTime.now();
    final backupName = fileName ??
        '${_kindToString(kind)}_${now.microsecondsSinceEpoch}.json';
    final directory = await _backupDirectory();
    final target = File(p.join(directory.path, backupName));
    final temporary = File('${target.path}.tmp');
    final payload = <String, Object?>{
      'formatVersion': _formatVersion,
      'createdAt': now.toIso8601String(),
      'kind': _kindToString(kind),
      'playerCount': snapshot.players.length,
      'gameCount': snapshot.games.length,
      'players': snapshot.players,
      'games': snapshot.games,
    };

    try {
      await temporary.writeAsString(jsonEncode(payload), flush: true);
      await temporary.rename(target.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }

    return StatsBackup(
      fileName: backupName,
      createdAt: now,
      kind: kind,
      playerCount: snapshot.players.length,
      gameCount: snapshot.games.length,
    );
  }

  Future<List<StatsBackup>> listBackups() async {
    final directory = await _backupDirectory();
    final backups = <StatsBackup>[];

    await for (final entry in directory.list(followLinks: false)) {
      if (entry is! File) continue;
      final name = p.basename(entry.path);
      if (!_backupFilePattern.hasMatch(name)) continue;

      try {
        final parsed = jsonDecode(await entry.readAsString());
        if (parsed is! Map<String, dynamic>) continue;
        backups.add(_parseMetadata(name, parsed));
      } catch (_) {
        // Defekte Dateien werden nicht zur Wiederherstellung angeboten.
      }
    }

    backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return backups;
  }

  Future<void> _pruneAutomaticBackups() async {
    final backups = await listBackups();
    final automatic = backups
        .where((backup) => backup.kind == StatsBackupKind.automatic)
        .toList();
    for (final backup in automatic.skip(_maxAutomaticBackups)) {
      final file = await _fileForBackup(backup);
      await file.delete();
    }
  }

  Future<File> _fileForBackup(StatsBackup backup) async {
    if (!_backupFilePattern.hasMatch(backup.fileName)) {
      throw const FormatException('Ungültiger Backup-Dateiname.');
    }
    final directory = await _backupDirectory();
    return File(p.join(directory.path, backup.fileName));
  }

  Future<void> deleteBackup(StatsBackup backup) {
    return _exclusive(() async {
      final file = await _fileForBackup(backup);
      if (await file.exists()) await file.delete();
    });
  }

  /// Validiert vorab alle Daten und stellt sie in EINER Transaktion wieder her.
  /// Vorher wird eine zusätzliche Rückfall-Sicherung angelegt.
  Future<void> restoreBackup(StatsBackup backup) {
    return _exclusive(() async {
      final file = await _fileForBackup(backup);
      final snapshot = await _readAndValidateBackup(file);

      final oldSnapshot = await _readCurrentStatistics();
      await _writeBackup(oldSnapshot, StatsBackupKind.beforeRestore);

      final db = await DatabaseService.instance.database;
      await db.transaction((txn) async {
        await txn.delete('games');
        await txn.delete('player');

        for (final player in snapshot.players) {
          await txn.insert('player', player);
        }
        for (final game in snapshot.games) {
          await txn.insert('games', game);
        }
      });
    });
  }

  Future<_StatsSnapshot> _readAndValidateBackup(File file) async {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Backup hat kein gültiges Format.');
    }
    final metadata = _parseMetadata(p.basename(file.path), decoded);

    final rawPlayers = decoded['players'];
    final rawGames = decoded['games'];
    if (rawPlayers is! List || rawGames is! List) {
      throw const FormatException('Spieler oder Spiele fehlen im Backup.');
    }

    final players = <Map<String, Object?>>[];
    final playerIds = <int>{};
    for (final entry in rawPlayers) {
      final player = _validatePlayerRow(entry);
      if (!playerIds.add(player['id'] as int)) {
        throw const FormatException('Doppelte Spieler-ID im Backup.');
      }
      players.add(player);
    }

    final games = <Map<String, Object?>>[];
    final gameIds = <int>{};
    for (final entry in rawGames) {
      final game = _validateGameRow(entry);
      if (!gameIds.add(game['id'] as int)) {
        throw const FormatException('Doppelte Spiel-ID im Backup.');
      }
      games.add(game);
    }

    if (players.length != metadata.playerCount ||
        games.length != metadata.gameCount) {
      throw const FormatException('Die Backup-Anzahlen stimmen nicht überein.');
    }
    return _StatsSnapshot(players: players, games: games);
  }

  StatsBackup _parseMetadata(String fileName, Map<String, dynamic> json) {
    if (json['formatVersion'] != _formatVersion) {
      throw const FormatException('Nicht unterstützte Backup-Version.');
    }
    final date = DateTime.tryParse(json['createdAt']?.toString() ?? '');
    final kind = _kindFromString(json['kind']);
    final playerCount = json['playerCount'];
    final gameCount = json['gameCount'];
    if (date == null || kind == null || playerCount is! int ||
        gameCount is! int || playerCount < 0 || gameCount < 0 ||
        !fileName.startsWith('${_kindToString(kind)}_')) {
      throw const FormatException('Ungültige Backup-Metadaten.');
    }
    return StatsBackup(
      fileName: fileName,
      createdAt: date,
      kind: kind,
      playerCount: playerCount,
      gameCount: gameCount,
    );
  }

  Map<String, Object?> _validatePlayerRow(Object? entry) {
    if (entry is! Map) {
      throw const FormatException('Ungültiger Spieler-Datensatz.');
    }
    final row = Map<String, Object?>.from(entry);
    if (!_playerColumns.every(row.containsKey) ||
        row['id'] is! int || (row['id'] as int) < 1 ||
        row['name'] is! String ||
        row['status'] is! int || row['position'] is! int ||
        row['team'] is! int || row['winRate'] is! num ||
        !(row['winRate'] as num).isFinite ||
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

class _StatsSnapshot {
  final List<Map<String, Object?>> players;
  final List<Map<String, Object?>> games;

  const _StatsSnapshot({required this.players, required this.games});
}
