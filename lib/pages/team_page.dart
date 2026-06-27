import 'package:flutter/material.dart';
import 'package:teamer/app_theme/app_theme.dart';
import '../database/player.dart';
import 'package:teamer/database/database_services.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

class TeamPage extends StatefulWidget {
  const TeamPage({super.key});

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  final DatabaseService _databaseService = DatabaseService.instance;
  late Future<List<Player>> _playersFuture;

  @override
  void initState() {
    super.initState();
    _playersFuture = _databaseService.getPlayers();
  }

  Future<void> _saveGame({
    required BuildContext context,
    required String title,
    required int teamBWon,
  }) async {
    _showGameDialog(
      context: context,
      title: title,
      onFinish: (gameName) async {
        final players = await _databaseService.getPlayers();

        final teamAIds = players
            .where((p) => p.team == 0 && p.status == 1)
            .map((p) => p.id)
            .toList();

        final teamBIds = players
            .where((p) => p.team == 1 && p.status == 1)
            .map((p) => p.id)
            .toList();

        await _databaseService.addGame(
          name: gameName,
          teamA: teamAIds,
          teamB: teamBIds,
          teamBWon: teamBWon,
        );

        if (teamBWon == 0) {
          await _databaseService.teamAWins();
        } else if (teamBWon == 1) {
          await _databaseService.teamBWins();
        } else {
          await _databaseService.draw();
        }

        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Spiel \'$gameName\' gespeichert')),
        );

        Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Teams'),
        titleTextStyle: Theme.of(context).textTheme.titleLarge,
        centerTitle: false,
        elevation: 0,
        backgroundColor: isDark
            ? AppTheme.navigationBarDark
            : AppTheme.navigationBarLight,
      ),
      body: SafeArea(
        child: FutureBuilder<List<Player>>(
          future: _playersFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final players = snapshot.data!;
            final teamA = players
                .where((p) => p.team == 0 && p.status == 1)
                .toList();

            final teamB = players
                .where((p) => p.team == 1 && p.status == 1)
                .toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(36, 20, 36, 14),
                  child: _HeaderInfo(playerCount: teamA.length + teamB.length),
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _TeamCard(
                          title: 'Team A',
                          players: teamA,
                          color: AppTheme.btnBlue3,
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(4),
                            bottomRight: Radius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TeamCard(
                          title: 'Team B',
                          players: teamB,
                          color: AppTheme.btnBlue2,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(4),
                            bottomLeft: Radius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 36,
                    vertical: 20,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Divider(
                          thickness: 1,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey
                              : AppTheme.grey600,
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Symbols.trophy,
                              size: 18,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey
                                  : AppTheme.grey600,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Spielergebnis festhalten',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.grey
                                        : AppTheme.grey600,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),

                      Expanded(
                        child: Divider(
                          thickness: 1,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey
                              : AppTheme.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ResultButton(
                          label: 'A gewinnt',
                          color: AppTheme.btnBlue3,
                          onPressed: () => _saveGame(
                            context: context,
                            title: 'Team A gewinnt',
                            teamBWon: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ResultButton(
                          icon: Icon(
                            Symbols.handshake,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : AppTheme.grey700,
                            size: 40,
                            fill: 1,
                          ),
                          label: 'Remis',
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.grey700
                              : AppTheme.navigationBarLight,
                          textColor:
                              Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : AppTheme.grey700,
                          onPressed: () => _saveGame(
                            context: context,
                            title: 'Unentschieden',
                            teamBWon: -1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ResultButton(
                          label: 'B gewinnt',
                          color: AppTheme.btnBlue2,
                          onPressed: () => _saveGame(
                            context: context,
                            title: 'Team B gewinnt',
                            teamBWon: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeaderInfo extends StatelessWidget {
  final int playerCount;

  const _HeaderInfo({required this.playerCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Divider(
            thickness: 1,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey
                : AppTheme.grey600,
          ),
        ),
        SizedBox(width: 10,), 
        Icon(
          Icons.group_outlined,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey
              : AppTheme.grey600,
          size: 18.0,
        ),
        SizedBox(width: 5),
        Text(
          '$playerCount Spieler',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey
                : AppTheme.grey600,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
        SizedBox(width: 10,), 
        Expanded(
          child: Divider(
            thickness: 1,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey
                : AppTheme.grey600,
          ),
        ),
      ],
    );
  }
}

class _TeamCard extends StatelessWidget {
  final String title;
  final List<Player> players;
  final Color color;
  final BorderRadius borderRadius;

  const _TeamCard({
    required this.title,
    required this.players,
    required this.color,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.grey700
            : AppTheme.navigationBarLight,
        borderRadius: borderRadius,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            color: color,
            child: Column(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${players.length} Spieler',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: players.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 18,
                endIndent: 18,
                color: AppTheme.grey400.withAlpha(90),
              ),
              itemBuilder: (context, index) {
                final player = players[index];

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          player.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w400,
                                fontSize: 19,
                              ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;
  final Icon icon;
  final Color? textColor;

  const _ResultButton({
    required this.label,
    required this.color,
    required this.onPressed,
    this.icon = const Icon(
      Symbols.trophy,
      size: 40,
      fill: 1,
      color: Colors.white,
    ),
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: color,
          foregroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Column(
            children: [
              icon,
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showGameDialog({
  required BuildContext context,
  required String title,
  required Future<void> Function(String gameName) onFinish,
}) async {
  String? game;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8.0)),
      ),
      title: Text(title, style: Theme.of(context).textTheme.displayLarge),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 30.0),
              child: TextField(
                style: Theme.of(context).textTheme.bodyMedium,
                onChanged: (value) => game = value,
                onSubmitted: (value) async {
                  if (value.isEmpty) return;
                  await onFinish(value);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  hintText: 'Spielname...',
                ),
                autofocus: true,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 50.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 135,
                    height: 40,
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
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text(
                        "Abbrechen",
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ),
                  Spacer(),
                  SizedBox(
                    height: 40,
                    width: 135,
                    child: TextButton(
                      onPressed: () async {
                        if (game == null || game!.trim().isEmpty) return;

                        await onFinish(game!.trim());

                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      },
                      child: Text(
                        "Fertig",
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
