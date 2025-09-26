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
  late Future<List<Game>> _gamesFuture;
  final DatabaseService _databaseService = DatabaseService.instance;

  @override
  void initState() {
    super.initState();
    _gamesFuture = _databaseService.getGames();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Alle Stats'),
        titleTextStyle: Theme.of(context).textTheme.titleLarge,
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.navigationBarDark
            : AppTheme.navigationBarLight,
      ),
      body: FutureBuilder<List<Game>>(
        future: _gamesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text(" Fehler: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Keine Spiele gefunden"));
          } else {
            final games = snapshot.data!;
            return Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    itemCount: games.length,
                    separatorBuilder: (context, index) {
                      return Divider(thickness: 1, height: 1);
                    },
                    itemBuilder: (context, index) {
                      final game = games[index];
                      return ListTile(
                        title: Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: Text(
                                game.name,
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                "Grün: ${game.teamANames} \nRot: ${game.teamBNames} \nSieger: ${game.teamBWon == 1 ? "Rot" : (game.teamBWon == 0 ? "Grün" : "Draw")}",
                                style: Theme.of(context).textTheme.labelSmall
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: Size(170, 60), // Breite = 150, Höhe = 50
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  onPressed: () async {
                    await _databaseService.deleteAllGames();
                    setState(() {
                      _gamesFuture = _databaseService.getGames();
                    });
                  },
                  child: Text(
                    "Löschen",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(height: 200),
              ],
            );
          }
        },
      ),
      extendBody: true,
    );
  }
}
