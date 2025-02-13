import 'package:flutter/material.dart';
import 'package:teamer/database/database_services.dart';
import 'package:teamer/utils/players_list.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../database/player.dart';

class TeamPage extends StatefulWidget {
  TeamPage({super.key});

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  final DatabaseService _databaseService = DatabaseService.instance;

  final _controller = TextEditingController();

  final FocusNode _focusNode =
      FocusNode(); // um die Tastatur beim Spielererstellen direkt zu öffnen

  String? _player;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 243, 250, 236),
      body: FutureBuilder(
          future: _databaseService.getTasks(),
          builder: (context, snapshot) {
            return ListView.separated(
                itemCount: (snapshot.data?.length ?? 0) + 1,
                // itemCount: snapshot.data?.length ?? 0,
                separatorBuilder: (context, index) {
                  return Divider(
                    color: const Color.fromARGB(255, 230, 230, 230),
                    thickness: 1,
                    height: 1,
                  );
                },
                itemBuilder: (context, index) {
                  if (index == (snapshot.data?.length ?? 0)) {
                    return Row(
                      children: [
                        Spacer(),
                        Icon(
                          Icons.add,
                          color: Colors.grey[500],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 24.0),
                          child: TextButton(
                              onPressed: () {
                                showDialog(
                                    context: this.context,
                                    builder: (_) => AlertDialog(
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.all(
                                                  Radius.circular(8.0))),
                                          backgroundColor: Color.fromARGB(
                                              255, 243, 250, 236),
                                          title: Text('Neuer Spieler'),
                                          content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 30.0),
                                                  child: TextField(
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
                                                          .addPlayer(_player!);
                                                      setState(() {
                                                        _player = null;
                                                      });
                                                      Navigator.pop(
                                                          this.context);
                                                    },
                                                    decoration: InputDecoration(
                                                        border: OutlineInputBorder(
                                                            borderSide:
                                                                BorderSide(
                                                                    color: Colors
                                                                        .grey)),
                                                        hintText: 'Name...'),
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
                                                      OutlinedButton(
                                                          style: OutlinedButton
                                                              .styleFrom(
                                                            shape: RoundedRectangleBorder(
                                                                borderRadius: BorderRadius
                                                                    .all(Radius
                                                                        .circular(
                                                                            4.0))),
                                                          ),
                                                          onPressed: () {
                                                            Navigator.pop(
                                                                context);
                                                          },
                                                          child: const Text(
                                                            "Abbrechen",
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.black,
                                                            ),
                                                          )),
                                                      Spacer(),
                                                      SizedBox(
                                                        width: 70.0,
                                                      ),
                                                      Spacer(),
                                                      MaterialButton(
                                                          color: Color
                                                              .fromARGB(255, 21,
                                                                  101, 181),
                                                          onPressed: () {
                                                            if (_player ==
                                                                    null ||
                                                                _player == "") {
                                                              return;
                                                            }
                                                            _databaseService
                                                                .addPlayer(
                                                                    _player!);
                                                            setState(() {
                                                              _player = null;
                                                            });
                                                            Navigator.pop(
                                                                this.context);
                                                          },
                                                          shape: RoundedRectangleBorder(
                                                              borderRadius: BorderRadius
                                                                  .all(Radius
                                                                      .circular(
                                                                          4.0))),
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    vertical:
                                                                        12.0,
                                                                    horizontal:
                                                                        16.0),
                                                            child: const Text(
                                                              "Fertig",
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                            ),
                                                          )),
                                                    ],
                                                  ),
                                                ),
                                              ]),
                                        ));
                              },
                              child: Text(
                                "Neuer Spieler",
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 20.0,
                                  fontWeight: FontWeight.w400,
                                ),
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
                      child: Slidable(
                        startActionPane: ActionPane(
                          extentRatio: 0.2,
                          motion: StretchMotion(),
                          children: [
                            SlidableAction(
                              backgroundColor: Color.fromARGB(255, 185, 88, 81),
                              onPressed: (_) {
                                showDialog(
                                    context: this.context,
                                    builder: (_) => AlertDialog(
                                          backgroundColor: Color.fromARGB(
                                              255, 243, 250, 236),
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
                                                          color:
                                                              Colors.grey[800],
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                left: 8.0),
                                                        child: Text(
                                                          'Löschen',
                                                          style: TextStyle(
                                                            color: Colors.black,
                                                            fontSize: 20.0,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
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
                                                    style: TextStyle(
                                                      color: Colors.black,
                                                      fontSize: 20.0,
                                                    ),
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
                                                    OutlinedButton(
                                                        style: OutlinedButton
                                                            .styleFrom(
                                                          shape: RoundedRectangleBorder(
                                                              borderRadius: BorderRadius
                                                                  .all(Radius
                                                                      .circular(
                                                                          4.0))),
                                                        ),
                                                        onPressed: () {
                                                          Navigator.pop(
                                                              context);
                                                        },
                                                        child: const Text(
                                                          "Abbrechen",
                                                          style: TextStyle(
                                                            color: Colors.black,
                                                          ),
                                                        )),
                                                    Spacer(),
                                                    MaterialButton(
                                                        color: Color.fromARGB(
                                                            255, 185, 88, 81),
                                                        onPressed: () {
                                                          _databaseService
                                                              .deleteTask(
                                                            player.id,
                                                          );
                                                          Navigator.pop(
                                                              this.context);
                                                          setState(() {});
                                                        },
                                                        shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.all(
                                                                    Radius.circular(
                                                                        4.0))),
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  vertical:
                                                                      12.0,
                                                                  horizontal:
                                                                      16.0),
                                                          child: const Text(
                                                            "Löschen",
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          ),
                                                        )),
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
                              ? Color.fromARGB(255, 243, 250, 236)
                              : const Color.fromARGB(255, 139, 204, 101),
                          onTap: () {
                            int newStatus = player.status == 1 ? 0 : 1;
                            _databaseService.updateTaskStatus(
                              player.id,
                              newStatus,
                            );
                            setState(() {});
                          },
                          title: Padding(
                            padding: const EdgeInsets.only(left: 14.0),
                            child: Text(
                              player.name,
                              style: TextStyle(
                                fontSize: 20,
                                // fontWeight: player.status == 1 ? FontWeight.bold : FontWeight.normal
                              ),
                            ),
                          ),
                          trailing: Checkbox(
                            value: player.status == 1,
                            activeColor: Colors.green,
                            onChanged: (value) {
                              _databaseService.updateTaskStatus(
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
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            width: 65,
            height: 65,
            child: FloatingActionButton(
              foregroundColor: const Color.fromARGB(255, 255, 255, 255),
              backgroundColor: const Color.fromARGB(255, 21, 101, 181),
              onPressed: null,
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

/*
        itemCount: players.length + 1,
        itemBuilder: (BuildContext context, index) => (index != players.length)
            ? PlayersList(
                playersName: players[index][0],
                playerSelected: players[index][1],
                onChanged: (value) => checkBoxChanged(index),
                deleteFunction: (context) => deleteTask(index),
              )
            // Add new player Button
            : Padding(
                padding: const EdgeInsets.only(left: 34.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.add,
                      color: const Color.fromARGB(255, 187, 187, 187),
                    ),
                    TextButton(
                      onPressed: () {
                        showDialog(
                            context: this.context,
                            builder: (_) => AlertDialog(
                                  title: const Text('Neuer Spieler'),
                                  content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextField(
                                          onChanged: (value) {
                                            setState(() {
                                              _player = value;
                                            });
                                          },
                                          decoration: InputDecoration(
                                              border: OutlineInputBorder(),
                                              hintText: 'Name...'),
                                          focusNode: _focusNode,
                                          autofocus: true,
                                        ),
                                        MaterialButton(
                                            color: const Color.fromARGB(
                                                255, 189, 224, 142),
                                            onPressed: () {
                                              if (_player == null || _player == "") return;
                                              _databaseService
                                                  .addPlayer(_player!);
                                              setState(() {
                                                _player = null;
                                              });
                                              Navigator.pop(this.context);
                                            },
                                            child: const Text(
                                              "Fertig",
                                              style: TextStyle(
                                                color: Colors.black,
                                              ),
                                            ))
                                      ]),
                                ));
                        // Verzögere die Fokussierung minimal, damit die Tastatur sicher erscheint
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _focusNode.requestFocus();
                        });
                      },
                      child: Text(
                        "Neuer Spieler",
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        separatorBuilder: (context, index) {
          return Divider(
            color: const Color.fromARGB(255, 230, 230, 230),
            thickness: 1,
            height: 1,
          );
        },

  List players = [
    ['Ava Mitchell', false],
    ['Aiden Morgan', false],
    ['Emma Hayes', false],
    ['Ethan Parker', false],
    ['Harper Sullivan', false],
    ['Jackson Reed', false],
    ['Logan Brooks', false],
    ['Mason Cooper', false],
    ['Olivia Bennett', false],
    ['Sophia Carter', false],
  ];

  void checkBoxChanged(int index) {
    setState(() {
      players[index][1] = !players[index][1];
    });
  }
  void saveNewPlayer() {
    setState(() {
      players.add([_controller.text, false]);
      _controller.clear();
    });
  }

  void saveNewPlayerEnter(String playerName) {
    setState(() {
      players.add([playerName, false]);
      _controller.clear();
    });
  }

  void deleteTask(int index) {
    setState(() {
      players.removeAt(index);
    });
  }

        */
