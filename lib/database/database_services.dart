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
  final String _playersPostionColumnName = "position";
  final String _playersTeamColumnName = "team";

  DatabaseService._constructor();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await getDatabase();
    return _db!;
  }

  Future<Database> getDatabase() async {
    final databaseDirPath = await getDatabasesPath();
    final databasePath = join(databaseDirPath, "master_db.db");
    final database =
        await openDatabase(databasePath, version: 1, onCreate: (db, version) {
      db.execute('''
        CREATE TABLE $_playersTableName(
          $_playersIDColumnName INTEGER PRIMARY KEY,
          $_playersNameColumnName TEXT NOT NULL,
          $_playersStatusColumnName INTEGER NOT NULL,
          $_playersPostionColumnName INTEGER NOT NULL,
          $_playersTeamColumnName INTEGER NOT NULL
        )
        ''');
    });
    return database;
  }

  Future<int> getItemCount() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM $_playersTableName');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> addPlayer(
    String name,
  ) async {
    final db = await database;
    int itemCount = await getItemCount();
    await db.insert(_playersTableName, {
      _playersNameColumnName: name,
      _playersStatusColumnName: 0,
      _playersPostionColumnName: itemCount,
      _playersTeamColumnName: 0,
    });
  }

  Future<List<Player>> getPlayers() async {
    final db = await database;
    final data = await db.query(_playersTableName);
    List<Player> players = data
        .map((e) => Player(
            id: e["id"] as int,
            name: e["name"] as String,
            status: e["status"] as int,
            position: e["position"] as int,
            team: e["team"] as int))
        .toList();
    return players;
  }

  Future<void> updatePlayerStatus(int id, int status) async {
    final db = await database;
    await db.update(
        _playersTableName,
        {
          _playersStatusColumnName: status,
        },
        where: 'id = ?',
        whereArgs: [
          id,
        ]);
  }

  Future<void> updateIndex(int id, int newIndex) async {
    final db = await database;
    await db.update(
      _playersTableName,
      {_playersPostionColumnName: newIndex},
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
          {_playersPostionColumnName: i},
          where: 'id = ?',
          whereArgs: [players[i].id],
        );
      }
    });
  }

  void deletePlayer(int id) async {
    final db = await database;
    await db.delete(_playersTableName, where: 'id = ?', whereArgs: [
      id,
    ]);
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
}
