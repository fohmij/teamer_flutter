import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:teamer/database/player.dart';

class DatabaseService {
  static Database? _db;
  static final DatabaseService instance = DatabaseService._constructor();

  final String _playersTableName = "player";
  final String _playersIDColumnName = "playerID";
  final String _playersNameColumnName = "name";

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
        )
        ''');
    });
    print("Hallo");
    return database;
  }

  void addPlayer(
    String content,
  ) async {
    final db = await database;
    await db.insert(_playersTableName, {
      _playersIDColumnName: content,
      _playersNameColumnName: 0,
    });
  }

  Future<List<Player>> getTasks() async {
    final db = await database;
    final data = await db.query(_playersTableName);
    List<Player> players = data
        .map((e) => Player(
            playerID: e["playerID"] as int,
            name: e["name"] as String))
        .toList();
    print("TastNr:  ${players.length}");
    return players;
  }
}
