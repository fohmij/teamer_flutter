import 'package:flutter/material.dart';
import 'package:teamer/database/database_services.dart';
import 'package:teamer/utils/players_list.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 243, 250, 236),
      body: FutureBuilder(
          future: _databaseService.getTasks(),
          builder: (context, snapshot) {
            return ListView.separated(
                itemCount: snapshot.data?.length ?? 0,
                separatorBuilder: (context, index) {
                  return Divider(
                    color: const Color.fromARGB(255, 230, 230, 230),
                    thickness: 1,
                    height: 1,
                  );
                },
                itemBuilder: (context, index) {
                  Player player = snapshot.data![index];
                  return ListTile(
                    onLongPress: () {
                      _databaseService.deleteTask(
                        player.id,
                      );
                      setState(() {});
                    },
                    title: Padding(
                      padding: const EdgeInsets.only(left: 14.0),
                      child: Text(
                        player.name,
                        style: TextStyle(
                          fontSize: 20,
                        ),
                      ),
                    ),
                    trailing: Checkbox(
                      value: player.status == 1,
                      onChanged: (value) {
                        _databaseService.updateTaskStatus(
                          player.id,
                          value == true ? 1 : 0,
                        );
                        setState(() {});
                      },
                    ),
                  );
                });
          }),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            width: 65,
            height: 65,
            child: FloatingActionButton(
              foregroundColor: const Color.fromARGB(255, 0, 0, 0),
              backgroundColor: const Color.fromARGB(255, 189, 224, 142),
              onPressed: () {
                showDialog(
                    context: this.context,
                    builder: (_) => AlertDialog(
      backgroundColor: Color.fromARGB(255, 243, 250, 236),
                          title: const Text('Neuer Spieler'),
                          content:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            TextField(
                              onChanged: (value) {
                                setState(() {
                                  _player = value;
                                });
                              },
                              decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.grey)
                                  ),
                                  hintText: 'Name...'),
                              focusNode: _focusNode,
                              autofocus: true,
                            ),
                            MaterialButton(
                                color: const Color.fromARGB(255, 189, 224, 142),
                                onPressed: () {
                                  if (_player == null || _player == "") {
                                    return;
                                  }
                                  _databaseService.addPlayer(_player!);
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
        */
