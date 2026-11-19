
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../database/database_helper.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  static const String _channelId = 'focusflow_reminders';
  static const String _channelName = 'FocusFlow Reminders';

  static const String _taskPreferenceKey = 'task_notifications_enabled';
  static const String _habitPreferenceKey = 'habit_notifications_enabled';
  static const String _focusPreferenceKey = 'focus_notifications_enabled';

  static const int _habitNotificationOffset = 200000;

  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await _notifications.initialize(
      settings: settings,
    );
  }

  // --------------------------------------------------
  // NOTIFICATION PERMISSION
  // --------------------------------------------------

  Future<bool?> requestPermission() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
    _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    return await androidPlugin?.requestNotificationsPermission();
  }

  // --------------------------------------------------
  // NOTIFICATION SETTINGS
  // --------------------------------------------------

  Future<bool> areTaskNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_taskPreferenceKey) ?? true;
  }

  Future<bool> areHabitNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_habitPreferenceKey) ?? true;
  }

  Future<bool> areFocusNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_focusPreferenceKey) ?? true;
  }

  Future<void> setTaskNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_taskPreferenceKey, enabled);

    await _syncTaskNotifications(enabled);
  }

  Future<void> setHabitNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_habitPreferenceKey, enabled);

    await _syncHabitNotifications(enabled);
  }

  Future<void> setFocusNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_focusPreferenceKey, enabled);
  }

  // --------------------------------------------------
  // RESTORE / CANCEL TASK NOTIFICATIONS
  // --------------------------------------------------

  Future<void> _syncTaskNotifications(bool enabled) async {
    final tasks = await DatabaseHelper.instance.getTasks();

    for (final task in tasks) {
      if (task.id == null) continue;

      if (!enabled ||
          task.completed ||
          task.reminderDateTime == null ||
          !task.reminderDateTime!.isAfter(DateTime.now())) {
        await cancelNotification(task.id!);
        continue;
      }

      await scheduleNotification(
        id: task.id!,
        title: 'Task Reminder: ${task.title}',
        body: task.description.isNotEmpty
            ? task.description
            : 'It is time to complete your task.',
        scheduledDate: task.reminderDateTime!,
      );
    }
  }

  // --------------------------------------------------
  // RESTORE / CANCEL HABIT NOTIFICATIONS
  // --------------------------------------------------

  Future<void> _syncHabitNotifications(bool enabled) async {
    final habits = await DatabaseHelper.instance.getHabits(
      activeOnly: enabled,
    );

    for (final habit in habits) {
      if (habit.id == null) continue;

      final notificationId = habit.id! + _habitNotificationOffset;

      if (!enabled ||
          habit.reminderTime == null ||
          habit.reminderTime!.isEmpty) {
        await cancelNotification(notificationId);
        continue;
      }

      final parts = habit.reminderTime!.split(':');

      if (parts.length != 2) {
        await cancelNotification(notificationId);
        continue;
      }

      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);

      if (hour == null ||
          minute == null ||
          hour < 0 ||
          hour > 23 ||
          minute < 0 ||
          minute > 59) {
        await cancelNotification(notificationId);
        continue;
      }

      await scheduleDailyNotification(
        id: notificationId,
        title: 'FocusFlow Habit Reminder',
        body: 'Time to work on your habit: ${habit.name}',
        hour: hour,
        minute: minute,
      );
    }
  }

  // --------------------------------------------------
  // SHOW INSTANT NOTIFICATION
  // --------------------------------------------------

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Task, habit and focus reminders',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _notifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  // Focus completion notification respects its own setting.
  Future<void> showFocusNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!await areFocusNotificationsEnabled()) return;

    await showNotification(
      id: id,
      title: title,
      body: body,
    );
  }

  // --------------------------------------------------
  // ONE-TIME TASK NOTIFICATION
  // --------------------------------------------------

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (!await areTaskNotificationsEnabled()) {
      await cancelNotification(id);
      return;
    }

    if (!scheduledDate.isAfter(DateTime.now())) {
      throw ArgumentError('Scheduled time must be in the future.');
    }

    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Task, habit and focus reminders',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _notifications.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(
        scheduledDate,
        tz.local,
      ),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  // --------------------------------------------------
  // DAILY HABIT NOTIFICATION
  // --------------------------------------------------

  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    if (!await areHabitNotificationsEnabled()) {
      await cancelNotification(id);
      return;
    }

    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw ArgumentError('Invalid reminder time.');
    }

    final now = tz.TZDateTime.now(tz.local);

    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (!scheduledDate.isAfter(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Task, habit and focus reminders',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _notifications.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // --------------------------------------------------
  // CANCEL NOTIFICATIONS
  // --------------------------------------------------

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id: id);
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}
