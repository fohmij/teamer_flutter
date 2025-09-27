import 'package:flutter/material.dart';
import 'package:teamer/app_theme/app_theme.dart';
import '../database/player.dart';
import 'package:teamer/database/database_services.dart';

class TeamPage extends StatefulWidget {
  const TeamPage({super.key});

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  final DatabaseService _databaseService = DatabaseService.instance;

  late Future<List<Player>> _playersFuture;

  String? _game;

  final FocusNode _focusNode =
      FocusNode(); // um die Tastatur beim Spielererstellen direkt zu öffnen

  @override
  void initState() {
    super.initState();
    _playersFuture = _databaseService.getPlayers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Teams'),
        titleTextStyle: Theme.of(context).textTheme.titleLarge,
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.navigationBarDark
            : AppTheme.navigationBarLight,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, top: 16.0),
                    child: Text(
                      'Team Grün',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.green,
                      ),
                    ),
                  ),
                  FutureBuilder<List<Player>>(
                    future: _playersFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return CircularProgressIndicator();

                      final filtered = snapshot.data!
                          .where(
                            (player) => player.team == 0 && player.status == 1,
                          )
                          .toList();

                      final height = (filtered.length) * 60.0;

                      return SizedBox(
                        height: height,
                        child: ListView.separated(
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            return ListTile(
                              title: Row(
                                children: [
                                  Text(
                                    filtered[index].name,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                  SizedBox(width: 20),
                                  Text(
                                    filtered[index].winRate.toStringAsFixed(2),
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w300,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          separatorBuilder: (context, index) =>
                              Divider(height: 1),
                        ),
                      );
                    },
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: Text(
                        'Team Rot',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ),
                  FutureBuilder<List<Player>>(
                    future: _playersFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return CircularProgressIndicator();
                      }
                      final filtered = snapshot.data!
                          .where(
                            (player) => player.team == 1 && player.status == 1,
                          )
                          .toList();

                      final height = (filtered.length) * 60.0;

                      return SizedBox(
                        height: height,
                        child: ListView.separated(
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            return ListTile(
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    filtered[index].winRate.toStringAsFixed(2),
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w300,
                                    ),
                                  ),
                                  SizedBox(width: 20),
                                  Text(
                                    filtered[index].name,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            );
                          },
                          separatorBuilder: (context, index) =>
                              Divider(height: 1),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 60),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                mainAxisSize:
                    MainAxisSize.min, // nimmt nur so viel Platz wie nötig
                children: [
                  FutureBuilder<double>(
                    future: _databaseService.getWinRateDifference(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator(); // Lade-Spinner
                      } else if (snapshot.hasError) {
                        return Text("Fehler: ${snapshot.error}");
                      } else {
                        return Text(
                          "WinRateDelta: ${snapshot.data!.toStringAsFixed(2)}", // z.B. "0.25"
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w300,
                          ),
                        );
                      }
                    },
                  ),
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextButton(
                          onPressed: () {
                            _showGameDialog(
                              context: context,
                              title: "Grün gewinnt",
                              onFinish: (gameName) async {
                                final players = await _databaseService
                                    .getPlayers();

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
                                  teamBWon: 0,
                                );

                                await _databaseService.teamAWins();

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Grün gewinnt",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );

                                Navigator.of(
                                  context,
                                ).pop(); // zurück zur TeamSelectPage
                              },
                            );
                          },
                          style: TextButton.styleFrom(
                            minimumSize: const Size(120, 70),
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(0),
                            ),
                          ),
                          child: const Text(
                            "Grün \ngewinnt",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: TextButton(
                          onPressed: () {
                            _showGameDialog(
                              context: context,
                              title: "Draw (Unentschieden)",
                              onFinish: (gameName) async {
                                final players = await _databaseService
                                    .getPlayers();

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
                                  teamBWon: -1,
                                );

                                await _databaseService.draw();

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Draw",
                                    ),
                                  ),
                                );

                                Navigator.of(
                                  context,
                                ).pop(); // zurück zur TeamSelectPage
                              },
                            );
                          },
                          style: TextButton.styleFrom(
                            minimumSize: const Size(120, 70),
                            backgroundColor: Theme.of(
                              context,
                            ).cardColor, //const Color.fromARGB(255, 84, 75, 95),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(0),
                            ),
                          ),
                          child: Text(
                            "Draw",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.color,
                            ),
                          ),
                        ),
                      ),
                      // SizedBox(width: 10.0),
                      Expanded(
                        flex: 2,
                        child: TextButton(
                          onPressed: () {
                            _showGameDialog(
                              context: context,
                              title: "Rot gewinnt",
                              onFinish: (gameName) async {
                                final players = await _databaseService
                                    .getPlayers();

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
                                  teamBWon: 1,
                                );

                                await _databaseService.teamBWins();

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Rot gewinnt",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );

                                Navigator.of(
                                  context,
                                ).pop(); // zurück zur TeamSelectPage
                              },
                            );
                          },
                          style: TextButton.styleFrom(
                            minimumSize: const Size(120, 70),
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(0),
                            ),
                          ),
                          child: const Text(
                            "Rot \ngewinnt",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // SizedBox(height: 100),
          ],
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
  final focusNode = FocusNode();

  return showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        shape: const RoundedRectangleBorder(
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
                  autofocus: true,
                  focusNode: focusNode,
                  style: Theme.of(context).textTheme.bodyMedium,
                  onChanged: (value) => game = value,
                  onSubmitted: (value) async {
                    if (value.isEmpty) return;
                    await onFinish(value);
                    Navigator.of(dialogContext).pop();
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Name...',
                  ),
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
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text(
                          "Abbrechen",
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      height: 40,
                      width: 135,
                      child: TextButton(
                        onPressed: () async {
                          if (game == null || game!.isEmpty) return;
                          await onFinish(game!);
                          Navigator.of(dialogContext).pop();
                        },
                        child: Text(
                          "Speichern",
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
      );
    },
  );
}
