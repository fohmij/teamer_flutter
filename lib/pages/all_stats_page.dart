// NEUE VERSION: Spielzeilen unter dem Diagramm sind klickbar und öffnen das Spiel-Overlay.
import 'package:flutter/material.dart';
import 'package:teamer/app_theme/app_theme.dart';
import 'package:teamer/database/database_services.dart';
import 'package:teamer/database/player.dart';
import 'package:teamer/database/game.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:teamer/services/app_settings_controller.dart';

class AllStatsPage extends StatefulWidget {
  const AllStatsPage({super.key});

  @override
  State<AllStatsPage> createState() => _AllStatsPageState();
}

class _AllStatsPageState extends State<AllStatsPage> {
  final DatabaseService _databaseService = DatabaseService.instance;

  int? _sortColumnIndex = 5;
  bool _sortAscending = false;
  bool _loading = true;
  bool _hideZeroAttendance = true;
  bool _legendExpanded = false;

  List<Player> _players = [];
  List<Game> _games = [];
  int _gamesCount = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadPlayers();
  }

  Future<void> _loadPlayers() async {
    final players = await _databaseService.getPlayersWithStatsFromGames();
    final games = await _databaseService.getGames();

    players.sort((a, b) => b.winRate.compareTo(a.winRate));

    if (!mounted) return;

    setState(() {
      _players = players;
      _games = games;
      _gamesCount = games.length;
      _loading = false;
    });
  }

  Future<void> _openSettings() async {
    await Navigator.pushNamed(context, '/settings');

    if (!mounted) return;

    setState(() {});
  }

  void _showPlayerStats(Player player) {
    final playerGames = _games.where((game) {
      return game.teamA.contains(player.id) || game.teamB.contains(player.id);
    }).toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlayerStatsBottomSheet(
        player: player,
        games: playerGames,
      ),
    );
  }

  void _sort<T>(
    Comparable<T> Function(Player p) getField,
    int columnIndex,
    bool ascending,
  ) {
    setState(() {
      _players.sort((a, b) {
        final aValue = getField(a);
        final bValue = getField(b);

        return ascending
            ? Comparable.compare(aValue, bValue)
            : Comparable.compare(bValue, aValue);
      });

      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alle Stats'),
        titleTextStyle: Theme.of(context).textTheme.titleLarge,
        backgroundColor: isDark
            ? AppTheme.navigationBarDark
            : AppTheme.navigationBarLight,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : _players.isEmpty
                ? _buildEmptyState()
                : _buildStatsContent(),
      ),
      extendBody: true,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.equalizer,
            size: 54,
            color: AppTheme.grey600,
          ),
          const SizedBox(height: 14),
          Text(
            'Keine Spieler gefunden',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Füge zuerst Spieler hinzu, dann erscheinen hier die Statistiken.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.grey600,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      child: Column(
        children: [
          _buildSummaryCard(),
          const SizedBox(height: 12),
          _buildAttendanceToggle(),
          const SizedBox(height: 12),
          Expanded(
            child: _buildTableCard(),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalAttendance = _players.fold<int>(
      0,
      (sum, p) => sum + p.attendance,
    );

    final averageAttendance = _players.isEmpty
        ? 0.0
        : totalAttendance / _players.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.grey700
            : AppTheme.cardColorLight,
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
                child: const Icon(
                  Icons.equalizer,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spielerstatistiken',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    Text(
                      'Übersicht, Sortieren, Vergleichen',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.grey600,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatsChip(
                    label: 'Spieler',
                    value: _players.length.toString(),
                  ),
                  _StatsChip(
                    label: 'Ø Anw.',
                    value: averageAttendance.toStringAsFixed(1),
                  ),
                  _StatsChip(
                    label: 'Spiele',
                    value: _gamesCount.toString(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceToggle() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final minGames = appSettingsController.value.minGamesForFullWeight;

    final hiddenPlayersCount = _players
        .where((player) => player.attendance < minGames)
        .length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () {
          setState(() {
            _legendExpanded = !_legendExpanded;
          });
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? AppTheme.navigationBarDark
                : Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.filter_alt_outlined,
                    size: 20,
                    color: isDark
                        ? AppTheme.grey300
                        : AppTheme.grey700,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 5,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Nur mit S ≥',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),

                            // Klick auf die Zahl -> Einstellungen
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _openSettings,
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppTheme.btnBlue2
                                        : AppTheme.primaryBlue,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '$minGames',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$hiddenPlayersCount Spieler betroffen',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                fontSize: 11,
                                color: AppTheme.grey600,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: _hideZeroAttendance,
                      activeThumbColor: AppTheme.cardColorLight,
                      activeTrackColor: AppTheme.primaryBlue,
                      onChanged: (value) {
                        setState(() {
                          _hideZeroAttendance = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 2),
                  AnimatedRotation(
                    turns: _legendExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeInOut,
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: 24,
                      color: isDark
                          ? AppTheme.grey300
                          : AppTheme.grey700,
                    ),
                  ),
                ],
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox(
                  width: double.infinity,
                ),
                secondChild: _buildStatsLegend(),
                crossFadeState: _legendExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 180),
                sizeCurve: Curves.easeInOut,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsLegend() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
            height: 1,
            color: isDark
                ? AppTheme.grey700
                : AppTheme.grey300,
          ),
          const SizedBox(height: 10),

          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.filter_alt_outlined,
                  size: 17,
                  color: AppTheme.grey600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filtergrenze: S ≥ Mindestspiele',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                              fontSize: 12,
                              color: AppTheme.grey600,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tippe auf die Zahl oben, um den Wert in den Einstellungen zu ändern.',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                              fontSize: 11,
                              color: AppTheme.grey600,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Row(
              children: [
                Text(
                  'W:\nL:\nD:\nS:\n%:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Siege\n'
                  'Niederlagen\n'
                  'Unentschieden\n'
                  'Spiele\n'
                  'Siegquote in Prozent',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final minGames =
        appSettingsController.value.minGamesForFullWeight;

    final visiblePlayers = _hideZeroAttendance
        ? _players
            .where(
              (player) => player.attendance >= minGames,
            )
            .toList()
        : _players;

    final isEmptyColor = isDark
        ? AppTheme.grey600
        : AppTheme.grey400;

    if (visiblePlayers.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.navigationBarDark
              : Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline,
                size: 35,
                color: isEmptyColor,
              ),
              const SizedBox(height: 8),
              Text(
                'Keine Spieler mit',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isEmptyColor,
                ),
              ),
              Text(
                'Anwesenheit ≥ $minGames',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isEmptyColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.navigationBarDark
              : Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
        child: DataTable2(
          fixedTopRows: 1,
          minWidth: 120,
          smRatio: 0.35,
          lmRatio: 2.2,
          sortColumnIndex: _sortColumnIndex,
          sortAscending: _sortAscending,
          headingRowColor: WidgetStatePropertyAll(
            isDark
                ? AppTheme.grey700
                : AppTheme.cardColorLight,
          ),
          dividerThickness: 0.7,
          columnSpacing: 1,
          horizontalMargin: 15,
          dataRowHeight: 56,
          columns: [
            DataColumn2(
              label: const Text('Name'),
              fixedWidth: 105,
              onSort: (i, asc) =>
                  _sort((p) => p.name.toLowerCase(), i, asc),
            ),
            DataColumn2(
              label: const Text('W'),
              fixedWidth: 25,
              minWidth: 35,
              numeric: true,
              onSort: (i, asc) =>
                  _sort((p) => p.wins, i, asc),
            ),
            DataColumn2(
              label: const Text('L'),
              fixedWidth: 25,
              minWidth: 35,
              numeric: true,
              onSort: (i, asc) =>
                  _sort((p) => p.losses, i, asc),
            ),
            DataColumn2(
              label: const Text('D'),
              fixedWidth: 25,
              minWidth: 35,
              numeric: true,
              onSort: (i, asc) => _sort(
                (p) => p.attendance - (p.wins + p.losses),
                i,
                asc,
              ),
            ),
            DataColumn2(
              label: const Text('S'),
              fixedWidth: 25,
              minWidth: 35,
              numeric: true,
              onSort: (i, asc) =>
                  _sort((p) => p.attendance, i, asc),
            ),
            DataColumn2(
              label: const Text('%'),
              fixedWidth: 55,
              numeric: true,
              onSort: (i, asc) =>
                  _sort((p) => p.winRate, i, asc),
            ),
          ],
          rows: visiblePlayers.map((player) {
            final int draws =
                player.attendance - (player.wins + player.losses);

            return DataRow(
              cells: [
                DataCell(
                  Text(
                    player.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                  ),
                  onTap: () => _showPlayerStats(player),
                ),
                DataCell(
                  _StatText(player.wins.toString()),
                  onTap: () => _showPlayerStats(player),
                ),
                DataCell(
                  _StatText(player.losses.toString()),
                  onTap: () => _showPlayerStats(player),
                ),
                DataCell(
                  _StatText(draws.toString()),
                  onTap: () => _showPlayerStats(player),
                ),
                DataCell(
                  _StatText(player.attendance.toString()),
                  onTap: () => _showPlayerStats(player),
                ),
                DataCell(
                  _StatText(
                    (player.winRate * 100).toStringAsFixed(1),
                  ),
                  onTap: () => _showPlayerStats(player),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _StatsChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatsChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.navigationBarDark
            : Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppTheme.grey300
                  : AppTheme.grey700,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? AppTheme.grey400
                  : AppTheme.grey700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatText extends StatelessWidget {
  final String value;

  const _StatText(this.value);

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w300,
          ),
    );
  }
}

class _PlayerStatsBottomSheet extends StatelessWidget {
  final Player player;
  final List<Game> games;

  const _PlayerStatsBottomSheet({
    required this.player,
    required this.games,
  });

  List<Game> get _sortedGames {
    final sortedGames = List<Game>.from(games);

    sortedGames.sort((a, b) {
      final nameComparison = a.name.toLowerCase().compareTo(
            b.name.toLowerCase(),
          );

      if (nameComparison != 0) return nameComparison;
      return a.id.compareTo(b.id);
    });

    return sortedGames;
  }

  List<double> _buildWinRateHistory(List<Game> sortedGames) {
    var wins = 0;
    var gamesPlayed = 0;
    final history = <double>[];

    for (final game in sortedGames) {
      gamesPlayed += 1;

      if (_resultForGame(game) == 'Sieg') {
        wins += 1;
      }

      history.add(wins / gamesPlayed);
    }

    return history;
  }

  String _resultForGame(Game game) {
    if (game.teamBWon == -1) {
      return 'Remis';
    }

    final isTeamA = game.teamA.contains(player.id);

    final won =
        (isTeamA && game.teamBWon == 0) ||
        (!isTeamA && game.teamBWon == 1);

    return won
        ? 'Sieg'
        : 'Niederlage';
  }

  Color _resultColor(String result) {
    switch (result) {
      case 'Sieg':
        return AppTheme.playerSelected;
      case 'Niederlage':
        return AppTheme.deleteRed;
      default:
        return AppTheme.grey600;
    }
  }


  List<String> _splitNames(Object? value) {
    if (value == null) return [];

    if (value is List) {
      return value
          .map((name) => name.toString().trim())
          .where((name) => name.isNotEmpty)
          .toList();
    }

    return value
        .toString()
        .split(RegExp(r'[,;\n]'))
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
  }

  String _winnerLabel(Game game) {
    if (game.teamBWon == 0) return 'A gewinnt';
    if (game.teamBWon == 1) return 'B gewinnt';
    return 'Remis';
  }

  Color _winnerColor(Game game) {
    if (game.teamBWon == 0) return AppTheme.btnBlue3;
    if (game.teamBWon == 1) return AppTheme.btnBlue2;
    return AppTheme.grey600;
  }

  void _showGameOverlay(BuildContext context, Game game) {
    final teamA = _splitNames(game.teamANames);
    final teamB = _splitNames(game.teamBNames);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 24,
          ),
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Card(
              elevation: 14,
              color: isDark ? AppTheme.navigationBarDark : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                game.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontSize: 24),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _PlayerGameInfoChip(
                                    icon: Icons.group_outlined,
                                    label: '${teamA.length + teamB.length} Spieler',
                                    color: isDark
                                        ? AppTheme.grey700
                                        : AppTheme.navigationBarLight,
                                    fontColor: isDark
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                  _PlayerGameInfoChip(
                                    icon: Icons.emoji_events_outlined,
                                    label: _winnerLabel(game),
                                    color: _winnerColor(game),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Schließen',
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Flexible(
                      child: SingleChildScrollView(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final showTeamsSideBySide =
                                constraints.maxWidth > 520;

                            if (!showTeamsSideBySide) {
                              return Column(
                                children: [
                                  _PlayerGameTeamCard(
                                    title: 'Team A',
                                    players: teamA,
                                    color: AppTheme.btnBlue3,
                                  ),
                                  const SizedBox(height: 12),
                                  _PlayerGameTeamCard(
                                    title: 'Team B',
                                    players: teamB,
                                    color: AppTheme.btnBlue2,
                                  ),
                                ],
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _PlayerGameTeamCard(
                                    title: 'Team A',
                                    players: teamA,
                                    color: AppTheme.btnBlue3,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _PlayerGameTeamCard(
                                    title: 'Team B',
                                    players: teamB,
                                    color: AppTheme.btnBlue2,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final draws =
        player.attendance - player.wins - player.losses;

    final backgroundColor = isDark
        ? AppTheme.backgroundColorDark
        : AppTheme.backgroundColorLight;

    final sortedGames = _sortedGames;
    final winRateHistory = _buildWinRateHistory(sortedGames);

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.50,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(4),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppTheme.grey600.withValues(
                    alpha: 0.45,
                  ),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    18,
                    18,
                    18,
                    24,
                  ),
                  children: [
                    _buildHeader(context, isDark),
                    const SizedBox(height: 14),
                    _buildStatsRow(context, draws),
                    const SizedBox(height: 20),
                    Text(
                      'Siegquote-Verlauf',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 8),
                    _buildWinRateChart(
                      context,
                      isDark,
                      sortedGames,
                      winRateHistory,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Spiele',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 8),
                    _buildGamesList(
                      context,
                      isDark,
                      sortedGames,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isDark,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            player.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 28,
                ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8.0,
            vertical: 4.0,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? AppTheme.grey700
                : AppTheme.cardColorLight,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${(player.winRate * 100).toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 28,
                  color: isDark
                      ? AppTheme.grey300
                      : AppTheme.grey700,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(
    BuildContext context,
    int draws,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _PlayerStatChip(
          label: 'Spiele',
          value: '${player.attendance}',
        ),
        _PlayerStatChip(
          label: 'Siege',
          value: '${player.wins}',
        ),
        _PlayerStatChip(
          label: 'Niederlagen',
          value: '${player.losses}',
        ),
        _PlayerStatChip(
          label: 'Draws',
          value: '$draws',
        ),
      ],
    );
  }

  Widget _buildWinRateChart(
    BuildContext context,
    bool isDark,
    List<Game> sortedGames,
    List<double> winRateHistory,
  ) {
    if (sortedGames.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 28,
        ),
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.navigationBarDark
              : Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'Noch kein Verlauf verfügbar',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.grey600,
              ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.navigationBarDark
            : Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kumulierte Gewinnquote nach jedem Spiel',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 12,
                  color: AppTheme.grey600,
                ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final chartWidth = sortedGames.length <= 6
                  ? constraints.maxWidth
                  : sortedGames.length * 48.0;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: chartWidth,
                  height: 220,
                  child: CustomPaint(
                    painter: _WinRateChartPainter(
                      values: winRateHistory,
                      gameNames: sortedGames
                          .map((game) => game.name)
                          .toList(),
                      lineColor: isDark
                          ? AppTheme.btnBlue2
                          : AppTheme.primaryBlue,
                      gridColor: isDark
                          ? AppTheme.grey600.withValues(alpha: 0.35)
                          : AppTheme.grey400.withValues(alpha: 0.45),
                      textColor: isDark
                          ? AppTheme.grey400
                          : AppTheme.grey600,
                      pointFillColor: isDark
                          ? AppTheme.navigationBarDark
                          : Colors.white,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGamesList(
    BuildContext context,
    bool isDark,
    List<Game> sortedGames,
  ) {
    if (sortedGames.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 28,
        ),
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.navigationBarDark
              : Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'Keine Spiele gefunden',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.grey600,
              ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.navigationBarDark
            : Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            color: isDark
                ? AppTheme.grey700
                : AppTheme.cardColorLight,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Name',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Text(
                    'Ergebnis',
                    textAlign: TextAlign.right,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedGames.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: isDark
                  ? AppTheme.grey700
                  : AppTheme.grey300,
            ),
            itemBuilder: (context, index) {
              final game = sortedGames[index];
              final result = _resultForGame(game);
              final resultColor = _resultColor(result);

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showGameOverlay(context, game),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            game.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  fontSize: 16,
                                ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 100,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: resultColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                result,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: AppTheme.grey600,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}


class _PlayerGameInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final Color? fontColor;

  const _PlayerGameInfoChip({
    required this.icon,
    required this.label,
    this.color,
    this.fontColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final chipColor =
        color ?? (isDark ? AppTheme.navigationBarDark : AppTheme.btnBlue1);

    final foregroundColor =
        fontColor ??
        (color == null
            ? (isDark ? Colors.white : AppTheme.grey700)
            : Colors.white);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foregroundColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: foregroundColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerGameTeamCard extends StatelessWidget {
  final String title;
  final List<String> players;
  final Color color;

  const _PlayerGameTeamCard({
    required this.title,
    required this.players,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.grey700 : AppTheme.navigationBarLight,
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  '${players.length}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (players.isEmpty)
            Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'Keine Spieler',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: AppTheme.grey600),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: players.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 18,
                endIndent: 18,
                color: AppTheme.grey400.withValues(alpha: 0.45),
              ),
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          players[index],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w400,
                              ),
                        ),
                      ),
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

class _WinRateChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> gameNames;
  final Color lineColor;
  final Color gridColor;
  final Color textColor;
  final Color pointFillColor;

  const _WinRateChartPainter({
    required this.values,
    required this.gameNames,
    required this.lineColor,
    required this.gridColor,
    required this.textColor,
    required this.pointFillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    const leftPadding = 38.0;
    const rightPadding = 12.0;
    const topPadding = 12.0;
    const bottomPadding = 34.0;

    final plotWidth = size.width - leftPadding - rightPadding;
    final plotHeight = size.height - topPadding - bottomPadding;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final pointBorderPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    final pointFillPaint = Paint()
      ..color = pointFillColor
      ..style = PaintingStyle.fill;

    for (final fraction in <double>[0.0, 0.5, 1.0]) {
      final y = topPadding + (1 - fraction) * plotHeight;

      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );

      final label = '${(fraction * 100).round()}%';
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: textColor,
            fontSize: 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(
          leftPadding - textPainter.width - 6,
          y - textPainter.height / 2,
        ),
      );
    }

    final points = <Offset>[];

    for (var index = 0; index < values.length; index++) {
      final normalizedValue = values[index].clamp(0.0, 1.0).toDouble();

      final x = values.length == 1
          ? leftPadding + plotWidth / 2
          : leftPadding + (index / (values.length - 1)) * plotWidth;

      final y = topPadding + (1 - normalizedValue) * plotHeight;
      points.add(Offset(x, y));
    }

    if (points.length > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);

      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }

      canvas.drawPath(path, linePaint);
    }

    for (final point in points) {
      canvas.drawCircle(point, 5.0, pointBorderPaint);
      canvas.drawCircle(point, 2.4, pointFillPaint);
    }

    if (gameNames.isNotEmpty) {
      _paintXAxisLabel(
        canvas,
        gameNames.first,
        points.first.dx,
        topPadding + plotHeight + 8,
        textColor,
        size.width,
      );

      if (gameNames.length > 1) {
        _paintXAxisLabel(
          canvas,
          gameNames.last,
          points.last.dx,
          topPadding + plotHeight + 8,
          textColor,
          size.width,
        );
      }
    }
  }

  void _paintXAxisLabel(
    Canvas canvas,
    String label,
    double centerX,
    double y,
    Color color,
    double canvasWidth,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: 10,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 86);

    final desiredX = centerX - textPainter.width / 2;
    final clampedX = desiredX
        .clamp(0.0, canvasWidth - textPainter.width)
        .toDouble();

    textPainter.paint(canvas, Offset(clampedX, y));
  }

  @override
  bool shouldRepaint(covariant _WinRateChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.gameNames != gameNames ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.textColor != textColor ||
        oldDelegate.pointFillColor != pointFillColor;
  }
}

class _PlayerStatChip extends StatelessWidget {
  final String label;
  final String value;

  const _PlayerStatChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.navigationBarDark
            : Colors.white,
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
              color: isDark
                  ? AppTheme.grey300
                  : AppTheme.grey700,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppTheme.grey400
                  : AppTheme.grey700,
            ),
          ),
        ],
      ),
    );
  }
}