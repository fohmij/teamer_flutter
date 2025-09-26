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
                  // Row(
                  //   mainAxisAlignment: MainAxisAlignment.center,
                  //   children: [
                  //     SizedBox(
                  //       height: 100,
                  //       width: 100,
                  //       child: TextField(
                  //         style: TextStyle(
                  //           fontWeight: FontWeight.w900,
                  //           color: Colors.green,
                  //         ),
                  //         keyboardType: TextInputType.numberWithOptions(),
                  //         textAlign: TextAlign.center,
                  //         decoration: InputDecoration(
                  //           hintText: 'Grün',
                  //           hintStyle: TextStyle(
                  //             fontWeight: FontWeight.w800,
                  //             fontStyle: FontStyle.italic,
                  //             color: Colors.green,
                  //           ),
                  //         ),
                  //       ),
                  //     ),
                  //     Padding(
                  //       padding: const EdgeInsets.only(bottom: 32, left: 20, right: 20),
                  //       child: Text(
                  //         'Tore',
                  //         style: Theme.of(context).textTheme.bodyLarge,
                  //       ),
                  //     ),
                  //     SizedBox(
                  //       height: 100,
                  //       width: 100,
                  //       child: TextField(
                  //         style: TextStyle(
                  //           fontWeight: FontWeight.w900,
                  //           color: Colors.red,
                  //         ),
                  //         keyboardType: TextInputType.numberWithOptions(),
                  //         textAlign: TextAlign.center,
                  //         decoration: InputDecoration(
                  //           hintText: 'Rot',
                  //           hintStyle: TextStyle(
                  //             fontWeight: FontWeight.w800,
                  //             fontStyle: FontStyle.italic,
                  //             color: Colors.red,
                  //           ),
                  //         ),
                  //       ),
                  //     ),
                  //   ],
                  // ),
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
                            _databaseService.teamAWins();
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Grün gewinnt",
                                  style: TextStyle(color: Colors.white),
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                            //Fluttertoast.showToast(msg: "Grün gewinnt");
                          },
                          style: TextButton.styleFrom(
                            minimumSize: Size(120, 70),
                            backgroundColor: const Color.fromARGB(
                              255,
                              68,
                              155,
                              71,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(0),
                            ),
                          ),
                          child: Text(
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
                      // SizedBox(width: 10.0),
                      Expanded(
                        flex: 1,
                        child: TextButton(
                          onPressed: () {
                            _databaseService.draw();
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Unentschieden",
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            minimumSize: Size(80, 70),
                            backgroundColor: Theme.of(
                              context,
                            ).cardColor, //const Color.fromARGB(255, 84, 75, 95),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(0),
                            ),
                          ),
                          child: Text(
                            "Draw",
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
                            _databaseService.teamBWins();
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Rot gewinnt",
                                  style: TextStyle(color: Colors.white),
                                  textAlign: TextAlign.right,
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            minimumSize: Size(120, 70),
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(0),
                            ),
                          ),
                          child: Text(
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
