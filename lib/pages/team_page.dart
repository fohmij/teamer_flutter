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
    ['Jan Imhof', false],
    ['Matti Schlutz', false],
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

  void openDialog() => showDialog(
        context: context,
        builder: (context) => AlertDialog(
          alignment: Alignment.bottomCenter,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.zero)),
          content: Builder(builder: (context) {
            var width = MediaQuery.of(context).size.width;
            return SizedBox(
              width: width,
              child: TextField(
                decoration:
                    InputDecoration(hintText: 'Spielername eingeben ...'),
              ),
            );
          }),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 243, 250, 236),
      body: Stack(children: <Widget>[
        ListView.separated(
          itemCount: players.length,
          itemBuilder: (BuildContext context, index) {
            return PlayersList(
              playersName: players[index][0],
              playerSelected: players[index][1],
              onChanged: (value) => checkBoxChanged(index),
              deleteFunction: (context) => deleteTask(index),
            );
          },
          separatorBuilder: (context, index) {
            return Divider(
              color: const Color.fromARGB(255, 230, 230, 230),
              thickness: 1,
              height: 1,
            );
          },
        ),
      ]),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            width: 65,
            height: 65,
            child: FloatingActionButton(
              foregroundColor: const Color.fromARGB(255, 0, 0, 0),
              backgroundColor: const Color.fromARGB(255, 189, 224, 142),
              onPressed: openDialog,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Icon(Icons.add), Text('Spieler')],
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
