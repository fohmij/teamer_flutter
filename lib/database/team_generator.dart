import 'player.dart';

class TeamSplitResult {
  final List<Player> teamA;
  final List<Player> teamB;

  TeamSplitResult({required this.teamA, required this.teamB});
}

TeamSplitResult splitPlayersByWinRate(List<Player> players) {
  int n = players.length;
  if (n == 0) {
    return TeamSplitResult(teamA: [], teamB: []);
  }

  double bestDiff = double.infinity;
  List<Player> bestA = [];
  List<Player> bestB = [];

  int start = n ~/ 2;
  int end = 1 << (n - 1); // 2^(n-1)

  for (int mask = start; mask < end; mask++) {
    // Anzahl der 1en im Bitmuster
    int ones = mask.toRadixString(2).replaceAll("0", "").length;

    bool cond;
    if (n % 2 == 0) {
      cond = ones == start;
    } else {
      cond = (ones == start || ones == start + 1);
    }
    if (!cond) continue;

    List<Player> teamA = [];
    List<Player> teamB = [];

    for (int i = 0; i < n; i++) {
      if ((mask >> i) & 1 == 1) {
        teamA.add(players[i]);
      } else {
        teamB.add(players[i]);
      }
    }

    // Durchschnitt berechnen
    double avgA = teamA.isEmpty
        ? 0.0
        : teamA.map((p) => p.winRate).reduce((a, b) => a + b) / teamA.length;
    double avgB = teamB.isEmpty
        ? 0.0
        : teamB.map((p) => p.winRate).reduce((a, b) => a + b) / teamB.length;

    double diff = (avgA - avgB).abs();

    if (diff < bestDiff) {
      bestDiff = diff;
      bestA = List.from(teamA);
      bestB = List.from(teamB);
    }
  }

  return TeamSplitResult(teamA: bestA, teamB: bestB);
}
