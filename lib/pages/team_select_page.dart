import 'package:flutter/material.dart';
import 'package:teamer/database/database_services.dart';
import 'package:teamer/app_theme/app_theme.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../database/player.dart';

class TeamSelectPage extends StatefulWidget {
  TeamSelectPage({super.key});

  @override
  State<TeamSelectPage> createState() => _TeamSelectPageState();
}

class _TeamSelectPageState extends State<TeamSelectPage> {
  final DatabaseService _databaseService = DatabaseService.instance;

  final FocusNode _focusNode =
      FocusNode(); // um die Tastatur beim Spielererstellen direkt zu öffnen

  String? _player;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
          future: _databaseService.getPlayers(),
          builder: (context, snapshot) {
            return ListView.separated(
                itemCount: (snapshot.data?.length ?? 0) + 1,
                separatorBuilder: (context, index) {
                  return Divider(
                    thickness: 1,
                    height: 1,
                  );
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
                    return Row(
                      children: [
                        Spacer(),
                        Icon(
                          Icons.add,
                          color: AppTheme.grey600,
                        ),
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
                                                  Radius.circular(8.0))),
                                          title: Text('Neuer Spieler',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .displayLarge),
                                          content: SizedBox(
                                            width: 560,
                                            child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 30.0),
                                                    child: TextField(
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium,
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
                                                        _databaseService
                                                            .addPlayer(
                                                                _player!);
                                                        setState(() {
                                                          _player = null;
                                                          _databaseService
                                                              .getPlayers();
                                                        });
                                                        Navigator.pop(
                                                            this.context);
                                                      },
                                                      decoration:
                                                          InputDecoration(
                                                        border: OutlineInputBorder(
                                                            borderSide:
                                                                BorderSide(
                                                                    color: Colors
                                                                        .grey)),
                                                        hintText: 'Name...',
                                                      ),
                                                      focusNode: _focusNode,
                                                      autofocus: true,
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 50.0),
                                                    child: Row(
                                                      children: [
                                                        SizedBox(
                                                          width: 135,
                                                          height: 40,
                                                          child: OutlinedButton(
                                                            onPressed: () {
                                                              Navigator.pop(
                                                                  context);
                                                            },
                                                            child: Text(
                                                              "Abbrechen",
                                                              style: Theme.of(
                                                                      context)
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
                                                                if (_player ==
                                                                        null ||
                                                                    _player ==
                                                                        "") {
                                                                  return;
                                                                }
                                                                _databaseService
                                                                    .addPlayer(
                                                                        _player!);
                                                                setState(() {
                                                                  _player =
                                                                      null;
                                                                });
                                                                Navigator.pop(
                                                                    this.context);
                                                              },
                                                              child: Text(
                                                                "Fertig",
                                                                style: Theme.of(
                                                                        context)
                                                                    .textTheme
                                                                    .displaySmall,
                                                              )),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ]),
                                          ),
                                        ));
                              },
                              child: Text(
                                "Neuer Spieler",
                                style: Theme.of(context).textTheme.labelMedium,
                              )),
                        ),
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
                                                  Radius.circular(8.0))),
                                          content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 6.0),
                                                  child: Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.end,
                                                    children: [
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                bottom: 2.0),
                                                        child: Icon(
                                                          Icons.delete,
                                                          size: 25.0,
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                left: 8.0),
                                                        child: Text(
                                                          'Löschen',
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .displayLarge,
                                                        ),
                                                      )
                                                    ],
                                                  ),
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 6.0),
                                                  child: Divider(),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      vertical: 30.0),
                                                  child: Text(
                                                    'Soll der Spieler wirklich dauerhaft gelöscht werden?',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodyMedium,
                                                  ),
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          bottom: 12.0),
                                                  child: Divider(),
                                                ),
                                                Row(
                                                  children: [
                                                    SizedBox(
                                                      height: 40,
                                                      width: 135,
                                                      child: OutlinedButton(
                                                        onPressed: () {
                                                          Navigator.pop(
                                                              context);
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
                                                        style: TextButton
                                                            .styleFrom(
                                                          backgroundColor:
                                                              AppTheme
                                                                  .deleteRed,
                                                        ),
                                                        onPressed: () {
                                                          _databaseService
                                                              .deletePlayer(
                                                            player.id,
                                                          );
                                                          Navigator.pop(
                                                              this.context);
                                                          setState(() {});
                                                        },
                                                        child: Text(
                                                          "Löschen",
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .displaySmall,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              ]),
                                        ));
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
                            _databaseService.updatePlayerStatus(
                              player.id,
                              newStatus,
                            );
                            setState(() {});
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
                              _databaseService.updatePlayerStatus(
                                player.id,
                                value == true ? 1 : 0,
                              );
                              setState(() {});
                            },
                          ),
                        ),
                      ),
                    );
                  }
                });
          }),
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
              onPressed: () {
                _databaseService.randomTeams();
                Navigator.pushNamed(context, '/team');
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.playlist_add_check_rounded),
                  Text('Team')
                ],
              ),
            ),
          ),
          SizedBox(
            height: 100,
            width: 100,
          ),
        ],
      ),
    );
  }
}


