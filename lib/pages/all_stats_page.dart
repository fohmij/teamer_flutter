import 'package:flutter/material.dart';
import 'package:teamer/app_theme/app_theme.dart';
import 'package:teamer/database/database_services.dart';
import 'package:teamer/database/player.dart';

class AllStatsPage extends StatefulWidget {
  const AllStatsPage({super.key});

  @override
  State<AllStatsPage> createState() => _AllStatsPageState();
}

class _AllStatsPageState extends State<AllStatsPage> {
  late Future<List<Player>> _playersFuture;
  final DatabaseService _databaseService = DatabaseService.instance;

  @override
  void initState() {
    super.initState();
    _playersFuture = _databaseService.getPlayers();
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
      body: FutureBuilder<List<Player>>(
        future: _playersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text(" Fehler: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Keine Spieler gefunden"));
          } else {
            final players = snapshot.data!;
            return Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    itemCount: players.length,
                    separatorBuilder: (context, index) {
                      return Divider(thickness: 1, height: 1);
                    },
                    itemBuilder: (context, index) {
                      final player = players[index];
                      return ListTile(
                        title: Text(
                          "${player.name}:     W: ${player.wins}, L: ${player.losses}, Att.: ${player.attendance} W%: ${player.winRate.toStringAsFixed(2)}",
                        ),
                      );
                    },
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: Size(170, 60), // Breite = 150, Höhe = 50
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25)
                    )
                  ),
                  onPressed: () async {
                    await _databaseService.resetStats();
                    setState(() {
                      _playersFuture = _databaseService.getPlayers();
                    });
                  },
                  child: Text("Reset", style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  )),
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
