// VERSION 2026-11-09: Optimale Varianten auch mit frei vorgegebenen Teamgrößen.
import 'package:flutter/foundation.dart';
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

/// Alle gleich guten Aufteilungen mit automatisch balancierten oder festen Teamgrößen.
///
/// Ein bloßer Austausch der Teamnamen A/B zählt nicht als weitere Variante.
/// Die Ergebnisse sind kompakt als Kombinationen von Halbgruppen gespeichert,
/// anstatt mehrere Millionen vollständige Teamlisten im Speicher zu halten.
class OptimalTeamSplits {
  final List<WeightedPlayer> players;
  final int _leftLength;
  final bool _canonicalMirrors;
  final List<_SplitRange> _ranges;
  final int count;

  const OptimalTeamSplits._(
    this.players,
    this._leftLength,
    this._canonicalMirrors,
    this._ranges,
    this.count,
  );

  TeamSplitResult resultAt(int index) {
    if (count == 0) {
      return TeamSplitResult(teamA: [], teamB: []);
    }
    if (index < 0 || index >= count) {
      throw RangeError.range(index, 0, count - 1, 'index');
    }

    // Eine binäre Suche findet die gewünschte Variante ohne Durchlaufen
    // aller davorliegenden optimalen Aufteilungen.
    int low = 0;
    int high = _ranges.length;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (_ranges[mid].endIndex <= index) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    final range = _ranges[low];
    final offset = index - range.startIndex;
    final rightMask = range.rightSubsets[range.firstRight + offset].mask;
    final selectedMask = range.leftMask | (rightMask << _leftLength);

    final teamA = <WeightedPlayer>[];
    final teamB = <WeightedPlayer>[];
    for (int i = 0; i < players.length; i++) {
      if ((selectedMask & (1 << i)) != 0) {
        teamA.add(players[i]);
      } else {
        teamB.add(players[i]);
      }
    }
    return TeamSplitResult(teamA: teamA, teamB: teamB);
  }

  /// Liefert den Index der aktuellen Aufteilung, falls sie eine der optimalen
  /// Varianten ist. Bei einer manuellen Änderung kann das Ergebnis null sein.
  int? indexForTeamA(Iterable<int> teamAPlayerIds) {
    if (count == 0) return null;
    final ids = teamAPlayerIds.toSet();
    int selectedMask = 0;
    int selectedCount = 0;
    for (int i = 0; i < players.length; i++) {
      if (ids.contains(players[i].player.id)) {
        selectedMask |= 1 << i;
        selectedCount++;
      }
    }
    if (selectedCount != ids.length) return null;
    // Bei spiegelbaren Teams wird die aktuelle Aufteilung kanonisiert.
    if (_canonicalMirrors &&
        (selectedMask & (1 << (players.length - 1))) != 0) {
      selectedMask ^= (1 << players.length) - 1;
    }

    final leftMask = selectedMask & ((1 << _leftLength) - 1);
    final rightMask = selectedMask >> _leftLength;
    for (final range in _ranges) {
      if (range.leftMask != leftMask) continue;
      for (int j = range.firstRight; j < range.lastRight; j++) {
        if (range.rightSubsets[j].mask == rightMask) {
          return range.startIndex + j - range.firstRight;
        }
      }
    }
    return null;
  }
}

class _SplitRequest {
  final List<Player> players;
  final int minGames;
  final int? teamASize;

  const _SplitRequest(this.players, this.minGames, this.teamASize);
}

class _Subset {
  final int mask;
  final int sum;
  final int size;

  const _Subset(this.mask, this.sum, this.size);
}

class _SplitRange {
  final int leftMask;
  final List<_Subset> rightSubsets;
  final int firstRight;
  final int lastRight;
  final int startIndex;
  final int endIndex;

  const _SplitRange({
    required this.leftMask,
    required this.rightSubsets,
    required this.firstRight,
    required this.lastRight,
    required this.startIndex,
    required this.endIndex,
  });
}

/// Auf Android läuft die Suche in einem Isolate, damit die Oberfläche
/// während der Berechnung weiterhin reagiert.
Future<OptimalTeamSplits> findOptimalTeamSplits(
  List<Player> players, {
  required int minGamesForFullWeight,
  int? teamASize,
}) {
  return compute(
    _calculateOptimalTeamSplits,
    _SplitRequest(players, minGamesForFullWeight, teamASize),
  );
}

/// Weiterhin verfügbar für bestehende Aufrufer, die nur eine Variante wollen.
TeamSplitResult splitPlayersByWinRate(
  List<Player> players, {
  required int minGamesForFullWeight,
}) {
  return _calculateOptimalTeamSplits(
    _SplitRequest(players, minGamesForFullWeight, null),
  ).resultAt(0);
}

OptimalTeamSplits _calculateOptimalTeamSplits(_SplitRequest request) {
  final weightedPlayers = request.players.map((player) {
    final fallback = player.attendance < request.minGames;
    return WeightedPlayer(
      player: player,
      effectiveWinRate: fallback ? 0.5 : player.winRate,
      usesFallbackWeight: fallback,
    );
  }).toList();
  final n = weightedPlayers.length;
  final requestedSize = request.teamASize;
  if (requestedSize != null && (requestedSize < 0 || requestedSize > n)) {
    throw RangeError.range(requestedSize, 0, n, 'teamASize');
  }
  if (n == 0) {
    return OptimalTeamSplits._(weightedPlayers, 0, false, const [], 0);
  }
  if (n == 1 || requestedSize == 0 || requestedSize == n) {
    final selectedMask = requestedSize == 0 ? 0 : (1 << n) - 1;
    return OptimalTeamSplits._(
      weightedPlayers, 0, false,
      [
        _SplitRange(
          leftMask: 0,
          rightSubsets: [_Subset(selectedMask, 0, requestedSize ?? n)],
          firstRight: 0, lastRight: 1, startIndex: 0, endIndex: 1,
        ),
      ],
      1,
    );
  }

  // Mit einer festen Skalierung von 10^12 werden mathematisch gleichwertige
  // Lösungen nicht wegen kleinster double-Abweichungen unterschiedlich gezählt.
  // Die Zahlen bleiben bei maximal 25 Spielern im sicheren Integer-Bereich.
  const precision = 1000000000000;
  final values = weightedPlayers
      .map((p) => (p.effectiveWinRate * precision).round())
      .toList();
  final total = values.fold<int>(0, (a, b) => a + b);

  // Nur bei der freien Ersteinteilung und exakt gleich großen Teams
  // werden A/B-Spiegelungen als dieselbe Variante betrachtet.
  // Bei ungleichen FESTEN Teamgrößen sind A und B unterscheidbar.
  final canonicalMirrors = requestedSize == null || requestedSize * 2 == n;
  final remaining = canonicalMirrors ? n - 1 : n;
  final leftLength = remaining ~/ 2;
  final rightLength = remaining - leftLength;
  final left = _subsets(values, 0, leftLength);
  final right = _subsets(values, leftLength, rightLength);
  final rightBySize = List.generate(rightLength + 1, (_) => <_Subset>[]);
  for (final subset in right) {
    rightBySize[subset.size].add(subset);
  }
  for (final group in rightBySize) {
    group.sort((a, b) => a.sum.compareTo(b.sum));
  }

  final sizes = requestedSize == null
      ? [n ~/ 2, if (n.isOdd) (n + 1) ~/ 2]
      : [requestedSize];
  int? bestNumerator;
  int? bestDenominator;

  for (final sizeA in sizes) {
    final expected = sizeA * total;
    final denominator = sizeA * (n - sizeA);
    for (final subset in left) {
      final sizeB = sizeA - subset.size;
      if (sizeB < 0 || sizeB >= rightBySize.length) continue;
      final group = rightBySize[sizeB];
      if (group.isEmpty) continue;
      final wanted = expected - n * subset.sum;
      final insertion = _lowerBound(group, wanted, n);
      for (final index in [insertion - 1, insertion]) {
        if (index < 0 || index >= group.length) continue;
        final difference =
            (n * (subset.sum + group[index].sum) - expected).abs();
        if (bestNumerator == null ||
            difference * bestDenominator! < bestNumerator * denominator) {
          bestNumerator = difference;
          bestDenominator = denominator;
        }
      }
    }
  }

  final ranges = <_SplitRange>[];
  int runningCount = 0;
  for (final sizeA in sizes) {
    final denominator = sizeA * (n - sizeA);
    if (bestNumerator == null ||
        (bestNumerator * denominator) % bestDenominator! != 0) continue;
    final best = bestNumerator * denominator ~/ bestDenominator!;
    final expected = sizeA * total;
    for (final subset in left) {
      final sizeB = sizeA - subset.size;
      if (sizeB < 0 || sizeB >= rightBySize.length) continue;
      final group = rightBySize[sizeB];
      if (group.isEmpty) continue;
      final wanted = expected - n * subset.sum;
      final targets = best == 0 ? [wanted] : [wanted - best, wanted + best];
      for (final target in targets) {
        final start = _lowerBound(group, target, n);
        int end = start;
        while (end < group.length && n * group[end].sum == target) {
          end++;
        }
        if (end == start) continue;
        final length = end - start;
        ranges.add(_SplitRange(
          leftMask: subset.mask,
          rightSubsets: group,
          firstRight: start,
          lastRight: end,
          startIndex: runningCount,
          endIndex: runningCount + length,
        ));
        runningCount += length;
      }
    }
  }

  return OptimalTeamSplits._(
    weightedPlayers,
    leftLength,
    canonicalMirrors,
    ranges,
    runningCount,
  );
}

List<_Subset> _subsets(List<int> values, int offset, int length) {
  final result = List<_Subset>.filled(1 << length, const _Subset(0, 0, 0));
  for (int mask = 1; mask < result.length; mask++) {
    final bit = mask & -mask;
    final position = bit.bitLength - 1;
    final previous = result[mask ^ bit];
    result[mask] = _Subset(
      mask,
      previous.sum + values[offset + position],
      previous.size + 1,
    );
  }
  return result;
}

int _lowerBound(List<_Subset> sorted, int target, int multiplier) {
  int low = 0;
  int high = sorted.length;
  while (low < high) {
    final mid = (low + high) ~/ 2;
    if (sorted[mid].sum * multiplier < target) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  return low;
}
