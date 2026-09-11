import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:teamer/services/app_settings_service.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class ReminderNotificationService {
  static final ReminderNotificationService instance =
      ReminderNotificationService._constructor();

  ReminderNotificationService._constructor();

  static const int _firstReminderNotificationId = 10000;
  static const int _lastReminderNotificationId = 99999999;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimezone.identifier));
    } catch (_) {
      // Falls die Geräte-Zeitzone nicht aufgelöst werden kann, bleibt die
      // Standard-Zeitzone des timezone-Pakets aktiv.
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _notifications.initialize(settings: initializationSettings);
    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    await initialize();

    if (Platform.isAndroid) {
      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      final notificationPermission =
          await android?.requestNotificationsPermission();

      if (notificationPermission == false) {
        return false;
      }

      final canScheduleExact =
          await android?.canScheduleExactNotifications() ?? false;

      if (!canScheduleExact) {
        // Wenn der Nutzer das nicht erlaubt, fällt die Planung später
        // automatisch auf eine ungenauere Android-Planung zurück.
        await android?.requestExactAlarmsPermission();
      }

      return true;
    }

    if (Platform.isIOS) {
      final granted = await _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: false, sound: true);

      return granted ?? false;
    }

    if (Platform.isMacOS) {
      final granted = await _notifications
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: false, sound: true);

      return granted ?? false;
    }

    return true;
  }

  Future<void> syncWeeklyReminders(List<WeeklyReminder> reminders) async {
    await initialize();

    final pending = await _notifications.pendingNotificationRequests();

    for (final notification in pending) {
      if (_isReminderNotificationId(notification.id)) {
        await _notifications.cancel(id: notification.id);
      }
    }

    for (final reminder in reminders) {
      await scheduleWeeklyReminder(reminder);
    }
  }

  Future<void> scheduleWeeklyReminder(WeeklyReminder reminder) async {
    await initialize();
    await _notifications.cancel(id: reminder.id);

    final androidScheduleMode = await _androidScheduleMode();
    final scheduledDate = _nextOccurrence(reminder);

    final channel = _androidChannelFor(reminder);

    await _notifications.zonedSchedule(
      id: reminder.id,
      title: reminder.name,
      scheduledDate: scheduledDate,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.high,
          priority: Priority.high,
          playSound: reminder.playSound,
          enableVibration: reminder.enableVibration,
        ),
        iOS: DarwinNotificationDetails(
          presentSound: reminder.playSound,
        ),
        macOS: DarwinNotificationDetails(
          presentSound: reminder.playSound,
        ),
      ),
      androidScheduleMode: androidScheduleMode,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: 'weekly_reminder:${reminder.id}',
    );
  }

  _ReminderAndroidChannel _androidChannelFor(WeeklyReminder reminder) {
    if (reminder.playSound && reminder.enableVibration) {
      return const _ReminderAndroidChannel(
        id: 'training_reminders_sound_vibration',
        name: 'Trainings-Reminder – Ton & Vibration',
        description:
            'Wöchentliche Trainings-Reminder mit Ton und Vibration',
      );
    }

    if (reminder.playSound) {
      return const _ReminderAndroidChannel(
        id: 'training_reminders_sound',
        name: 'Trainings-Reminder – Ton',
        description: 'Wöchentliche Trainings-Reminder nur mit Ton',
      );
    }

    if (reminder.enableVibration) {
      return const _ReminderAndroidChannel(
        id: 'training_reminders_vibration',
        name: 'Trainings-Reminder – Vibration',
        description: 'Wöchentliche Trainings-Reminder nur mit Vibration',
      );
    }

    return const _ReminderAndroidChannel(
      id: 'training_reminders_silent',
      name: 'Trainings-Reminder – Lautlos',
      description: 'Wöchentliche Trainings-Reminder ohne Ton und Vibration',
    );
  }

  Future<void> cancelWeeklyReminder(int reminderId) async {
    await initialize();
    await _notifications.cancel(id: reminderId);
  }

  Future<AndroidScheduleMode> _androidScheduleMode() async {
    if (!Platform.isAndroid) {
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }

    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    final canScheduleExact =
        await android?.canScheduleExactNotifications() ?? false;

    return canScheduleExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  tz.TZDateTime _nextOccurrence(WeeklyReminder reminder) {
    final now = tz.TZDateTime.now(tz.local);
    final daysUntilTarget = (reminder.weekday - now.weekday + 7) % 7;

    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day + daysUntilTarget,
      reminder.hour,
      reminder.minute,
    );

    if (!scheduled.isAfter(now)) {
      scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + daysUntilTarget + 7,
        reminder.hour,
        reminder.minute,
      );
    }

    return scheduled;
  }

  bool _isReminderNotificationId(int id) {
    return id >= _firstReminderNotificationId &&
        id <= _lastReminderNotificationId;
  }
}


class _ReminderAndroidChannel {
  final String id;
  final String name;
  final String description;

  const _ReminderAndroidChannel({
    required this.id,
    required this.name,
    required this.description,
  });
}
