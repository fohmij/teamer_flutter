import 'package:flutter/material.dart';
import 'package:teamer/app_theme/app_theme.dart';
import 'package:teamer/pages/team_select_page.dart';
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
        appBar: AppBar(
            title: Text(
          appBarTitle,
          style: Theme.of(context).textTheme.titleLarge,
        )),
        body: [
          TeamSelectPage(),
          StatsPage(),
        ][currentPageIndex],
        extendBody: true,
        bottomNavigationBar: Stack(
          children: <Widget>[
            Container(
              color: Colors.transparent,
              child: NavigationBar(
                destinations: [
                  NavigationDestination(
                    icon: Icon(
                      Icons.group_outlined,
                      color:
                          currentPageIndex == 0 ? Colors.white : AppTheme.grey800,
                    ),
                    label: "Team",
                    selectedIcon: Icon(
                      Icons.group_outlined,
                      color: Colors.white,
                    ),
                  ),
                  NavigationDestination(
                    icon: Icon(
                      Icons.star_border,
                      color:
                          currentPageIndex == 1 ? Colors.white : AppTheme.grey800,
                    ),
                    label: "Stats",
                    selectedIcon: Icon(
                      Icons.star_border,
                      color: Colors.white,
                    ),
                  ),
                ],
                selectedIndex: currentPageIndex,
                onDestinationSelected: (int index) {
                  setState(() {
                    currentPageIndex = index;
                    updateAppBarTitle();
                  });
                },
              ),
            ),
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Teamer',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 21,
                    color: 
                    Theme.of(context).brightness == Brightness.dark ? AppTheme.grey300 : AppTheme.grey600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ],
        ));
  }
}
