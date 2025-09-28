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
  //late Future<List<Player>> _playersFuture;
  final DatabaseService _databaseService = DatabaseService.instance;

  int? _sortColumnIndex;
  bool _sortAscending = true;
  List<Player> _players = [];

  @override
  void initState() {
    super.initState();
    _loadPlayers();
  }

  bool _loading = true;

  Future<void> _loadPlayers() async {
    final players = await _databaseService.getPlayers();
    setState(() {
      _players = players;
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _players.isEmpty
          ? const Center(child: Text("Keine Spieler gefunden"))
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: DataTable(
                      sortColumnIndex: _sortColumnIndex,
                      sortAscending: _sortAscending,
                      columnSpacing: 14,
                      columns: [
                        DataColumn(
                          label: Text("Name"),
                          onSort: (i, asc) =>
                              _sort((p) => p.name.toLowerCase(), i, asc),
                        ),
                        DataColumn(
                          label: Text("W"),
                          numeric: true,
                          onSort: (i, asc) => _sort((p) => p.wins, i, asc),
                        ),
                        DataColumn(
                          label: Text("L"),
                          numeric: true,
                          onSort: (i, asc) => _sort((p) => p.losses, i, asc),
                        ),
                        DataColumn(
                          label: Text("D"),
                          numeric: true,
                          onSort: (i, asc) => _sort(
                            (p) => p.attendance - (p.wins + p.losses),
                            i,
                            asc,
                          ),
                        ),
                        DataColumn(
                          label: Text("A"),
                          numeric: true,
                          onSort: (i, asc) =>
                              _sort((p) => p.attendance, i, asc),
                        ),
                        DataColumn(
                          label: Text("%"),
                          numeric: true,
                          onSort: (i, asc) => _sort((p) => p.winRate, i, asc),
                        ),
                      ],
                      rows: _players.map((player) {
                        final int draws =
                            player.attendance - (player.wins + player.losses);
                        return DataRow(
                          cells: [
                            DataCell(Text(player.name)),
                            DataCell(Text(player.wins.toString())),
                            DataCell(Text(player.losses.toString())),
                            DataCell(Text(draws.toString())),
                            DataCell(Text(player.attendance.toString())),
                            DataCell(
                              Text(
                                "${(player.winRate * 100).toStringAsFixed(1)}%",
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // Expanded(
                //   child: ListView.separated(
                //     itemCount: players.length,
                //     separatorBuilder: (context, index) {
                //       return Divider(thickness: 1, height: 1);
                //     },
                //     itemBuilder: (context, index) {
                //       final player = players[index];
                //       return ListTile(
                //         title: Row(
                //           children: [
                //             Text(
                //               "${player.name}:     W: ${player.wins}, L: ${player.losses}, Att.: ${player.attendance} W%: ${player.winRate.toStringAsFixed(2)}",
                //             ),
                //           ],
                //         ),
                //       );
                //     },
                //   ),
                // ),
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: Size(170, 60), // Breite = 150, Höhe = 50
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  onPressed: () async {
                    await _databaseService.resetStats();
                    setState(() {
                      _loadPlayers();
                    });
                  },
                  child: Text(
                    "Reset",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(height: 200),
              ],
            ),
      extendBody: true,
    );
  }
}
