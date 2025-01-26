import 'package:flutter/material.dart';
import 'package:teamer/utils/players_list.dart';

class TeamPage extends StatefulWidget {
  TeamPage({super.key});

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  final _controller = TextEditingController();
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
      body: ListView.separated(
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
                      onPressed: null,
                      child: Text(
                        "Neuer Spieler",
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.grey[360],
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
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            width: 65,
            height: 65,
            child: FloatingActionButton(
              foregroundColor: const Color.fromARGB(255, 0, 0, 0),
              backgroundColor: const Color.fromARGB(255, 189, 224, 142),
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
