import 'package:flutter/material.dart';
import 'package:teamer/pages/team_page.dart';
import 'package:teamer/pages/stats_page.dart';

class HomePage extends StatefulWidget {
  HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var currentPageIndex = 0;

  var appBarTitle = 'Spieler wählen';

  // Funktion updateAppBarTitle()
  void updateAppBarTitle() {
    switch (currentPageIndex) {
      case 0:
        appBarTitle = 'Spieler wählen';
      case 1:
        appBarTitle = 'Events & Scoreboard';
      default:
        appBarTitle = 'Spieler wählen';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Color.fromARGB(255, 243, 250, 236),
        appBar: AppBar(
          title: Text(appBarTitle,
              style: TextStyle(
                color: Colors.black,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto',
              )),
          backgroundColor: Color.fromARGB(255, 243, 250, 236),
        ),
        body: [
          TeamPage(),
          StatsPage(),
        ][currentPageIndex],
        extendBody: true,
        bottomNavigationBar: Stack(children: <Widget>[
          NavigationBar(
            destinations: [
              NavigationDestination(
                  icon: Icon(Icons.group_outlined), label: "Team"),
              NavigationDestination(
                  icon: Icon(Icons.star_border), label: "Stats")
            ],
            selectedIndex: currentPageIndex,
            onDestinationSelected: (int index) {
              setState(() {
                currentPageIndex = index;
                updateAppBarTitle();
              });
            },
            backgroundColor: const Color.fromARGB(199, 204, 238, 204),
            indicatorColor: const Color.fromARGB(255, 174, 223, 178),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
            SizedBox(
              height: 75,
            ),
            Text(
              'Teamer',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 21,
                  fontStyle: FontStyle.italic),
            ),
          ]),
        ]));
  }
}
