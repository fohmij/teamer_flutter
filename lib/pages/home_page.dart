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
          NavigationBarTheme(
            data: NavigationBarThemeData(
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
        (Set<WidgetState> states) => states.contains(WidgetState.selected)
            ? const TextStyle(color: Colors.white)
            : const TextStyle(color: Colors.white),
      ),
    ),

            child: NavigationBar(
              destinations: [
                NavigationDestination(
                    icon: Icon(Icons.group_outlined, color: Colors.white,), label: "Team"),
                NavigationDestination(
                    icon: Icon(Icons.star_border, color: Colors.white,), label: "Stats")
              ],
              selectedIndex: currentPageIndex,
              onDestinationSelected: (int index) {
                setState(() {
                  currentPageIndex = index;
                  updateAppBarTitle();
                });
              },
              backgroundColor: const Color.fromARGB(198, 38, 96, 171),
              indicatorColor: const Color.fromARGB(255, 30, 89, 148),
            ),
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
                  color: Colors.grey[300],
                  fontStyle: FontStyle.italic),
            ),
          ]),
        ]));
  }
}
