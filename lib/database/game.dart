class Game {
  final int id;
  final String name;
  final List<int> teamA;
  final List<int> teamB;
  final int teamBWon;

  final String teamANames; // aufgelöst
  final String teamBNames; // aufgelöst

  Game({
    required this.id,
    required this.name,
    required this.teamA,
    required this.teamB,
    required this.teamBWon,
    required this.teamANames,
    required this.teamBNames,
  });

  factory Game.fromMap(Map<String, dynamic> map, {required String teamANames, required String teamBNames}) {    return Game(
      id: map['id'] as int,
      name: map['name'] as String,
      teamA: (map['teamA'] as String).split(",").map(int.parse).toList(),
      teamB: (map['teamB'] as String).split(",").map(int.parse).toList(),
      teamBWon: map['teamBWon'] as int,
      teamANames: teamANames,
      teamBNames: teamBNames,
    );
  }
}