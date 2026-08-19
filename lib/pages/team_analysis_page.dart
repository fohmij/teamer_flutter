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

  bool _loading = true;
  final Set<int> _updatingPlayerIds = <int>{};
  List<WeightedPlayer> _teamA = [];
  List<WeightedPlayer> _teamB = [];
  List<Player> _availablePlayers = [];

  @override
  void initState() {
    super.initState();
    _loadTeams();
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
      (a, b) => a.player.name.toLowerCase().compareTo(
        b.player.name.toLowerCase(),
      ),
    );
  }

  Future<void> _confirmAndRemovePlayer(
    WeightedPlayer weightedPlayer,
  ) async {
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
            const Padding(
              padding: EdgeInsets.only(top: 6.0),
              child: Divider(),
            ),
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
    if (_updatingPlayerIds.contains(player.id)) return;

    setState(() {
      _updatingPlayerIds.add(player.id);
    });

    try {
      await _databaseService.updatePlayerAssignment(
        player.id,
        status: 0,
      );

      if (!mounted) return;
      setState(() {
        _teamA.removeWhere((entry) => entry.player.id == player.id);
        _teamB.removeWhere((entry) => entry.player.id == player.id);
        _availablePlayers.removeWhere((entry) => entry.id == player.id);
        _availablePlayers.add(player);
        _sortPlayers(_availablePlayers);
      });
    } finally {
      if (mounted) {
        setState(() {
          _updatingPlayerIds.remove(player.id);
        });
      }
    }
  }

  Future<void> _addPlayerToTeam(Player player, int team) async {
    if (_updatingPlayerIds.contains(player.id)) return;

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
                                    style: Theme.of(context).textTheme.bodyLarge,
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
                                  color: AppTheme.grey400.withValues(alpha: 0.45),
                                ),
                                itemBuilder: (context, index) {
                                  final player = availablePlayers[index];
                                  final isUpdating = _updatingPlayerIds.contains(
                                    player.id,
                                  );

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
                                            await _addPlayerToTeam(player, team);
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

  void _openTeamPage() {
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
                    _SummaryCard(result: _currentResult),
                    const SizedBox(height: 14),
                    Expanded(
                      child: ListView(
                        children: [
                          _TeamAnalysisCard(
                            title: 'Team A',
                            players: _teamA,
                            color: AppTheme.btnBlue3,
                            updatingPlayerIds: _updatingPlayerIds,
                            onRemovePlayer: _confirmAndRemovePlayer,
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

  const _SummaryCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final minGames = appSettingsController.value.minGamesForFullWeight;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
                    Text(
                      'Unter $minGames Spielen = Wert 0.5 (default Wert)',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.grey600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                label: 'Ø A',
                value: (result.averageTeamA * 100).toStringAsFixed(1),
              ),
              _InfoChip(
                label: 'Diff.',
                value: (result.difference * 100).toStringAsFixed(1),
              ),
              _InfoChip(
                label: 'Ø B',
                value: (result.averageTeamB * 100).toStringAsFixed(1),
              ),
            ],
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
  final VoidCallback onAddPlayer;

  const _TeamAnalysisCard({
    required this.title,
    required this.players,
    required this.color,
    required this.updatingPlayerIds,
    required this.onRemovePlayer,
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
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.grey600,
                ),
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
                      isUpdating
                          ? const Padding(
                              padding: EdgeInsets.all(9),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : SizedBox(
                              width: 30,
                              height: 30,
                              child: IconButton(
                                tooltip: 'Aus Team entfernen',
                                style: TextButton.styleFrom(
                                  backgroundColor: AppTheme.deleteRed,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                onPressed: () => onRemovePlayer(weightedPlayer),
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                  size: 15,
                                ),
                              ),
                            ),
                      const SizedBox(width: 20),
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

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.navigationBarDark : Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.grey300 : AppTheme.grey700,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppTheme.grey400 : AppTheme.grey700,
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
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          fallback ? 'default Wert' : 'echter Wert',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: fallback ? AppTheme.deleteRed : AppTheme.grey600,
            fontSize: 12,
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

  const _DeleteDialogActions({
    required this.onCancel,
    required this.onDelete,
  });

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
            style: TextButton.styleFrom(
              backgroundColor: AppTheme.deleteRed,
            ),
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
      {
        'status': status,
        if (team != null) 'team': team,
      },
      where: 'id = ?',
      whereArgs: [playerId],
    );
  }
}
