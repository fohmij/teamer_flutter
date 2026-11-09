// VERSION 2026-11-09 (STAERKE-NAVIGATION): Pfeile wechseln nur eindeutige Staerkekombinationen.
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

  /// Kompakte Repräsentanten der optimalen Stärkekombinationen. Falls alle
  /// Spieler unterschiedliche Werte haben, sind die bisherigen Varianten
  /// bereits eindeutig und wir benötigen keine zusätzliche Liste.
  final _StrengthCatalog? _strengthCatalog;

  /// Identische effektive Siegquoten gelten als austauschbar.
  int get strengthCombinationCount => _strengthCatalog?.count ?? count;

  const OptimalTeamSplits._(
    this.players,
    this._leftLength,
    this._canonicalMirrors,
    this._ranges,
    this.count,
    this._strengthCatalog,
  );

  /// Gibt genau eine Spielerzuordnung je unterschiedlicher Wertverteilung
  /// zurück. Auch bei Millionen austauschbarer Spielerzuordnungen O(n).
  TeamSplitResult strengthResultAt(int index) {
    if (index < 0 || index >= strengthCombinationCount) {
      throw RangeError.range(index, 0, strengthCombinationCount - 1, 'index');
    }
    final catalog = _strengthCatalog;
    if (catalog == null) return resultAt(index);
    return _resultFromMask(catalog.masks[index]);
  }

  /// Ermittelt die angezeigte Stärkekombination der aktuellen Teams.
  /// Tauscht man nur Spieler mit identischen Werten, bleibt der Index gleich.
  int? strengthIndexForTeamA(Iterable<int> teamAPlayerIds) {
    final catalog = _strengthCatalog;
    if (catalog == null) return indexForTeamA(teamAPlayerIds);
    final ids = teamAPlayerIds.toSet();
    int mask = 0;
    for (int i = 0; i < players.length; i++) {
      if (ids.contains(players[i].player.id)) mask |= 1 << i;
    }
    if (_countBits(mask) != ids.length) return null;

    int selectedKey = 0;
    int mirrorKey = 0;
    int multiplier = 1;
    for (int i = 0; i < catalog.groupMasks.length; i++) {
      final selected = _countBits(mask & catalog.groupMasks[i]);
      selectedKey += selected * multiplier;
      mirrorKey += (catalog.groupSizes[i] - selected) * multiplier;
      multiplier *= catalog.groupSizes[i] + 1;
    }
    // Bei gleich grossen Teams ist auch die vertauschte A/B-Orientierung
    // dieselbe Stärkekombination. Andere Teamgrössen bleiben unverändert.
    return catalog.indexByKey[selectedKey] ??
        (_canonicalMirrors ? catalog.indexByKey[mirrorKey] : null);
  }

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

    return _resultFromMask(selectedMask);
  }

  TeamSplitResult _resultFromMask(int selectedMask) {
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

/// Ein Repräsentant pro effektiver Stärkekombination; keine doppelten
/// Personenbelegungen für Spieler mit gleichem Wert.
class _StrengthCatalog {
  final List<int> masks;
  final Map<int, int> indexByKey;
  final List<int> groupMasks;
  final List<int> groupSizes;

  const _StrengthCatalog({
    required this.masks,
    required this.indexByKey,
    required this.groupMasks,
    required this.groupSizes,
  });

  int get count => masks.length;
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
    return OptimalTeamSplits._(weightedPlayers, 0, false, const [], 0, null);
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
      null,
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

  // A/B-Spiegelungen muessen nur bei GLEICH grossen Teams entfernt
  // werden: Bei ungerader Spielerzahl ist Team A bei der Ersteinteilung
  // immer die kleinere Gruppe (z. B. 4 / 5). Die gespiegelte Aufteilung
  // (5 / 4) wird gar nicht erzeugt. Dadurch bleibt der Teamname stabil,
  // waehrend alle unterschiedlichen optimalen Aufteilungen erhalten bleiben.
  // Bei einer spaeteren Optimierung ist die vorgegebene A-Groesse bindend.
  final canonicalMirrors = (requestedSize ?? (n ~/ 2)) * 2 == n;
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

  // Ausschliesslich diese Team-A-Groesse betrachten. Fuer ungerade n
  // entspricht jede A/B-Spiegelung bereits exakt einer dieser Varianten.
  final sizes = [requestedSize ?? (n ~/ 2)];
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

  final strengthCatalog = _buildStrengthCatalog(
    values: values,
    teamASize: sizes.single,
    canonicalMirrors: canonicalMirrors,
    bestNumerator: bestNumerator!,
    bestDenominator: bestDenominator!,
    ranges: ranges,
    leftLength: leftLength,
    variantCount: runningCount,
  );

  return OptimalTeamSplits._(
    weightedPlayers,
    leftLength,
    canonicalMirrors,
    ranges,
    runningCount,
    strengthCatalog,
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

/// Berechnet je optimaler Stärkekombination genau EINE repräsentative
/// Team-A-Auswahl. Damit müssen die Pfeiltasten niemals alle Varianten aus
/// Vertauschungen gleich starker Spieler durchlaufen.
/// Bei ausschließlich verschiedenen Werten ist keine Zusatzliste nötig:
/// jede optimale Spieleraufteilung ist schon eine Stärkekombination.
_StrengthCatalog? _buildStrengthCatalog({
  required List<int> values,
  required int teamASize,
  required bool canonicalMirrors,
  required int bestNumerator,
  required int bestDenominator,
  required List<_SplitRange> ranges,
  required int leftLength,
  required int variantCount,
}) {
  if (variantCount == 0) return null;
  final n = values.length;
  final countsByValue = <int, int>{};
  final maskByValue = <int, int>{};
  for (int i = 0; i < n; i++) {
    final value = values[i];
    countsByValue[value] = (countsByValue[value] ?? 0) + 1;
    maskByValue[value] = (maskByValue[value] ?? 0) | (1 << i);
  }
  if (countsByValue.length == n) return null;

  final strengths = countsByValue.keys.toList()..sort();
  final groupSizes = strengths.map((v) => countsByValue[v]!).toList();
  final groupMasks = strengths.map((v) => maskByValue[v]!).toList();
  final anchorStrength = canonicalMirrors ? values.last : null;
  final anchorIndex = canonicalMirrors
      ? strengths.indexOf(anchorStrength!)
      : -1;
  final anchorMask = canonicalMirrors ? (1 << (n - 1)) : 0;
  final total = values.fold<int>(0, (a, b) => a + b);
  final denominator = teamASize * (n - teamASize);
  final best = bestNumerator * denominator ~/ bestDenominator;
  final expected = teamASize * total;

  final masks = <int>[];
  final indexByKey = <int, int>{};

  int combinationKey(List<int> chosenCounts) {
    int key = 0;
    int multiplier = 1;
    for (int i = 0; i < groupSizes.length; i++) {
      key += chosenCounts[i] * multiplier;
      multiplier *= groupSizes[i] + 1;
    }
    return key;
  }

  // Bei gleich grossen Teams bleiben die gespiegelten Wertverteilungen
  // eine einzige Kombination, auch wenn der Ankerwert mehrfach vorkommt.
  bool isCanonicalOrientation(List<int> chosenCounts) {
    if (!canonicalMirrors || chosenCounts[anchorIndex] == 0) return true;
    for (int i = 0; i < groupSizes.length; i++) {
      final difference = 2 * chosenCounts[i] - groupSizes[i];
      if (difference < 0) return true;
      if (difference > 0) return false;
    }
    return true;
  }

  void addRepresentative(int mask, List<int> chosenCounts) {
    final key = combinationKey(chosenCounts);
    if (indexByKey.containsKey(key)) return;
    indexByKey[key] = masks.length;
    masks.add(mask);
  }

  // Anstatt Millionen Personenbelegungen zu speichern, werden zunächst
  // ausschließlich die Anzahlen je tatsächlich verschiedenem Wert gewählt.
  int combinationUpperBound = 1;
  for (final size in groupSizes) {
    combinationUpperBound *= size + 1;
    if (combinationUpperBound > 1000000) break;
  }
  if (combinationUpperBound <= 1000000) {
    final groupCount = groupSizes.length;
    final remainingPlaces = List<int>.filled(groupCount + 1, 0);
    for (int i = groupCount - 1; i >= 0; i--) {
      remainingPlaces[i] = remainingPlaces[i + 1] + groupSizes[i];
    }
    final chosenCounts = List<int>.filled(groupCount, 0);

    int canonicalMask() {
      int selectedMask = 0;
      for (int i = 0; i < groupCount; i++) {
        int available = groupMasks[i] & ~anchorMask;
        int left = chosenCounts[i];
        while (left > 0 && available != 0) {
          final lowestBit = available & -available;
          selectedMask |= lowestBit;
          available ^= lowestBit;
          left--;
        }
        assert(left == 0);
      }
      return selectedMask;
    }

    void search(int i, int seatsLeft, int sum) {
      if (i == groupCount) {
        if (seatsLeft == 0 &&
            (n * sum - expected).abs() == best &&
            isCanonicalOrientation(chosenCounts)) {
          addRepresentative(canonicalMask(), chosenCounts);
        }
        return;
      }
      final available = groupSizes[i] - (i == anchorIndex ? 1 : 0);
      final minChosen = seatsLeft > remainingPlaces[i + 1]
          ? seatsLeft - remainingPlaces[i + 1]
          : 0;
      final maxChosen = seatsLeft < available ? seatsLeft : available;
      for (int k = minChosen; k <= maxChosen; k++) {
        chosenCounts[i] = k;
        search(i + 1, seatsLeft - k, sum + k * strengths[i]);
      }
      chosenCounts[i] = 0;
    }

    search(0, teamASize, 0);
  } else {
    // Für fast ausschließlich verschiedene Werte kann die vorhandene
    // Meet-in-the-Middle-Liste schneller sein als alle Wertemengen zu prüfen.
    // Nur die erste kanonische Auswahl jedes gleichen Wertes wird übernommen.
    final repeatedMasks = groupMasks
        .map((mask) => mask & ~anchorMask)
        .where((mask) => (mask & (mask - 1)) != 0)
        .toList();
    final chosenCounts = List<int>.filled(groupSizes.length, 0);
    for (final range in ranges) {
      for (int j = range.firstRight; j < range.lastRight; j++) {
        final selectedMask =
            range.leftMask | (range.rightSubsets[j].mask << leftLength);
        bool representative = true;
        for (final groupMask in repeatedMasks) {
          final selected = selectedMask & groupMask;
          if (selected != (groupMask & ((1 << selected.bitLength) - 1))) {
            representative = false;
            break;
          }
        }
        if (!representative) continue;
        for (int i = 0; i < groupMasks.length; i++) {
          chosenCounts[i] = _countBits(selectedMask & groupMasks[i]);
        }
        if (!isCanonicalOrientation(chosenCounts)) continue;
        addRepresentative(selectedMask, chosenCounts);
      }
    }
  }

  return _StrengthCatalog(
    masks: masks,
    indexByKey: indexByKey,
    groupMasks: groupMasks,
    groupSizes: groupSizes,
  );
}

int _countBits(int mask) {
  int count = 0;
  while (mask != 0) {
    mask &= mask - 1;
    count++;
  }
  return count;
}
