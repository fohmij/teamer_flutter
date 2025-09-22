import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:teamer/database/player.dart';

class DatabaseService {
  static Database? _db;
  static final DatabaseService instance = DatabaseService._constructor();

  final String _playersTableName = "player";
  final String _playersIDColumnName = "id";
  final String _playersNameColumnName = "name";
  final String _playersStatusColumnName = "status";
  final String _playersPositionColumnName = "position";
  final String _playersTeamColumnName = "team";
  final String _playersWinRateColumnName = "winRate";
  final String _playersWinsColumnName = "wins";
  final String _playersLossesColumnName = "losses";
  final String _playersAttendanceColumnName = "attendance";

  DatabaseService._constructor();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await getDatabase();
    return _db!;
  }

  Future<Database> getDatabase() async {
    final databaseDirPath = await getDatabasesPath();
    final databasePath = join(databaseDirPath, "master_db.db");
    print("DB Path: $databasePath");
    await deleteDatabase(
      databasePath,
    ); // Wenn mal wieder die Database nicht funktioniert nach einer Änderung

    final database = await openDatabase(
      databasePath,
      version: 3,
      onCreate: (db, version) {
        // Wenn mal wieder die Database nicht funktioniert nach einer Änderung
        db.execute('''
        CREATE TABLE $_playersTableName(
          $_playersIDColumnName INTEGER PRIMARY KEY,
          $_playersNameColumnName TEXT NOT NULL,
          $_playersStatusColumnName INTEGER NOT NULL,
          $_playersPositionColumnName INTEGER NOT NULL,
          $_playersTeamColumnName INTEGER NOT NULL,
          $_playersWinRateColumnName REAL NOT NULL,
          $_playersWinsColumnName INTEGER NOT NULL,
          $_playersLossesColumnName INTEGER NOT NULL,
          $_playersAttendanceColumnName INTEGER NOT NULL
        )
        ''');
      },
    );
    return database;
  }

  Future<void> resetStats() async {
    final db = await database;
    await db.rawUpdate('''
    UPDATE $_playersTableName
    SET 
      $_playersWinRateColumnName = 0,
      $_playersWinsColumnName = 0,
      $_playersLossesColumnName = 0,
      $_playersAttendanceColumnName = 0
  ''');
  }

  Future<int> getItemCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_playersTableName',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> addPlayer(String name) async {
    final db = await database;
    int itemCount = await getItemCount();
    await db.insert(_playersTableName, {
      _playersNameColumnName: name,
      _playersStatusColumnName: 0,
      _playersPositionColumnName: itemCount,
      _playersTeamColumnName: 0,
      _playersWinRateColumnName: 0.5,
      _playersWinsColumnName: 0,
      _playersLossesColumnName: 0,
      _playersAttendanceColumnName: 0,
    });
  }

  Future<List<Player>> getPlayers() async {
    final db = await database;
    final data = await db.query(
      _playersTableName,
      orderBy: '$_playersNameColumnName COLLATE NOCASE',
    );
    List<Player> players = data
        .map(
          (e) => Player(
            id: e[_playersIDColumnName] as int,
            name: e[_playersNameColumnName] as String,
            status: e[_playersStatusColumnName] as int,
            position: e[_playersPositionColumnName] as int,
            team: e[_playersTeamColumnName] as int,
            winRate: (e[_playersWinRateColumnName] as num).toDouble(),
            wins: e[_playersWinsColumnName] as int,
            losses: e[_playersLossesColumnName] as int,
            attendance: e[_playersAttendanceColumnName] as int,
          ),
        )
        .toList();
    return players;
  }

  Future<void> updatePlayerStatus(int id, int status) async {
    final db = await database;
    await db.update(
      _playersTableName,
      {_playersStatusColumnName: status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateIndex(int id, int newIndex) async {
    final db = await database;
    await db.update(
      _playersTableName,
      {_playersPositionColumnName: newIndex},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateAllPositions(List<Player> players) async {
    final db = await database;

    // Transaktion starten (sichert, dass alle Updates ausgeführt werden)
    await db.transaction((txn) async {
      for (int i = 0; i < players.length; i++) {
        await txn.update(
          _playersTableName,
          {_playersPositionColumnName: i},
          where: 'id = ?',
          whereArgs: [players[i].id],
        );
      }
    });
  }

  Future<void> deletePlayer(int id) async {
    final db = await database;
    await db.delete(_playersTableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> randomTeams() async {
    List<Player> players = await getPlayers();
    List<Player> activePlayers = players.where((p) => p.status == 1).toList();

    if (activePlayers.isEmpty) return;

    activePlayers.shuffle();
    int half = (activePlayers.length / 2).ceil();
    List<Player> teamA = activePlayers.sublist(0, half);
    List<Player> teamB = activePlayers.sublist(half);

    final db = await database;

    await db.transaction((txn) async {
      for (Player player in teamA) {
        await txn.update(
          _playersTableName,
          {_playersTeamColumnName: 0},
          where: '$_playersIDColumnName = ?',
          whereArgs: [player.id],
        );
      }
      for (Player player in teamB) {
        await txn.update(
          _playersTableName,
          {_playersTeamColumnName: 1},
          where: '$_playersIDColumnName = ?',
          whereArgs: [player.id],
        );
      }
    });
  }

  Future<void> teamAWins() async {
    List<Player> players = await getPlayers();
    List<Player> activePlayersTeamA = players
        .where((p) => p.status == 1 && p.team == 0)
        .toList();
    List<Player> activePlayersTeamB = players
        .where((p) => p.status == 1 && p.team == 1)
        .toList();

    if (activePlayersTeamA.isEmpty && activePlayersTeamB.isEmpty) return;

    final db = await database;

    await db.transaction((txn) async {
      for (int i = 0; i < activePlayersTeamA.length; i++) {
        int id = activePlayersTeamA[i].id;
        await txn.rawUpdate(
          '''
          UPDATE $_playersTableName
          SET $_playersWinsColumnName = $_playersWinsColumnName + 1,
          $_playersAttendanceColumnName = $_playersAttendanceColumnName + 1,
          $_playersWinRateColumnName = ($_playersWinsColumnName + 1) * 1.0 / ($_playersAttendanceColumnName + 1)
          WHERE $_playersIDColumnName = ?
          ''',
          [id],
        );
      }

      for (int i = 0; i < activePlayersTeamB.length; i++) {
        int id = activePlayersTeamB[i].id;
        await txn.rawUpdate(
          '''
          UPDATE $_playersTableName
          SET $_playersLossesColumnName = $_playersLossesColumnName + 1,
          $_playersAttendanceColumnName = $_playersAttendanceColumnName + 1,
          $_playersWinRateColumnName = $_playersWinsColumnName * 1.0 / ($_playersAttendanceColumnName + 1)
          WHERE $_playersIDColumnName = ?
          ''',
          [id],
        );
      }
    });
  }

  Future<void> teamBWins() async {
    List<Player> players = await getPlayers();
    List<Player> activePlayersTeamA = players
        .where((p) => p.status == 1 && p.team == 0)
        .toList();
    List<Player> activePlayersTeamB = players
        .where((p) => p.status == 1 && p.team == 1)
        .toList();

    if (activePlayersTeamA.isEmpty && activePlayersTeamB.isEmpty) return;

    final db = await database;

    await db.transaction((txn) async {
      for (int i = 0; i < activePlayersTeamA.length; i++) {
        int id = activePlayersTeamA[i].id;
        await txn.rawUpdate(
          '''
          UPDATE $_playersTableName
          SET $_playersLossesColumnName = $_playersLossesColumnName + 1,
          $_playersAttendanceColumnName = $_playersAttendanceColumnName + 1,
          $_playersWinRateColumnName = $_playersWinsColumnName * 1.0 / ($_playersAttendanceColumnName + 1)
          WHERE $_playersIDColumnName = ?
          ''',
          [id],
        );
      }

      for (int i = 0; i < activePlayersTeamB.length; i++) {
        int id = activePlayersTeamB[i].id;
        await txn.rawUpdate(
          '''
          UPDATE $_playersTableName
          SET $_playersWinsColumnName = $_playersWinsColumnName + 1,
          $_playersAttendanceColumnName = $_playersAttendanceColumnName + 1,
          $_playersWinRateColumnName = ($_playersWinsColumnName + 1) * 1.0 / ($_playersAttendanceColumnName + 1)
          WHERE $_playersIDColumnName = ?
          ''',
          [id],
        );
      }
    });
  }

  Future<void> draw() async {
    List<Player> players = await getPlayers();
    List<Player> activePlayers = players.where((p) => p.status == 1).toList();

    if (activePlayers.isEmpty) return;

    final db = await database;

    await db.transaction((txn) async {
      for (int i = 0; i < activePlayers.length; i++) {
        int id = activePlayers[i].id;
        await txn.rawUpdate(
          '''
          UPDATE $_playersTableName
          SET $_playersAttendanceColumnName = $_playersAttendanceColumnName + 1,
          $_playersWinRateColumnName = ($_playersWinsColumnName) * 1.0 / ($_playersAttendanceColumnName + 1)
          WHERE $_playersIDColumnName = ?
          ''',
          [id],
        );
      }
    });
  }
}
