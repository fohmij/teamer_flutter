import 'package:flutter/material.dart';
import 'package:teamer/app_theme/app_theme.dart';
import 'package:teamer/database/database_services.dart';
import 'package:teamer/database/player.dart';
import 'package:teamer/database/game.dart';
import 'package:data_table_2/data_table_2.dart';

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
            ? const Center(child: CircularProgressIndicator())
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
          const Icon(Icons.equalizer, size: 54, color: AppTheme.grey600),
          const SizedBox(height: 14),
          Text(
            'Keine Spieler gefunden',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Füge zuerst Spieler hinzu, dann erscheinen hier die Statistiken.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppTheme.grey600),
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
          Expanded(child: _buildTableCard()),
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
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: AppTheme.grey600),
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
                  _StatsChip(label: 'Spiele', value: _gamesCount.toString()),
                ],
              ),
              // _buildResetButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceToggle() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hiddenPlayersCount = _players.where((p) => p.attendance == 0).length;

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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.navigationBarDark : Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.visibility_off_outlined,
                    size: 20,
                    color: isDark ? AppTheme.grey300 : AppTheme.grey700,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          'Nur mit S > 0',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(width: 18),
                        Flexible(
                          child: Text(
                            '$hiddenPlayersCount Spieler betroffen',
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontSize: 13,
                                  color: AppTheme.grey600,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                  AnimatedRotation(
                    turns: _legendExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeInOut,
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: 24,
                      color: isDark ? AppTheme.grey300 : AppTheme.grey700,
                    ),
                  ),
                ],
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity),
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
        children: [
          Divider(
            height: 1,
            color: isDark ? AppTheme.grey700 : AppTheme.grey300,
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Row(
              children: [
                Text(
                  'W:\nL:\nD:\nS:\n%:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight(600)),
                ),
                SizedBox(width: 10,),
                Text(
                  'Siege\nNiederlagen\nUnentschieden\nSpiele\nSiegquote in Prozent',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight(300)),
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
    final visiblePlayers = _hideZeroAttendance
        ? _players.where((player) => player.attendance > 0).toList()
        : _players;
    final isEmptyColor = isDark ? AppTheme.grey600 : AppTheme.grey400;

    if (visiblePlayers.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.navigationBarDark : Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                SizedBox(height: 120),
                Icon(Icons.info_outline, size: 35, color: isEmptyColor),
                SizedBox(height: 8),
                Text(
                  'Keine Spieler mit',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: isEmptyColor),
                ),
                Text(
                  'Anwesenheit > 0',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isEmptyColor,
                    fontWeight: FontWeight(700),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.navigationBarDark : Colors.white,
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
            isDark ? AppTheme.grey700 : AppTheme.cardColorLight,
          ),
          dividerThickness: 0.7,
          columnSpacing: 1,
          horizontalMargin: 15,
          dataRowHeight: 56,
          columns: [
            DataColumn2(
              label: const Text('Name'),
              fixedWidth: 105,
              onSort: (i, asc) => _sort((p) => p.name.toLowerCase(), i, asc),
            ),
            DataColumn2(
              label: const Text('W'),
              fixedWidth: 25,
              minWidth: 35,
              numeric: true,
              onSort: (i, asc) => _sort((p) => p.wins, i, asc),
            ),
            DataColumn2(
              label: const Text('L'),
              fixedWidth: 25,
              minWidth: 35,
              numeric: true,
              onSort: (i, asc) => _sort((p) => p.losses, i, asc),
            ),
            DataColumn2(
              label: const Text('D'),
              fixedWidth: 25,
              minWidth: 35,
              numeric: true,
              onSort: (i, asc) =>
                  _sort((p) => p.attendance - (p.wins + p.losses), i, asc),
            ),
            DataColumn2(
              label: const Text('S'),
              fixedWidth: 25,
              minWidth: 35,
              numeric: true,
              onSort: (i, asc) => _sort((p) => p.attendance, i, asc),
            ),
            DataColumn2(
              label: const Text('%'),
              fixedWidth: 55,
              numeric: true,
              onSort: (i, asc) => _sort((p) => p.winRate, i, asc),
            ),
          ],
          rows: visiblePlayers.map((player) {
            final int draws = player.attendance - (player.wins + player.losses);

            return DataRow(
              cells: [
                DataCell(
                  Text(
                    player.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
                  _StatText((player.winRate * 100).toStringAsFixed(1)),
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

  const _StatsChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              color: isDark ? AppTheme.grey300 : AppTheme.grey700,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppTheme.grey400 : AppTheme.grey700,
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

  String _resultForGame(Game game) {
    if (game.teamBWon == -1) return 'Remis';

    final isTeamA = game.teamA.contains(player.id);
    final won = (isTeamA && game.teamBWon == 0) ||
        (!isTeamA && game.teamBWon == 1);

    return won ? 'Sieg' : 'Niederlage';
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final draws = player.attendance - player.wins - player.losses;
    final backgroundColor = isDark
        ? AppTheme.backgroundColorDark
        : AppTheme.backgroundColorLight;

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
                  color: AppTheme.grey600.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                  children: [
                    _buildHeader(context, isDark),
                    const SizedBox(height: 14),
                    _buildStatsRow(context, draws),
                    const SizedBox(height: 20),
                    Text(
                      'Spiele',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 8),
                    _buildGamesList(context, isDark),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
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
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
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
              color: isDark ? AppTheme.grey300 : AppTheme.grey700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(BuildContext context, int draws) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _PlayerStatChip(label: 'Spiele', value: '${player.attendance}'),
        _PlayerStatChip(label: 'Siege', value: '${player.wins}'),
        _PlayerStatChip(label: 'Niederlagen', value: '${player.losses}'),
        _PlayerStatChip(label: 'Draws', value: '$draws'),
      ],
    );
  }

  Widget _buildGamesList(BuildContext context, bool isDark) {
    if (games.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.navigationBarDark : Colors.white,
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
        color: isDark ? AppTheme.navigationBarDark : Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isDark ? AppTheme.grey700 : AppTheme.cardColorLight,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Name',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Text(
                    'Ergebnis',
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
            itemCount: games.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: isDark ? AppTheme.grey700 : AppTheme.grey300,
            ),
            itemBuilder: (context, index) {
              final game = games[index];
              final result = _resultForGame(game);
              final resultColor = _resultColor(result);

              return Padding(
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
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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

