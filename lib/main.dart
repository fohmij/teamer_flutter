// VERSION 2026-11-12 (BACKUPS): Monats-Backup beim Start und bei Rückkehr zur App.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:teamer/pages/coaching_zone_page.dart';
import 'package:teamer/pages/home_page.dart';
import 'package:teamer/pages/event_page.dart';
import 'package:teamer/pages/team_page.dart';
import 'package:teamer/pages/all_stats_page.dart';
import 'package:teamer/pages/all_games_page.dart';
import 'package:teamer/pages/settings_page.dart';
import 'package:teamer/pages/team_analysis_page.dart';
import 'package:teamer/services/app_settings_controller.dart';
import 'package:teamer/pages/pdf_viewer_page.dart';
import 'package:teamer/services/reminder_notification_service.dart';
import 'package:teamer/services/stats_backup_service.dart';

import 'package:teamer/app_theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // make navigation bar transparent

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(systemNavigationBarColor: Colors.transparent),
  );
  // make flutter draw behind navigation bar
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await appSettingsController.load();
  try {
    await ReminderNotificationService.instance.initialize();

    await ReminderNotificationService.instance.syncWeeklyReminders(
      appSettingsController.value.weeklyReminders,
    );
  } catch (error) {
    debugPrint('Reminder-Initialisierung fehlgeschlagen: $error');
  }
  try {
    await StatsBackupService.instance.createMonthlyBackupIfNeeded();
  } catch (error) {
    debugPrint('Monatliches Statistik-Backup fehlgeschlagen: $error');
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkMonthlyBackup());
    }
  }

  Future<void> _checkMonthlyBackup() async {
    try {
      await StatsBackupService.instance.createMonthlyBackupIfNeeded();
    } catch (error) {
      debugPrint('Monatliches Statistik-Backup fehlgeschlagen: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: appSettingsController,
      builder: (context, settings, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: HomePage(),
          routes: {
            '/eventpage': (context) => EventPage(),
            '/coachingzonepage': (context) => CoachingZonePage(),
            '/rules': (context) => const PdfViewerPage(
              title: 'Schulregelwerk',
              assetPath: 'assets/pdfs/schulregelwerk.pdf',
            ),
            '/exercises': (context) => const PdfViewerPage(
              title: 'Übungen',
              assetPath: 'assets/pdfs/Floorball-Trainingsunterlagen.pdf',
            ),
            '/team': (context) => TeamPage(),
            '/all_stats': (context) => AllStatsPage(),
            '/all_games': (context) => AllGamesPage(),
            '/settings': (context) => SettingsPage(),
            '/team_analysis': (context) => TeamAnalysisPage(),
          },
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: appSettingsController.flutterThemeMode,
        );
      },
    );
  }
}
