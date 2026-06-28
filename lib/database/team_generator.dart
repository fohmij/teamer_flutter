import 'player.dart';

class WeightedPlayer {
  final Player player;
  final double effectiveWinRate;
  final bool usesFallbackWeight;

  const WeightedPlayer({
    required this.player,
    required this.effectiveWinRate,
    required this.usesFallbackWeight,
  });
}

class TeamSplitResult {
  final List<WeightedPlayer> teamA;
  final List<WeightedPlayer> teamB;

  TeamSplitResult({required this.teamA, required this.teamB});

  List<Player> get playersTeamA => teamA.map((p) => p.player).toList();
  List<Player> get playersTeamB => teamB.map((p) => p.player).toList();

  double get averageTeamA => _average(teamA);
  double get averageTeamB => _average(teamB);
  double get difference => (averageTeamA - averageTeamB).abs();

  static double _average(List<WeightedPlayer> players) {
    if (players.isEmpty) return 0.0;
    return players.map((p) => p.effectiveWinRate).reduce((a, b) => a + b) /
        players.length;
  }
}

TeamSplitResult splitPlayersByWinRate(
  List<Player> players, {
  required int minGamesForFullWeight,
}) {
  final weightedPlayers = players
      .map(
        (player) => WeightedPlayer(
          player: player,
          effectiveWinRate: player.attendance < minGamesForFullWeight
              ? 0.5
              : player.winRate,
          usesFallbackWeight: player.attendance < minGamesForFullWeight,
        ),
      )
      .toList();

  int n = weightedPlayers.length;
  if (n == 0) {
    return TeamSplitResult(teamA: [], teamB: []);
  }

  double bestDiff = double.infinity;
  List<WeightedPlayer> bestA = [];
  List<WeightedPlayer> bestB = [];

  int start = n ~/ 2;
  int end = 1 << (n - 1);

  for (int mask = start; mask < end; mask++) {
    int ones = mask.toRadixString(2).replaceAll('0', '').length;

    bool cond;
    if (n % 2 == 0) {
      cond = ones == start;
    } else {
      cond = (ones == start || ones == start + 1);
    }
    if (!cond) continue;

    List<WeightedPlayer> teamA = [];
    List<WeightedPlayer> teamB = [];

    for (int i = 0; i < n; i++) {
      if ((mask >> i) & 1 == 1) {
        teamA.add(weightedPlayers[i]);
      } else {
        teamB.add(weightedPlayers[i]);
      }
    }

    double avgA = TeamSplitResult._average(teamA);
    double avgB = TeamSplitResult._average(teamB);
    double diff = (avgA - avgB).abs();

    if (diff < bestDiff) {
      bestDiff = diff;
      bestA = List.from(teamA);
      bestB = List.from(teamB);
    }
  }

  return TeamSplitResult(teamA: bestA, teamB: bestB);
}
