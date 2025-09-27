import 'package:flutter/material.dart';
import 'package:teamer/database/database_services.dart';
import 'package:teamer/app_theme/app_theme.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../database/player.dart';
import 'package:fluttertoast/fluttertoast.dart';

class TeamSelectPage extends StatefulWidget {
  const TeamSelectPage({super.key});

  @override
  State<TeamSelectPage> createState() => _TeamSelectPageState();
}

class _TeamSelectPageState extends State<TeamSelectPage> {
  final DatabaseService _databaseService = DatabaseService.instance;

  final FocusNode _focusNode =
      FocusNode(); // um die Tastatur beim Spielererstellen direkt zu öffnen

  String? _player;

  bool allBtnSelected = false;

  late Future<List<Player>> _playersFuture;

  @override
  void initState() {
    super.initState();
    _playersFuture = _databaseService.getPlayers();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _playersFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final players = snapshot.data!;
        final selectedCount = players.where((p) => p.status == 1).length;
        final enoughPlayers = selectedCount >= 2;
        final notTooManyPlayers = selectedCount <= 30;

        final allAreSelected =
            players.isNotEmpty && players.every((p) => p.status == 1);
        if (allBtnSelected != allAreSelected) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              allBtnSelected = allAreSelected;
            });
          });
        }
        return Scaffold(
          body: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 15),
                      Text(
                        "Name",
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Text(
                            "Alle",
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          Checkbox(
                            value: allBtnSelected,
                            activeColor: Colors.green,
                            onChanged: (bool? value) async {
                              final newStatus = value == true ? 1 : 0;
                              await _databaseService.updateAllPlayersStatus(
                                newStatus,
                              );
                              setState(() {
                                allBtnSelected = value ?? false;
                                _playersFuture = _databaseService.getPlayers();
                              });
                            },
                          ),
                          SizedBox(width: 24),
                        ],
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Text(
                      "($selectedCount)",
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: (snapshot.data?.length ?? 0) + 1,
                  separatorBuilder: (context, index) {
                    return Divider(thickness: 1, height: 1);
                  },
                  /*
                #######################################################################################
                #######################################################################################
                #######################################################################################
                #######################################################################################
                #######################################################################################
                Spieler hinzufügen
                */
                  itemBuilder: (context, index) {
                    if (index == (snapshot.data?.length ?? 0)) {
                      return Column(
                        children: [
                          Row(
                            children: [
                              Spacer(),
                              Icon(Icons.add, color: AppTheme.grey600),
                              Padding(
                                padding: const EdgeInsets.only(right: 25.0),
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                  ),
                                  onPressed: () {
                                    showDialog(
                                      context: this.context,
                                      builder: (_) => AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.all(
                                            Radius.circular(8.0),
                                          ),
                                        ),
                                        title: Text(
                                          'Neuer Spieler',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.displayLarge,
                                        ),
                                        content: SizedBox(
                                          width: 560,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 30.0,
                                                ),
                                                child: TextField(
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.bodyMedium,
                                                  onChanged: (value) {
                                                    setState(() {
                                                      _player = value;
                                                    });
                                                  },
                                                  onSubmitted: (value) {
                                                    if (_player == null ||
                                                        _player == "") {
                                                      return;
                                                    }
                                                    _databaseService.addPlayer(
                                                      _player!,
                                                    );
                                                    setState(() {
                                                      _player = null;
                                                      _playersFuture =
                                                          _databaseService
                                                              .getPlayers();
                                                    });
                                                    Navigator.pop(this.context);
                                                  },
                                                  decoration: InputDecoration(
                                                    border: OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                    hintText: 'Name...',
                                                  ),
                                                  focusNode: _focusNode,
                                                  autofocus: true,
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 50.0,
                                                ),
                                                child: Row(
                                                  children: [
                                                    SizedBox(
                                                      width: 135,
                                                      height: 40,
                                                      child: OutlinedButton(
                                                        onPressed: () {
                                                          Navigator.pop(
                                                            context,
                                                          );
                                                        },
                                                        child: Text(
                                                          "Abbrechen",
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .labelSmall,
                                                        ),
                                                      ),
                                                    ),
                                                    Spacer(),
                                                    SizedBox(
                                                      height: 40,
                                                      width: 135,
                                                      child: TextButton(
                                                        onPressed: () {
                                                          if (_player == null ||
                                                              _player == "") {
                                                            return;
                                                          }
                                                          _databaseService
                                                              .addPlayer(
                                                                _player!,
                                                              )
                                                              .then((_) {
                                                                setState(() {
                                                                  _player =
                                                                      null;
                                                                  _playersFuture =
                                                                      _databaseService
                                                                          .getPlayers(); // 🔁 wichtig
                                                                });
                                                                Navigator.pop(
                                                                  // ignore: use_build_context_synchronously
                                                                  this.context,
                                                                );
                                                              });
                                                        },
                                                        child: Text(
                                                          "Fertig",
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .displaySmall,
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
                                  },
                                  child: Text(
                                    "Neuer Spieler",
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelMedium,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 190),
                        ],
                      );
                    } else {
                      Player player = snapshot.data![index];
                      return Theme(
                        data: Theme.of(context).copyWith(
                          outlinedButtonTheme: const OutlinedButtonThemeData(
                            style: ButtonStyle(
                              iconColor: WidgetStatePropertyAll(Colors.white),
                            ),
                          ),
                        ),
                        /*
                #######################################################################################
                #######################################################################################
                #######################################################################################
                #######################################################################################
                #######################################################################################
                Spieler löschen
                */
                        child: Slidable(
                          startActionPane: ActionPane(
                            extentRatio: 0.2,
                            motion: StretchMotion(),
                            children: [
                              SlidableAction(
                                backgroundColor: AppTheme.deleteRed,
                                onPressed: (_) {
                                  showDialog(
                                    context: this.context,
                                    builder: (_) => AlertDialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(8.0),
                                        ),
                                      ),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 6.0,
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 2.0,
                                                      ),
                                                  child: Icon(
                                                    Icons.delete,
                                                    size: 25.0,
                                                  ),
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        left: 8.0,
                                                      ),
                                                  child: Text(
                                                    'Löschen',
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.displayLarge,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 6.0,
                                            ),
                                            child: Divider(),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 30.0,
                                            ),
                                            child: Text(
                                              'Soll der Spieler wirklich dauerhaft gelöscht werden?',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodyMedium,
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 12.0,
                                            ),
                                            child: Divider(),
                                          ),
                                          Row(
                                            children: [
                                              SizedBox(
                                                height: 40,
                                                width: 135,
                                                child: OutlinedButton(
                                                  onPressed: () {
                                                    Navigator.pop(context);
                                                  },
                                                  child: Text(
                                                    "Abbrechen",
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.labelSmall,
                                                  ),
                                                ),
                                              ),
                                              Spacer(),
                                              SizedBox(
                                                height: 40,
                                                width: 135,
                                                child: TextButton(
                                                  style: TextButton.styleFrom(
                                                    backgroundColor:
                                                        AppTheme.deleteRed,
                                                  ),
                                                  onPressed: () {
                                                    _databaseService
                                                        .deletePlayer(player.id)
                                                        .then((_) {
                                                          setState(() {
                                                            _playersFuture =
                                                                _databaseService
                                                                    .getPlayers();
                                                          });
                                                        });
                                                    Navigator.pop(this.context);
                                                  },
                                                  child: Text(
                                                    "Löschen",
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.displaySmall,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                                icon: Icons.delete,
                                borderRadius: BorderRadius.circular(7),
                                foregroundColor: Colors.white,
                              ),
                            ],
                          ),
                          child: ListTile(
                            tileColor: player.status == 0
                                ? Theme.of(context).scaffoldBackgroundColor
                                : AppTheme.playerSelected,
                            onTap: () {
                              int newStatus = player.status == 1 ? 0 : 1;
                              _databaseService
                                  .updatePlayerStatus(player.id, newStatus)
                                  .then((_) {
                                    setState(() {
                                      _playersFuture = _databaseService
                                          .getPlayers();
                                    });
                                  });
                            },
                            title: Padding(
                              padding: const EdgeInsets.only(left: 14.0),
                              child: Text(
                                player.name,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            trailing: Checkbox(
                              value: player.status == 1,
                              activeColor: Colors.green,
                              onChanged: (value) {
                                final newStatus = value == true ? 1 : 0;
                                _databaseService
                                    .updatePlayerStatus(player.id, newStatus)
                                    .then((_) async {
                                      final players = await _databaseService
                                          .getPlayers();

                                      setState(() {
                                        _playersFuture = Future.value(players);

                                        // wenn einer abgewählt wurde → allBtnSelected = false
                                        if (newStatus == 0 && allBtnSelected) {
                                          allBtnSelected = false;
                                        } else {
                                          // neu prüfen ob jetzt wirklich ALLE ausgewählt sind
                                          allBtnSelected =
                                              players.isNotEmpty &&
                                              players.every(
                                                (p) => p.status == 1,
                                              );
                                        }
                                      });
                                    });
                              },
                            ),
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          /*
          #######################################################################################
          #######################################################################################
          #######################################################################################
          #######################################################################################
          #######################################################################################
          Floating Action Button
          */
          floatingActionButton: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                width: 65,
                height: 65,
                child: FloatingActionButton(
                  heroTag: "randomBtn",
                  onPressed: () async {
                    if (enoughPlayers) {
                      await _databaseService.randomTeams();
                      Navigator.pushNamed(context, '/team');
                    } else {
                      Fluttertoast.showToast(
                        msg: "Bitte min. 2 Spieler auswählen",
                        toastLength: Toast.LENGTH_SHORT,
                        gravity: ToastGravity.BOTTOM,
                        backgroundColor:
                            Theme.of(context).brightness == Brightness.dark
                            ? Colors.black
                            : Colors.white,
                        textColor:
                            Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                      );
                    }
                  },
                  backgroundColor: const Color.fromARGB(255, 190, 75, 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.casino_outlined),
                      Text('Random', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20, width: 100),
              SizedBox(
                width: 65,
                height: 65,
                child: FloatingActionButton(
                  heroTag: "partitionBtn",
                  onPressed: () async {
                    if (enoughPlayers && notTooManyPlayers) {
                      await _databaseService.optimizedTeam();
                      Navigator.pushNamed(context, '/team').then((_) {
                        setState(() {
                          _playersFuture = _databaseService.getPlayers();
                        });
                      });
                    } else {
                      Fluttertoast.showToast(
                        msg: "Bitte 2-20 Spieler auswählen",
                        toastLength: Toast.LENGTH_SHORT,
                        gravity: ToastGravity.BOTTOM,
                        backgroundColor:
                            Theme.of(context).brightness == Brightness.dark
                            ? Colors.black
                            : Colors.white,
                        textColor:
                            Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                      );
                    }
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.playlist_add_check_rounded),
                      Text('Team'),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 110, width: 100),
            ],
          ),
        );
      },
    );
  }
}
