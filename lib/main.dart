import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:teamer/pages/coaching_zone_page.dart';
import 'package:teamer/pages/exercises_page.dart';
import 'package:teamer/pages/home_page.dart';
import 'package:teamer/pages/event_page.dart';
import 'package:teamer/pages/rules_page.dart';
import 'package:teamer/pages/team_page.dart';
import 'package:teamer/pages/all_stats_page.dart';

import 'package:teamer/app_theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // make navigation bar transparent
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  // make flutter draw behind navigation bar
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
       return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: HomePage(),
        routes: {
          '/eventpage': (context) => EventPage(),
          '/coachingzonepage': (context) => CoachingZonePage(),
          '/rules': (context) => RulesPage(),
          '/exercises': (context) => ExercisesPage(),
          '/team': (context) => TeamPage(),
          '/all_stats': (context) => AllStatsPage(),
        },
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
      );
  }
}
