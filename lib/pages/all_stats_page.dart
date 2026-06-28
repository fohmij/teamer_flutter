import 'package:flutter/material.dart';
import 'package:teamer/app_theme/app_theme.dart';
import 'package:teamer/database/database_services.dart';
import 'package:teamer/database/player.dart';
import 'package:data_table_2/data_table_2.dart';

class AllStatsPage extends StatefulWidget {
  const AllStatsPage({super.key});

  @override
  State<AllStatsPage> createState() => _AllStatsPageState();
}

class _AllStatsPageState extends State<AllStatsPage> {
  final DatabaseService _databaseService = DatabaseService.instance;

  int? _sortColumnIndex;
  bool _sortAscending = true;
  bool _loading = true;
  bool _hideZeroAttendance = true;
  List<Player> _players = [];
  int _gamesCount = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadPlayers();
  }

  Future<void> _loadPlayers() async {
    final players = await _databaseService.getPlayersWithStatsFromGames();
    final games = await _databaseService.getGames();

    if (!mounted) return;
    setState(() {
      _players = players;
      _gamesCount = games.length;
      _loading = false;
    });
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

  Future<void> _resetStats() async {
    setState(() {
      _loading = true;
    });

    await _databaseService.resetStats();
    await _loadPlayers();
  }

  void _showResetStatsDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _ResetStatsDialogTitle(),
            const Padding(padding: EdgeInsets.only(top: 6.0), child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30.0),
              child: Text(
                'Sollen wirklich alle Statistiken zurückgesetzt werden?',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 12.0),
              child: Divider(),
            ),
            _ResetStatsDialogActions(
              onCancel: () {
                Navigator.pop(context);
              },
              onReset: () async {
                Navigator.pop(context);
                await _resetStats();
              },
            ),
          ],
        ),
      ),
    );
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final double nameColumnWidth = (constraints.maxWidth * 0.5)
            .clamp(92.0, 150.0)
            .toDouble();

        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
          child: Column(
            children: [
              _buildSummaryCard(),
              const SizedBox(height: 12),
              _buildAttendanceToggle(),
              const SizedBox(height: 12),
              Expanded(child: _buildTableCard(nameColumnWidth)),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.navigationBarDark : Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
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
                  'Nur mit A > 0',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 18),
                Text(
                  '$hiddenPlayersCount Spieler betroffen',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 13,
                    color: AppTheme.grey600,
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
        ],
      ),
    );
  }

  Widget _buildTableCard(double nameColumnWidth) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final visiblePlayers = _hideZeroAttendance
        ? _players.where((player) => player.attendance > 0).toList()
        : _players;

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
            child: Text(
              'Keine Spieler mit Anwesenheit über 0',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
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
              fixedWidth: nameColumnWidth,
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
              label: const Text('A'),
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
                  SizedBox(
                    width: nameColumnWidth,
                    child: Text(
                      player.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
                DataCell(_StatText(player.wins.toString())),
                DataCell(_StatText(player.losses.toString())),
                DataCell(_StatText(draws.toString())),
                DataCell(_StatText(player.attendance.toString())),
                DataCell(
                  _StatText((player.winRate * 100).toStringAsFixed(1)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildResetButton() {
    return SizedBox(
      height: 38,
      width: 38,
      child: IconButton(
        style: TextButton.styleFrom(
          backgroundColor: AppTheme.deleteRed,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        onPressed: _showResetStatsDialog,
        icon: const Icon(Icons.delete, color: Colors.white, size: 20),
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

class _ResetStatsDialogTitle extends StatelessWidget {
  const _ResetStatsDialogTitle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 2.0),
            child: Icon(Icons.warning, size: 25.0),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(
              'Stats zurücksetzen',
              style: Theme.of(context).textTheme.displayLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResetStatsDialogActions extends StatelessWidget {
  final VoidCallback onCancel;
  final Future<void> Function() onReset;

  const _ResetStatsDialogActions({
    required this.onCancel,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        SizedBox(
          height: 40,
          width: 135,
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
          width: 135,
          child: TextButton(
            style: TextButton.styleFrom(backgroundColor: AppTheme.deleteRed),
            onPressed: onReset,
            child: Text(
              'Zurücksetzen',
              style: Theme.of(context).textTheme.displaySmall,
            ),
          ),
        ),
      ],
    );
  }
}
