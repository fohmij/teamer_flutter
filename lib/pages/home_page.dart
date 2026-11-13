// VERSION 2026-11-13 (TABLET-UI): Navigation und FAB-Abstaende an Android-Systemleisten anpassen.
import 'package:flutter/material.dart';
import 'package:teamer/app_theme/app_theme.dart';
import 'package:teamer/pages/team_select_page.dart';
import 'package:teamer/pages/stats_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var currentPageIndex = 1;

  var appBarTitle = 'Events & Scoreboard';

  // Funktion updateAppBarTitle()
  void updateAppBarTitle() {
    switch (currentPageIndex) {
      case 0:
        appBarTitle = 'Spieler wählen';
      case 1:
        appBarTitle = 'Events & Scoreboard';
      default:
        appBarTitle = 'Events & Scoreboard';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Die NavigationBar beruecksichtigt den Systemleisten-Abstand selbst.
    // Die mittige Beschriftung wird nur im 80-dp-Inhaltsbereich zentriert.
    final bottomSystemInset = MediaQuery.viewPaddingOf(context).bottom;
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0, // Damit es die Farbe nicht änder wenn man die Playersliste nach unten Scrollt
        backgroundColor: isDark
                  ? AppTheme.navigationBarDark
                  : AppTheme.navigationBarLight,
        // backgroundColor: currentPageIndex == 0
        //     ? (isDark
        //           ? AppTheme.navigationBarDark
        //           : AppTheme.navigationBarLight)
        //     : (isDark
        //           ? AppTheme.backgroundColorDark
        //           : AppTheme.backgroundColorLight),
        title: Text(appBarTitle, style: Theme.of(context).textTheme.titleLarge),
        actions: currentPageIndex == 1
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: IconButton(
                    tooltip: 'Einstellungen',
                    onPressed: () => Navigator.pushNamed(context, '/settings'),
                    icon: const Icon(Icons.settings),
                  ),
                ),
              ]
            : null,
      ),
      body: [TeamSelectPage(), StatsPage()][currentPageIndex],
      // Der Seiteninhalt endet oberhalb der Navigationsleiste. So koennen
      // innere Scaffolds ihre Floating Action Buttons korrekt positionieren.
      extendBody: false,
      bottomNavigationBar: Stack(
        children: [
          // Die NavigationBar nimmt den Platz fuer die Android-Systemleiste
          // selbst ein; ihre sichtbare Leiste bleibt 80 dp hoch.
          NavigationBar(
            height: 80,
            maintainBottomViewPadding: true,
            indicatorShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            destinations: [
              NavigationDestination(
                icon: Icon(
                  Icons.group_outlined,
                  color: currentPageIndex == 0
                      ? Colors.white
                      : AppTheme.grey800,
                ),
                label: 'Team',
                selectedIcon: const Icon(
                  Icons.group_outlined,
                  color: Colors.white,
                ),
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.star_border,
                  color: currentPageIndex == 1
                      ? Colors.white
                      : AppTheme.grey800,
                ),
                label: 'Stats',
                selectedIcon: const Icon(
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
          // Nur die 80 dp hohe Navigationsleiste zentrieren, nicht den
          // zusaetzlichen Bereich der Android-Systemnavigation.
          Positioned.fill(
            bottom: bottomSystemInset,
            child: IgnorePointer(
              child: Center(
                child: Text(
                  'Teamer',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 21,
                    color: isDark ? AppTheme.grey400 : AppTheme.grey800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
