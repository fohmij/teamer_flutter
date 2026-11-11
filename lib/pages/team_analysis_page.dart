// VERSION 2026-11-12 (FIX): Korrekte Übergabe der Legendenparameter; einklappbare Variantenlegende.
// VERSION 2026-11-11 (SHUFFLE): Gleich starke Spieler innerhalb der aktuellen Staerkekombination mischen.
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:teamer/app_theme/app_theme.dart';
import 'package:teamer/database/database_services.dart';
import 'package:teamer/database/player.dart';
import 'package:teamer/database/team_generator.dart';
import 'package:teamer/services/app_settings_controller.dart';

class TeamAnalysisPage extends StatefulWidget {
  const TeamAnalysisPage({super.key});

  @override
  State<TeamAnalysisPage> createState() => _TeamAnalysisPageState();
}

class _TeamAnalysisPageState extends State<TeamAnalysisPage> {
  final DatabaseService _databaseService = DatabaseService.instance;
  final Random _random = Random();

  bool _loading = true;
  final Set<int> _updatingPlayerIds = <int>{};
  List<WeightedPlayer> _teamA = [];
  List<WeightedPlayer> _teamB = [];
  List<Player> _availablePlayers = [];

  OptimalTeamSplits? _alternatives;
  OptimalTeamSplits? _passedAlternatives;
  int? _alternativeIndex;
  bool _calculatingAlternatives = false;
  bool _applyingAlternative = false;
  bool _shuffling = false;
  bool _variantsExpanded = false;
  bool _statsLegendExpanded = false;
  bool _variantsLegendExpanded = false;
  bool _reoptimizing = false;
  bool _readRouteArguments = false;
  int _calculationVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_readRouteArguments) return;
    _readRouteArguments = true;
    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments is OptimalTeamSplits) {
      // Die Startvariante wurde bereits beim Generieren berechnet.
      _passedAlternatives = arguments;
    }
  }

  Future<void> _loadTeams() async {
    final players = await _databaseService.getPlayersWithStatsFromGames();

    final teamA = players
        .where((player) => player.status == 1 && player.team == 0)
        .map(_toWeightedPlayer)
        .toList();
    final teamB = players
        .where((player) => player.status == 1 && player.team == 1)
        .map(_toWeightedPlayer)
        .toList();
    final availablePlayers = players
        .where((player) => player.status == 0)
        .toList();

    _sortWeightedPlayers(teamA);
    _sortWeightedPlayers(teamB);
    _sortPlayers(availablePlayers);

    if (!mounted) return;
    setState(() {
      _teamA = teamA;
      _teamB = teamB;
      _availablePlayers = availablePlayers;
      _loading = false;
    });

    final precomputed = _passedAlternatives;
    _passedAlternatives = null;
    unawaited(_refreshAlternatives(precomputed: precomputed));
  }

  /// Ermittelt alle gleichwertig besten Aufteilungen für die aktuell
  /// zugeteilten Spieler. Ältere Berechnungen werden nicht mehr übernommen.
  Future<void> _refreshAlternatives({OptimalTeamSplits? precomputed}) async {
    final version = ++_calculationVersion;
    final players = [
      ..._teamA,
      ..._teamB,
    ].map((entry) => entry.player).toList();
    final playerIds = players.map((p) => p.id).toSet();
    final minGames = appSettingsController.value.minGamesForFullWeight;

    setState(() {
      _calculatingAlternatives = true;
      _alternativeIndex = null;
    });

    try {
      final canReuse =
          precomputed != null &&
          precomputed.players.length == players.length &&
          precomputed.resultAt(0).teamA.length == _teamA.length &&
          precomputed.players.every(
            (entry) =>
                playerIds.contains(entry.player.id) &&
                entry.usesFallbackWeight ==
                    (entry.player.attendance < minGames),
          );

      final alternatives = canReuse
          ? precomputed!
          : await findOptimalTeamSplits(
              players,
              minGamesForFullWeight: minGames,
              teamASize: _teamA.length,
            );
      if (!mounted || version != _calculationVersion) return;

      setState(() {
        _alternatives = alternatives;
        _alternativeIndex = alternatives.strengthIndexForTeamA(
          _teamA.map((entry) => entry.player.id),
        );
        _calculatingAlternatives = false;
      });
    } catch (error) {
      if (!mounted || version != _calculationVersion) return;
      setState(() {
        _alternatives = null;
        _calculatingAlternatives = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Optimale Aufteilungen konnten nicht berechnet werden: $error',
          ),
        ),
      );
    }
  }

  /// Berechnet die beste neue Zuordnung mit der AKTUELLEN Anzahl
  /// Spieler pro Team. Auch ungleiche Teamgrößen bleiben erhalten.
  Future<void> _reoptimizeTeams() async {
    if (_reoptimizing ||
        _applyingAlternative ||
        _calculatingAlternatives ||
        _updatingPlayerIds.isNotEmpty)
      return;

    final teamASize = _teamA.length;
    final players = [
      ..._teamA,
      ..._teamB,
    ].map((entry) => entry.player).toList();
    if (players.isEmpty) return;
    final version = ++_calculationVersion;
    setState(() {
      _reoptimizing = true;
      _calculatingAlternatives = true;
    });

    try {
      final alternatives = await findOptimalTeamSplits(
        players,
        minGamesForFullWeight:
            appSettingsController.value.minGamesForFullWeight,
        teamASize: teamASize,
      );
      if (!mounted || version != _calculationVersion || alternatives.count == 0)
        return;
      final result = alternatives.strengthResultAt(0);
      await _databaseService.saveTeamSplit(result);
      if (!mounted || version != _calculationVersion) return;
      final newTeamA = List<WeightedPlayer>.from(result.teamA);
      final newTeamB = List<WeightedPlayer>.from(result.teamB);
      _sortWeightedPlayers(newTeamA);
      _sortWeightedPlayers(newTeamB);
      setState(() {
        _teamA = newTeamA;
        _teamB = newTeamB;
        _alternatives = alternatives;
        _alternativeIndex = 0;
      });
    } catch (error) {
      if (!mounted || version != _calculationVersion) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Optimierung fehlgeschlagen: $error')),
      );
    } finally {
      if (mounted && version == _calculationVersion) {
        setState(() {
          _reoptimizing = false;
          _calculatingAlternatives = false;
        });
      }
    }
  }

  /// Wechselt sofort zur nächsten/vorherigen unterschiedlichen Stärkekombination und
  /// speichert sämtliche Teamzuordnungen in einer Datenbanktransaktion.
  Future<void> _showAlternative(int direction) async {
    final alternatives = _alternatives;
    if (_reoptimizing ||
        _applyingAlternative ||
        _calculatingAlternatives ||
        _updatingPlayerIds.isNotEmpty ||
        alternatives == null ||
        alternatives.strengthCombinationCount == 0) {
      return;
    }

    final current = _alternativeIndex;
    final strengthCount = alternatives.strengthCombinationCount;
    final nextIndex = current == null
        ? (direction > 0 ? 0 : strengthCount - 1)
        : (current + direction + strengthCount) % strengthCount;
    if (current == nextIndex) return;

    final previousTeamA = _teamA;
    final previousTeamB = _teamB;
    final teamASize = previousTeamA.length;
    final canonical = alternatives.strengthResultAt(nextIndex);

    // Bei ungleichen Teamgroessen ist die bisherige Groesse von Team A
    // verbindlich: Niemals A und B nur aufgrund des Referenzspielers tauschen.
    // Bei gleich grossen Teams bleibt wie bisher der Referenzspieler auf
    // seiner bisherigen A/B-Seite, sodass reine Spiegelungen nicht wechseln.
    final keepReferenceSide =
        canonical.teamA.length == canonical.teamB.length &&
        previousTeamA.any(
          (entry) => entry.player.id == alternatives.players.last.player.id,
        );
    final swapTeams = canonical.teamA.length != teamASize || keepReferenceSide;
    final result = swapTeams
        ? TeamSplitResult(teamA: canonical.teamB, teamB: canonical.teamA)
        : canonical;
    if (result.teamA.length != teamASize ||
        result.teamB.length != previousTeamB.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Die Teamgrößen konnten nicht beibehalten werden.'),
        ),
      );
      return;
    }
    final nextTeamA = List<WeightedPlayer>.from(result.teamA);
    final nextTeamB = List<WeightedPlayer>.from(result.teamB);
    _sortWeightedPlayers(nextTeamA);
    _sortWeightedPlayers(nextTeamB);

    setState(() {
      _applyingAlternative = true;
      _teamA = nextTeamA;
      _teamB = nextTeamB;
      _alternativeIndex = nextIndex;
    });

    try {
      await _databaseService.saveTeamSplit(result);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _teamA = previousTeamA;
        _teamB = previousTeamB;
        _alternativeIndex = current;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Variante konnte nicht gespeichert werden: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _applyingAlternative = false);
      }
    }
  }

  // Dieselbe Genauigkeit wie die Staerkekombinationen im Teamgenerator.
  // So gelten auch mathematisch gleiche Werte trotz Rundungsfehlern als gleich.
  int _strengthKey(WeightedPlayer entry) =>
      (entry.effectiveWinRate * 1000000000000).round();

  /// Shuffle ist nur moeglich, wenn sich mindestens zwei Spieler mit
  /// gleicher effektiver Staerke in unterschiedlichen Teams befinden.
  /// Ein reiner A/B-Namenstausch bei genau zwei Spielern zaehlt nicht.
  bool get _canShuffleTeams {
    if (_teamA.isEmpty ||
        _teamB.isEmpty ||
        (_teamA.length == 1 && _teamB.length == 1)) {
      return false;
    }
    final strengthsA = _teamA.map(_strengthKey).toSet();
    return _teamB.any((entry) => strengthsA.contains(_strengthKey(entry)));
  }

  /// Mischt die konkreten Spielerzuordnungen innerhalb der aktuellen
  /// Staerkekombination. Die Anzahl jeder Staerke pro Team bleibt exakt gleich.
  /// Es wird weder die Staerkekombination gewechselt noch neu optimiert.
  Future<void> _shuffleTeams() async {
    if (_reoptimizing ||
        _applyingAlternative ||
        _calculatingAlternatives ||
        _updatingPlayerIds.isNotEmpty ||
        !_canShuffleTeams) {
      return;
    }

    final previousTeamA = _teamA;
    final previousTeamB = _teamB;
    final previousAIds = previousTeamA.map((e) => e.player.id).toSet();
    final previousBIds = previousTeamB.map((e) => e.player.id).toSet();

    final playersByStrength = <int, List<WeightedPlayer>>{};
    final sizeAByStrength = <int, int>{};
    for (final entry in previousTeamA) {
      final key = _strengthKey(entry);
      playersByStrength.putIfAbsent(key, () => []).add(entry);
      sizeAByStrength[key] = (sizeAByStrength[key] ?? 0) + 1;
    }
    for (final entry in previousTeamB) {
      playersByStrength.putIfAbsent(_strengthKey(entry), () => []).add(entry);
    }

    TeamSplitResult? shuffled;
    // Zufallsbelegung aller Staerkegruppen: Weder die alte Aufteilung noch
    // eine reine A/B-Spiegelung darf als neue Variante erscheinen.
    for (var attempt = 0; attempt < 32 && shuffled == null; attempt++) {
      final nextA = <WeightedPlayer>[];
      final nextB = <WeightedPlayer>[];
      for (final group in playersByStrength.entries) {
        final mixed = List<WeightedPlayer>.from(group.value)..shuffle(_random);
        final countA = sizeAByStrength[group.key] ?? 0;
        nextA.addAll(mixed.take(countA));
        nextB.addAll(mixed.skip(countA));
      }

      final newAIds = nextA.map((entry) => entry.player.id).toSet();
      final unchanged = previousAIds.containsAll(newAIds);
      final mirrored =
          previousTeamA.length == previousTeamB.length &&
          previousBIds.containsAll(newAIds);
      if (!unchanged && !mirrored) {
        shuffled = TeamSplitResult(teamA: nextA, teamB: nextB);
      }
    }

    // Garantierter Fallback bei zufaellig wiederholtem Ziehen der alten
    // Belegung: ein Paar identisch starker Spieler wird gezielt getauscht.
    if (shuffled == null) {
      final swappable = playersByStrength.keys
          .where(
            (key) =>
                previousTeamA.any((entry) => _strengthKey(entry) == key) &&
                previousTeamB.any((entry) => _strengthKey(entry) == key),
          )
          .toList();
      final key = swappable[_random.nextInt(swappable.length)];
      final candidatesA = previousTeamA
          .where((entry) => _strengthKey(entry) == key)
          .toList();
      final candidatesB = previousTeamB
          .where((entry) => _strengthKey(entry) == key)
          .toList();
      final fromA = candidatesA[_random.nextInt(candidatesA.length)];
      final fromB = candidatesB[_random.nextInt(candidatesB.length)];
      shuffled = TeamSplitResult(
        teamA: [
          ...previousTeamA.where((entry) => entry.player.id != fromA.player.id),
          fromB,
        ],
        teamB: [
          ...previousTeamB.where((entry) => entry.player.id != fromB.player.id),
          fromA,
        ],
      );
    }

    final nextTeamA = List<WeightedPlayer>.from(shuffled.teamA);
    final nextTeamB = List<WeightedPlayer>.from(shuffled.teamB);
    _sortWeightedPlayers(nextTeamA);
    _sortWeightedPlayers(nextTeamB);

    setState(() {
      _applyingAlternative = true;
      _shuffling = true;
      _teamA = nextTeamA;
      _teamB = nextTeamB;
      // _alternativeIndex bleibt erhalten: dieselbe Staerkekombination.
    });

    try {
      await _databaseService.saveTeamSplit(shuffled);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _teamA = previousTeamA;
        _teamB = previousTeamB;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Shuffle konnte nicht gespeichert werden: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _applyingAlternative = false;
          _shuffling = false;
        });
      }
    }
  }

  WeightedPlayer _toWeightedPlayer(Player player) {
    final minGames = appSettingsController.value.minGamesForFullWeight;
    final usesFallbackWeight = player.attendance < minGames;

    return WeightedPlayer(
      player: player,
      effectiveWinRate: usesFallbackWeight ? 0.5 : player.winRate,
      usesFallbackWeight: usesFallbackWeight,
    );
  }

  TeamSplitResult get _currentResult {
    return TeamSplitResult(teamA: _teamA, teamB: _teamB);
  }

  void _sortPlayers(List<Player> players) {
    players.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
  }

  void _sortWeightedPlayers(List<WeightedPlayer> players) {
    players.sort(
      (a, b) =>
          a.player.name.toLowerCase().compareTo(b.player.name.toLowerCase()),
    );
  }

  Future<void> _confirmAndRemovePlayer(WeightedPlayer weightedPlayer) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final player = weightedPlayer.player;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: isDark ? AppTheme.grey700 : Colors.white),
          borderRadius: const BorderRadius.all(Radius.circular(8.0)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _DeleteDialogTitle(),
            const Padding(padding: EdgeInsets.only(top: 6.0), child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30.0),
              child: Text.rich(
                TextSpan(
                  text: 'Soll ',
                  style: Theme.of(context).textTheme.bodyMedium,
                  children: [
                    TextSpan(
                      text: player.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(
                      text: ' wirklich aus dem Team entfernt werden?',
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 12.0),
              child: Divider(),
            ),
            _DeleteDialogActions(
              onCancel: () => Navigator.of(dialogContext).pop(false),
              onDelete: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    await _removePlayer(weightedPlayer);
  }

  Future<void> _removePlayer(WeightedPlayer weightedPlayer) async {
    final player = weightedPlayer.player;
    if (_reoptimizing ||
        _applyingAlternative ||
        _updatingPlayerIds.contains(player.id))
      return;

    setState(() {
      _updatingPlayerIds.add(player.id);
    });

    try {
      await _databaseService.updatePlayerAssignment(player.id, status: 0);

      if (!mounted) return;
      setState(() {
        _teamA.removeWhere((entry) => entry.player.id == player.id);
        _teamB.removeWhere((entry) => entry.player.id == player.id);
        _availablePlayers.removeWhere((entry) => entry.id == player.id);
        _availablePlayers.add(player);
        _sortPlayers(_availablePlayers);
      });
      unawaited(_refreshAlternatives());
    } finally {
      if (mounted) {
        setState(() {
          _updatingPlayerIds.remove(player.id);
        });
      }
    }
  }

  // Wird sowohl beim Hinzufügen als auch beim direkten Teamwechsel verwendet.
  // Die Zuordnung wird gespeichert und die angezeigten Kennzahlen aktualisiert.
  Future<void> _addPlayerToTeam(Player player, int team) async {
    if (_reoptimizing ||
        _applyingAlternative ||
        _updatingPlayerIds.contains(player.id))
      return;

    setState(() {
      _updatingPlayerIds.add(player.id);
    });

    try {
      await _databaseService.updatePlayerAssignment(
        player.id,
        status: 1,
        team: team,
      );

      if (!mounted) return;

      final weightedPlayer = _toWeightedPlayer(player);

      setState(() {
        _availablePlayers.removeWhere((entry) => entry.id == player.id);
        _teamA.removeWhere((entry) => entry.player.id == player.id);
        _teamB.removeWhere((entry) => entry.player.id == player.id);

        if (team == 0) {
          _teamA.add(weightedPlayer);
          _sortWeightedPlayers(_teamA);
        } else {
          _teamB.add(weightedPlayer);
          _sortWeightedPlayers(_teamB);
        }
      });
      unawaited(_refreshAlternatives());
    } finally {
      if (mounted) {
        setState(() {
          _updatingPlayerIds.remove(player.id);
        });
      }
    }
  }

  // Direkter Teamwechsel ohne Dialog. Die Anzeige wechselt sofort,
  // während die neue Zuordnung parallel in der Datenbank gespeichert wird.
  Future<void> _switchPlayerTeam(
    WeightedPlayer weightedPlayer,
    int targetTeam,
  ) async {
    final player = weightedPlayer.player;
    if (_reoptimizing ||
        _applyingAlternative ||
        _updatingPlayerIds.contains(player.id))
      return;

    final originalTeam = _teamA.any((entry) => entry.player.id == player.id)
        ? 0
        : 1;
    if (originalTeam == targetTeam) return;

    setState(() {
      _updatingPlayerIds.add(player.id);
      _teamA.removeWhere((entry) => entry.player.id == player.id);
      _teamB.removeWhere((entry) => entry.player.id == player.id);
      final destination = targetTeam == 0 ? _teamA : _teamB;
      destination.add(weightedPlayer);
      _sortWeightedPlayers(destination);
      _alternativeIndex = _alternatives?.strengthIndexForTeamA(
        _teamA.map((entry) => entry.player.id),
      );
    });

    try {
      await _databaseService.updatePlayerAssignment(
        player.id,
        status: 1,
        team: targetTeam,
      );
      if (mounted) unawaited(_refreshAlternatives());
    } catch (error) {
      if (!mounted) return;
      // Bei einem Speicherfehler wird der Wechsel zurückgenommen.
      setState(() {
        _teamA.removeWhere((entry) => entry.player.id == player.id);
        _teamB.removeWhere((entry) => entry.player.id == player.id);
        final original = originalTeam == 0 ? _teamA : _teamB;
        original.add(weightedPlayer);
        _sortWeightedPlayers(original);
        _alternativeIndex = _alternatives?.strengthIndexForTeamA(
          _teamA.map((entry) => entry.player.id),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Teamwechsel fehlgeschlagen: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingPlayerIds.remove(player.id);
        });
      }
    }
  }

  Future<void> _showAddPlayerSheet({
    required int team,
    required String title,
    required Color color,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_availablePlayers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keine weiteren Spieler verfügbar.')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final availablePlayers = List<Player>.from(_availablePlayers);

            return DraggableScrollableSheet(
              initialChildSize: 0.72,
              minChildSize: 0.4,
              maxChildSize: 0.92,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.backgroundColorDark
                        : AppTheme.backgroundColorLight,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppTheme.grey600.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 10, 12),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 36,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$title Spieler hinzufügen',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge,
                                  ),
                                  Text(
                                    '${availablePlayers.length} nicht ausgewählt',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(color: AppTheme.grey600),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Schließen',
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: availablePlayers.isEmpty
                            ? Center(
                                child: Text(
                                  'Keine weiteren Spieler verfügbar.',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              )
                            : ListView.separated(
                                controller: scrollController,
                                itemCount: availablePlayers.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  indent: 18,
                                  endIndent: 18,
                                  color: AppTheme.grey400.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                                itemBuilder: (context, index) {
                                  final player = availablePlayers[index];
                                  final isUpdating = _updatingPlayerIds
                                      .contains(player.id);

                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 0,
                                    ),
                                    title: Text(
                                      player.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                    subtitle: Text(
                                      'S: ${player.attendance} | WR: ${(player.winRate * 100).toStringAsFixed(1)}%',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: AppTheme.grey600,
                                            fontSize: 12,
                                          ),
                                    ),
                                    trailing: isUpdating
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : SizedBox(
                                            width: 38,
                                            height: 38,
                                            child: IconButton(
                                              tooltip: 'Zu $title hinzufügen',
                                              style: TextButton.styleFrom(
                                                backgroundColor: color,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                              ),
                                              onPressed: () async {
                                                await _addPlayerToTeam(
                                                  player,
                                                  team,
                                                );
                                                if (!sheetContext.mounted) {
                                                  return;
                                                }
                                                setSheetState(() {});
                                              },
                                              icon: const Icon(
                                                Icons.add,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                    onTap: isUpdating
                                        ? null
                                        : () async {
                                            await _addPlayerToTeam(
                                              player,
                                              team,
                                            );
                                            if (!sheetContext.mounted) return;
                                            setSheetState(() {});
                                          },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _openSettings() async {
    if (_reoptimizing || _applyingAlternative || _updatingPlayerIds.isNotEmpty)
      return;
    await Navigator.pushNamed(context, '/settings');
    if (!mounted) return;

    // Nach einer Änderung der Mindestspiele werden alle Varianten
    // mit den neuen Gewichten neu berechnet.
    _passedAlternatives = null;
    await _loadTeams();
  }

  void _openTeamPage() {
    if (_reoptimizing || _applyingAlternative || _updatingPlayerIds.isNotEmpty)
      return;
    Navigator.pushReplacementNamed(
      context,
      '/team',
      arguments: const TeamPageArgs(showAnalysisButton: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team-Analyse'),
        titleTextStyle: Theme.of(context).textTheme.titleLarge,
        backgroundColor: isDark
            ? AppTheme.navigationBarDark
            : AppTheme.navigationBarLight,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        children: [
                          _SummaryCard(
                            result: _currentResult,
                            onOpenSettings: _openSettings,
                            alternatives: _alternatives,
                            alternativeIndex: _alternativeIndex,
                            calculating: _calculatingAlternatives,
                            switching:
                                _applyingAlternative ||
                                _updatingPlayerIds.isNotEmpty,
                            onPrevious: () => _showAlternative(-1),
                            onNext: () => _showAlternative(1),
                            expanded: _variantsExpanded,
                            onToggleExpanded: () => setState(
                              () => _variantsExpanded = !_variantsExpanded,
                            ),
                            variantsLegendExpanded: _variantsLegendExpanded,
                            onToggleVariantsLegend: () => setState(
                              () => _variantsLegendExpanded =
                                  !_variantsLegendExpanded,
                            ),
                            statsLegendExpanded: _statsLegendExpanded,
                            onToggleStatsLegend: () => setState(
                              () =>
                                  _statsLegendExpanded = !_statsLegendExpanded,
                            ),
                            onReoptimize: _reoptimizeTeams,
                            reoptimizing: _reoptimizing,
                            onShuffle: _shuffleTeams,
                            canShuffle: _canShuffleTeams,
                            shuffling: _shuffling,
                          ),
                          const SizedBox(height: 14),
                          _TeamAnalysisCard(
                            title: 'Team A',
                            players: _teamA,
                            color: AppTheme.btnBlue3,
                            updatingPlayerIds: _updatingPlayerIds,
                            onRemovePlayer: _confirmAndRemovePlayer,
                            onSwitchPlayer: (player) =>
                                _switchPlayerTeam(player, 1),
                            onAddPlayer: () => _showAddPlayerSheet(
                              team: 0,
                              title: 'Team A',
                              color: AppTheme.btnBlue3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _TeamAnalysisCard(
                            title: 'Team B',
                            players: _teamB,
                            color: AppTheme.btnBlue2,
                            updatingPlayerIds: _updatingPlayerIds,
                            onRemovePlayer: _confirmAndRemovePlayer,
                            onSwitchPlayer: (player) =>
                                _switchPlayerTeam(player, 0),
                            onAddPlayer: () => _showAddPlayerSheet(
                              team: 1,
                              title: 'Team B',
                              color: AppTheme.btnBlue2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: TextButton(
                        onPressed: _openTeamPage,
                        child: Text(
                          'Teams anzeigen',
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class TeamPageArgs {
  final bool showAnalysisButton;

  const TeamPageArgs({required this.showAnalysisButton});
}

class _SummaryCard extends StatelessWidget {
  final TeamSplitResult result;
  final VoidCallback onOpenSettings;
  final OptimalTeamSplits? alternatives;
  final int? alternativeIndex;
  final bool calculating;
  final bool switching;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final bool variantsLegendExpanded;
  final VoidCallback onToggleVariantsLegend;
  final bool statsLegendExpanded;
  final VoidCallback onToggleStatsLegend;
  final VoidCallback onReoptimize;
  final bool reoptimizing;
  final VoidCallback onShuffle;
  final bool canShuffle;
  final bool shuffling;

  const _SummaryCard({
    required this.result,
    required this.onOpenSettings,
    required this.alternatives,
    required this.alternativeIndex,
    required this.calculating,
    required this.switching,
    required this.onPrevious,
    required this.onNext,
    required this.expanded,
    required this.onToggleExpanded,
    required this.variantsLegendExpanded,
    required this.onToggleVariantsLegend,
    required this.statsLegendExpanded,
    required this.onToggleStatsLegend,
    required this.onReoptimize,
    required this.reoptimizing,
    required this.onShuffle,
    required this.canShuffle,
    required this.shuffling,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final minGames = appSettingsController.value.minGamesForFullWeight;
    final playerCount = result.teamA.length + result.teamB.length;
    final effectiveTotal = [
      ...result.teamA,
      ...result.teamB,
    ].fold<double>(0.0, (sum, player) => sum + player.effectiveWinRate);
    final totalAverage = playerCount == 0 ? 0.0 : effectiveTotal / playerCount;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14, 12, 14, expanded ? 12 : 6),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.grey700 : AppTheme.cardColorLight,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.balance, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Intelligente Zuteilung',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onOpenSettings,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text(
                            'Unter $minGames Spielen = Wert 0.5 (default Wert)',
                            style: Theme.of(
                              context,
                            ).textTheme.labelSmall?.copyWith(fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Fünf Kennzahlen in EINEM Chip: Tippen klappt die Legende auf.
          // Gleicher Material-/InkWell-/AnimatedCrossFade-Aufbau wie die
          // Tabellenlegende auf der Seite "Alle Stats".
          Material(
            color: isDark ? AppTheme.navigationBarDark : Colors.white,
            borderRadius: BorderRadius.circular(4),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onToggleStatsLegend,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryMetric(
                            label: 'Spieler',
                            value: playerCount.toString(),
                          ),
                        ),
                        Expanded(
                          child: _SummaryMetric(
                            label: 'Ø A',
                            value: (result.averageTeamA * 100).toStringAsFixed(
                              1,
                            ),
                          ),
                        ),
                        Expanded(
                          child: _SummaryMetric(
                            label: 'Diff.',
                            value: (result.difference * 100).toStringAsFixed(1),
                          ),
                        ),
                        Expanded(
                          child: _SummaryMetric(
                            label: 'Ø B',
                            value: (result.averageTeamB * 100).toStringAsFixed(
                              1,
                            ),
                          ),
                        ),
                        Expanded(
                          child: _SummaryMetric(
                            label: 'Ø Ges.',
                            value: (totalAverage * 100).toStringAsFixed(1),
                          ),
                        ),
                        const SizedBox(width: 2),
                        AnimatedRotation(
                          turns: statsLegendExpanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeInOut,
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            size: 19,
                            color: isDark ? AppTheme.grey300 : AppTheme.grey700,
                          ),
                        ),
                      ],
                    ),
                    AnimatedCrossFade(
                      firstChild: const SizedBox(width: double.infinity),
                      secondChild: _buildMetricLegend(
                        context,
                        isDark,
                        minGames,
                      ),
                      crossFadeState: statsLegendExpanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 180),
                      sizeCurve: Curves.easeInOut,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggleExpanded,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: expanded ? 6 : 3),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        calculating
                            ? 'Optimale Varianten werden berechnet …'
                            : '${alternatives?.count ?? 0} optimale Varianten',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (calculating)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    Icon(expanded ? Icons.expand_less : Icons.expand_more),
                  ],
                ),
              ),
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 5),
            // Navigation und die beiden Aktionen rechts uebereinander.
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    alternativeIndex == null
                        ? 'Manuelle Aufteilung'
                        : 'Stärkekomb. ${alternativeIndex! + 1} / ${alternatives?.strengthCombinationCount ?? 0}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 12,
                      color: isDark ? AppTheme.grey400 : AppTheme.grey600,
                    ),
                  ),
                ),
                SizedBox(
                  width: 36,
                  height: 36,
                  child: IconButton(
                    tooltip: 'Vorherige unterschiedliche Stärkekombination',
                    padding: EdgeInsets.zero,
                    iconSize: 23,
                    onPressed:
                        !switching &&
                            !calculating &&
                            !reoptimizing &&
                            ((alternatives?.strengthCombinationCount ?? 0) >
                                    1 ||
                                (alternativeIndex == null &&
                                    (alternatives?.strengthCombinationCount ??
                                            0) >
                                        0))
                        ? onPrevious
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                ),
                SizedBox(
                  width: 36,
                  height: 36,
                  child: IconButton(
                    tooltip: 'Nächste unterschiedliche Stärkekombination',
                    padding: EdgeInsets.zero,
                    iconSize: 23,
                    onPressed:
                        !switching &&
                            !calculating &&
                            !reoptimizing &&
                            ((alternatives?.strengthCombinationCount ?? 0) >
                                    1 ||
                                (alternativeIndex == null &&
                                    (alternatives?.strengthCombinationCount ??
                                            0) >
                                        0))
                        ? onNext
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Erneut optimieren',
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.secondaryBlue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(36, 36),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      onPressed:
                          switching ||
                              calculating ||
                              reoptimizing ||
                              playerCount == 0
                          ? null
                          : onReoptimize,
                      child: reoptimizing
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.auto_fix_high, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Tooltip(
                  message: canShuffle
                      ? 'Gleich starke Spieler zufällig neu zuordnen'
                      : 'Keine anderen gleichwertigen Zuordnungen vorhanden',
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.btnBlue2,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(36, 36),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      onPressed:
                          switching ||
                              calculating ||
                              reoptimizing ||
                              !canShuffle
                          ? null
                          : onShuffle,
                      child: shuffling
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.shuffle, size: 20),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Material(
              color: isDark ? AppTheme.navigationBarDark : Colors.white,
              borderRadius: BorderRadius.circular(4),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onToggleVariantsLegend,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: isDark
                                      ? AppTheme.grey400
                                      : AppTheme.grey600,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Anleitung',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? AppTheme.grey300
                                            : AppTheme.grey700,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedRotation(
                            turns: variantsLegendExpanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeInOut,
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              size: 19,
                              color: isDark
                                  ? AppTheme.grey300
                                  : AppTheme.grey700,
                            ),
                          ),
                        ],
                      ),
                      AnimatedCrossFade(
                        firstChild: const SizedBox(width: double.infinity),
                        secondChild: _buildVariantsLegend(context, isDark),
                        crossFadeState: variantsLegendExpanded
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 180),
                        sizeCurve: Curves.easeInOut,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVariantsLegend(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 11, 2, 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
            height: 1,
            color: isDark ? AppTheme.grey700 : AppTheme.grey300,
          ),
          const SizedBox(height: 10),
          const _MetricLegendRow(
            label: 'Stärkekomb.:',
            labelWidth: 104,
            description:
                'Verteilung der gewichteten Siegquoten auf die beiden Teams. '
                'Spieler mit derselben gewichteten Siegquote gelten als austauschbar. '
                'Ein reiner Tausch der Teamnamen A und B zählt nicht als neue Kombination.',
          ),
          const _MetricLegendRow(
            label: 'Zauberstab:',
            labelWidth: 104,
            description:
                'Berechnet die bestmögliche Aufteilung der aktuellen Spieler neu. '
                'Die bisherigen Teamgrößen bleiben dabei erhalten.',
          ),
          const _MetricLegendRow(
            label: 'Shuffle:',
            labelWidth: 104,
            description:
                'Mischt Spieler mit gleicher gewichteter Siegquote, '
                'ohne die Stärkekombination zu ändern.',
          ),
        ],
      ),
    );
  }

  Widget _buildMetricLegend(BuildContext context, bool isDark, int minGames) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 11, 2, 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
            height: 1,
            color: isDark ? AppTheme.grey700 : AppTheme.grey300,
          ),
          const SizedBox(height: 10),
          const _MetricLegendRow(
            label: 'Spieler:',
            description: 'Anzahl aller Spieler in Team A und Team B.',
          ),
          const _MetricLegendRow(
            label: 'Ø A:',
            description: 'Gewichteter Durchschnitt der Siegquoten in Team A.',
          ),
          const _MetricLegendRow(
            label: 'Diff.:',
            description:
                'Abstand zwischen den Teamdurchschnitten in Prozentpunkten. Je kleiner, desto ausgeglichener.',
          ),
          const _MetricLegendRow(
            label: 'Ø B:',
            description: 'Gewichteter Durchschnitt der Siegquoten in Team B.',
          ),
          const _MetricLegendRow(
            label: 'Ø Ges.:',
            description:
                'Durchschnitt aller zugeteilten Spieler, unabhängig vom Team.',
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 7, right: 4),
            child: Text(
              'Die Ø-Werte werden in %, die Differenz in Prozentpunkten angezeigt. '
              'Bei weniger als $minGames Spielen zählt eine Siegquote von 50,0 %. '
              'Die Grenze kannst du über den Hinweis oberhalb des Chips ändern.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 11,
                color: isDark ? AppTheme.grey400 : AppTheme.grey600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamAnalysisCard extends StatelessWidget {
  final String title;
  final List<WeightedPlayer> players;
  final Color color;
  final Set<int> updatingPlayerIds;
  final Future<void> Function(WeightedPlayer player) onRemovePlayer;
  final Future<void> Function(WeightedPlayer player) onSwitchPlayer;
  final VoidCallback onAddPlayer;

  const _TeamAnalysisCard({
    required this.title,
    required this.players,
    required this.color,
    required this.updatingPlayerIds,
    required this.onRemovePlayer,
    required this.onSwitchPlayer,
    required this.onAddPlayer,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.navigationBarDark : Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: color,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${players.length} Spieler',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 38,
                  height: 38,
                  child: IconButton(
                    tooltip: 'Spieler hinzufügen',
                    onPressed: onAddPlayer,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.16),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    icon: const Icon(Icons.add, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
          if (players.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
              child: Text(
                'Keine Spieler im Team',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AppTheme.grey600),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: players.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 18,
                endIndent: 18,
                color: AppTheme.grey400.withValues(alpha: 0.45),
              ),
              itemBuilder: (context, index) {
                final weightedPlayer = players[index];
                final player = weightedPlayer.player;
                final isUpdating = updatingPlayerIds.contains(player.id);

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 6, 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 66,
                        child: isUpdating
                            ? const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : Row(
                                children: [
                                  SizedBox(
                                    width: 30,
                                    height: 30,
                                    child: IconButton(
                                      tooltip: 'Aus Team entfernen',
                                      padding: EdgeInsets.zero,
                                      style: TextButton.styleFrom(
                                        backgroundColor: AppTheme.deleteRed,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                      onPressed: () =>
                                          onRemovePlayer(weightedPlayer),
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                        size: 17,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  SizedBox(
                                    width: 30,
                                    height: 30,
                                    child: IconButton(
                                      tooltip: title == 'Team A'
                                          ? 'Zu Team B wechseln'
                                          : 'Zu Team A wechseln',
                                      padding: EdgeInsets.zero,
                                      style: TextButton.styleFrom(
                                        backgroundColor: AppTheme.primaryBlue,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                      onPressed: () =>
                                          onSwitchPlayer(weightedPlayer),
                                      icon: const Icon(
                                        Icons.swap_horiz,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              player.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            Text(
                              'S: ${player.attendance} | echte WR: ${(player.winRate * 100).toStringAsFixed(1)}%',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: AppTheme.grey600,
                                    fontSize: 12,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      _ValueBadge(
                        value: (weightedPlayer.effectiveWinRate * 100)
                            .toStringAsFixed(1),
                        fallback: weightedPlayer.usesFallbackWeight,
                      ),
                      const SizedBox(width: 10),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Eine Kennzahl innerhalb des einzigen, gemeinsamen Statistik-Chips.
class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 14,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppTheme.grey400 : AppTheme.grey600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 1),
          SizedBox(
            height: 17,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.grey300 : AppTheme.grey700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Legendenzeile im Stil der ausklappbaren Tabellenlegende auf "Alle Stats".
class _MetricLegendRow extends StatelessWidget {
  final String label;
  final String description;
  final double labelWidth;

  const _MetricLegendRow({
    required this.label,
    required this.description,
    this.labelWidth = 51,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(7, 3, 4, 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.grey300 : AppTheme.grey700,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w300,
                color: isDark ? AppTheme.grey300 : AppTheme.grey700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueBadge extends StatelessWidget {
  final String value;
  final bool fallback;

  const _ValueBadge({required this.value, required this.fallback});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$value%',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          fallback ? 'default Wert' : 'echter Wert',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: fallback ? AppTheme.deleteRed : AppTheme.grey600,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _DeleteDialogTitle extends StatelessWidget {
  const _DeleteDialogTitle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 2.0),
            child: Icon(Icons.delete, size: 25.0),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(
              'Löschen',
              style: Theme.of(context).textTheme.displayLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteDialogActions extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  const _DeleteDialogActions({required this.onCancel, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        SizedBox(
          height: 40,
          width: 125,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: isDark ? AppTheme.grey700 : Colors.white,
              foregroundColor: Colors.white,
              side: BorderSide.none,
            ),
            onPressed: onCancel,
            child: Text(
              'Abbrechen',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ),
        const Spacer(),
        SizedBox(
          height: 40,
          width: 125,
          child: TextButton(
            style: TextButton.styleFrom(backgroundColor: AppTheme.deleteRed),
            onPressed: onDelete,
            child: Text(
              'Löschen',
              style: Theme.of(context).textTheme.displaySmall,
            ),
          ),
        ),
      ],
    );
  }
}

extension _TeamAnalysisDatabaseActions on DatabaseService {
  Future<void> updatePlayerAssignment(
    int playerId, {
    required int status,
    int? team,
  }) async {
    final db = await database;

    await db.update(
      'player',
      {'status': status, if (team != null) 'team': team},
      where: 'id = ?',
      whereArgs: [playerId],
    );
  }
}
