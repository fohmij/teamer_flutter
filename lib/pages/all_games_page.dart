import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:teamer/app_theme/app_theme.dart';
import 'package:teamer/database/database_services.dart';
import 'package:teamer/database/game.dart';

class AllGamesPage extends StatefulWidget {
  const AllGamesPage({super.key});

  @override
  State<AllGamesPage> createState() => _AllGamesPageState();
}

class _AllGamesPageState extends State<AllGamesPage> {
  final DatabaseService _databaseService = DatabaseService.instance;
  late Future<List<Game>> _gamesFuture;

  int? _sortColumnIndex;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _gamesFuture = _databaseService.getGames();
  }

  void _reloadGames() {
    setState(() {
      _gamesFuture = _databaseService.getGames();
    });
  }

  void _sortGames(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  List<Game> _sortedGames(List<Game> games) {
    final sortedGames = List<Game>.from(games);
    final sortColumnIndex = _sortColumnIndex;

    if (sortColumnIndex == null) return sortedGames;

    sortedGames.sort((a, b) {
      final result = switch (sortColumnIndex) {
        0 => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        1 => _playerCount(a).compareTo(_playerCount(b)),
        _ => 0,
      };

      return _sortAscending ? result : -result;
    });

    return sortedGames;
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

  int _playerCount(Game game) {
    return _splitNames(game.teamANames).length +
        _splitNames(game.teamBNames).length;
  }

  String _winnerLabel(Game game) {
    if (game.teamBWon == 0) return 'Team A gewinnt';
    if (game.teamBWon == 1) return 'Team B gewinnt';
    return 'Remis';
  }

  Color _winnerColor(Game game) {
    if (game.teamBWon == 0) return AppTheme.btnBlue3;
    if (game.teamBWon == 1) return AppTheme.btnBlue2;
    return AppTheme.grey600;
  }

  Future<void> _showRenameGameDialog(Game game) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _RenameGameDialog(initialName: game.name),
    );

    final trimmedName = newName?.trim();
    if (trimmedName == null || trimmedName.isEmpty) return;
    if (trimmedName == game.name.trim()) return;

    await _databaseService.updateGameName(game.id, trimmedName);

    if (!mounted) return;
    _reloadGames();
  }

  Future<void> _showDeleteGameDialog(Game game) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.delete_outline, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    'Spiel löschen',
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 18),
              Text.rich(
                TextSpan(
                  text: 'Soll ',
                  style: Theme.of(context).textTheme.bodyMedium,
                  children: [
                    TextSpan(
                      text: game.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(
                      text: ' wirklich dauerhaft gelöscht werden?',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  SizedBox(
                    height: 40,
                    width: 135,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isDark
                            ? AppTheme.grey700
                            : Colors.white,
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: isDark ? Colors.transparent : AppTheme.grey300,
                          width: 1,
                        ),
                      ),
                      onPressed: () => Navigator.of(dialogContext).pop(),
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
                      style: TextButton.styleFrom(
                        backgroundColor: AppTheme.deleteRed,
                      ),
                      onPressed: () async {
                        await _databaseService.deleteGame(game.id);

                        if (!dialogContext.mounted) return;
                        Navigator.of(dialogContext).pop();

                        if (!mounted) return;
                        _reloadGames();
                      },
                      child: Text(
                        'Löschen',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showDeleteAllGamesDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.delete_outline, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    'Alle Spiele löschen',
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 18),
              Text(
                'Sollen wirklich alle gespeicherten Spiele dauerhaft gelöscht werden?',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  SizedBox(
                    height: 40,
                    width: 135,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isDark
                            ? AppTheme.grey700
                            : Colors.white,
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: isDark ? Colors.transparent : AppTheme.grey300,
                          width: 1,
                        ),
                      ),
                      onPressed: () => Navigator.of(dialogContext).pop(),
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
                      style: TextButton.styleFrom(
                        backgroundColor: AppTheme.deleteRed,
                      ),
                      onPressed: () async {
                        await _databaseService.deleteAllGames();

                        if (!dialogContext.mounted) return;
                        Navigator.of(dialogContext).pop();

                        if (!mounted) return;
                        _reloadGames();
                      },
                      child: Text(
                        'Löschen',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showGameOverlay(Game game) {
    final teamA = _splitNames(game.teamANames);
    final teamB = _splitNames(game.teamBNames);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog<void>(
      context: context,
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
                                style: Theme.of(
                                  context,
                                ).textTheme.titleLarge?.copyWith(fontSize: 24),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _InfoChip(
                                    icon: Icons.group_outlined,
                                    label:
                                        '${teamA.length + teamB.length} Spieler',
                                    color: isDark
                                        ? AppTheme.grey700
                                        : AppTheme.navigationBarLight,
                                    fontColor: isDark
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                  _InfoChip(
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
                                  _TeamPlayersCard(
                                    title: 'Team A',
                                    players: teamA,
                                    color: AppTheme.btnBlue3,
                                  ),
                                  const SizedBox(height: 12),
                                  _TeamPlayersCard(
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
                                  child: _TeamPlayersCard(
                                    title: 'Team A',
                                    players: teamA,
                                    color: AppTheme.btnBlue3,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _TeamPlayersCard(
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
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: isDark
                                  ? AppTheme.grey700
                                  : Colors.white,
                              foregroundColor: isDark
                                  ? Colors.white
                                  : Colors.black,
                              side: BorderSide(
                                color: isDark
                                    ? Colors.transparent
                                    : AppTheme.grey300,
                                width: 1,
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                              _showRenameGameDialog(game);
                            },
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Bearbeiten'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              backgroundColor: AppTheme.deleteRed,
                            ),
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                              _showDeleteGameDialog(game);
                            },
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.white,
                            ),
                            label: Text(
                              'Löschen',
                              style: Theme.of(context).textTheme.displaySmall,
                            ),
                          ),
                        ),
                      ],
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
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Alle Spiele'),
        titleTextStyle: Theme.of(context).textTheme.titleLarge,
        centerTitle: false,
        elevation: 0,
        backgroundColor: isDark
            ? AppTheme.navigationBarDark
            : AppTheme.navigationBarLight,
      ),
      body: SafeArea(
        child: FutureBuilder<List<Game>>(
          future: _gamesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Fehler: ${snapshot.error}'));
            }

            final games = snapshot.data ?? [];

            if (games.isEmpty) {
              return const _EmptyGamesState();
            }

            return _buildGamesContent(games);
          },
        ),
      ),
      extendBody: true,
    );
  }

  Widget _buildGamesContent(List<Game> games) {
    final sortedGames = _sortedGames(games);
    final averageAttendance =
        games.fold<int>(0, (sum, game) => sum + _playerCount(game)) /
        games.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      child: Column(
        children: [
          _GamesSummaryCard(
            gameCount: games.length,
            averageAttendance: averageAttendance,
            onDeleteAll: _showDeleteAllGamesDialog,
          ),
          const SizedBox(height: 14),
          Expanded(child: _buildGamesTableCard(sortedGames)),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildGamesTableCard(List<Game> games) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.navigationBarDark : Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: DataTable2(
          fixedTopRows: 1,
          minWidth: 260,
          smRatio: 0.35,
          lmRatio: 2.2,
          sortColumnIndex: _sortColumnIndex,
          sortAscending: _sortAscending,
          headingRowColor: WidgetStatePropertyAll(
            isDark ? AppTheme.grey700 : AppTheme.cardColorLight,
          ),
          dividerThickness: 0.7,
          columnSpacing: 1,
          horizontalMargin: 12,
          dataRowHeight: 58,
          columns: [
            DataColumn2(
              label: const Text('Name'),
              size: ColumnSize.L,
              onSort: _sortGames,
            ),
            DataColumn2(
              label: const Text('Anw.'),
              fixedWidth: 88,
              numeric: true,
              onSort: _sortGames,
            ),
          ],
          rows: games.map((game) {
            final playerCount = _playerCount(game);

            return DataRow(
              onLongPress: () => _showDeleteGameDialog(game),
              cells: [
                DataCell(
                  Text(
                    game.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  onTap: () => _showGameOverlay(game),
                ),
                DataCell(
                  Align(
                    alignment: Alignment.centerRight,
                    child: _InfoChip(
                      icon: Icons.group_outlined,
                      label: '$playerCount',
                    ),
                  ),
                  onTap: () => _showGameOverlay(game),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _RenameGameDialog extends StatefulWidget {
  final String initialName;

  const _RenameGameDialog({required this.initialName});

  @override
  State<_RenameGameDialog> createState() => _RenameGameDialogState();
}

class _RenameGameDialogState extends State<_RenameGameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initialName.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final newName = _controller.text.trim();
    if (newName.isEmpty) return;

    Navigator.of(context).pop(newName);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        side: BorderSide(color: isDark ? AppTheme.grey700 : Colors.white),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      title: Text(
        'Spiel bearbeiten',
        style: Theme.of(context).textTheme.displayLarge,
      ),
      content: SizedBox(
        width: 560,
        child: TextField(
          controller: _controller,
          autofocus: true,
          style: Theme.of(context).textTheme.bodyMedium,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            hintText: 'Spielname...',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _submit(),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        Row(
          children: [
            SizedBox(
              height: 40,
              width: 135,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: isDark ? AppTheme.grey700 : Colors.white,
                  foregroundColor: Colors.white,
                  side: BorderSide(
                    color: isDark ? Colors.transparent : AppTheme.grey300,
                    width: 1,
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
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
                onPressed: _submit,
                child: Text(
                  'Speichern',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GamesSummaryCard extends StatelessWidget {
  final int gameCount;
  final double averageAttendance;
  final VoidCallback onDeleteAll;

  const _GamesSummaryCard({
    required this.gameCount,
    required this.averageAttendance,
    required this.onDeleteAll,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                child: const Icon(Icons.history, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spielverlauf',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    Text(
                      'Übersicht, Bearbeiten, Löschen',
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
                  _StatsChip(label: 'Spiele', value: gameCount.toString()),
                  _StatsChip(
                    label: 'Ø Anw.',
                    value: averageAttendance.toStringAsFixed(1),
                  ),
                ],
              ),
              _buildDeleteButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteButton() {
    return SizedBox(
      height: 38,
      width: 38,
      child: IconButton(
        style: TextButton.styleFrom(
          backgroundColor: AppTheme.deleteRed,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        onPressed: onDeleteAll,
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final Color? fontColor;

  const _InfoChip({
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
              fontWeight: FontWeight.w700,
              color: foregroundColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamPlayersCard extends StatelessWidget {
  final String title;
  final List<String> players;
  final Color color;

  const _TeamPlayersCard({
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
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AppTheme.grey600),
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
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
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

class _EmptyGamesState extends StatelessWidget {
  const _EmptyGamesState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.grey700
                    : AppTheme.btnBlue1,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.history, size: 34),
            ),
            const SizedBox(height: 18),
            Text(
              'Keine Spiele gefunden',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Sobald du ein Spiel speicherst, erscheint es hier.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppTheme.grey600),
            ),
          ],
        ),
      ),
    );
  }
}

extension _AllGamesDatabaseServiceActions on DatabaseService {
  Future<void> updateGameName(int gameId, String name) async {
    final db = await database;

    await db.update(
      'games',
      {'name': name},
      where: 'id = ?',
      whereArgs: [gameId],
    );
  }

  Future<void> deleteGame(int gameId) async {
    final db = await database;

    await db.delete('games', where: 'id = ?', whereArgs: [gameId]);
  }
}
