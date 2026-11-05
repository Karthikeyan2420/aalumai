import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../preferences/app_preferences.dart';
import '../providers/providers.dart';
import '../../features/habits/data/habit_repository.dart';
import '../../features/schedule/data/event_repository.dart';
import '../../features/tasks/data/task_repository.dart';
import 'notification_service.dart';
import 'reminder_scheduler.dart';

/// Applies the settings "Reminders" master switch: cancel OS schedules when off,
/// re-arm from the database when on.
Future<void> applyNotificationsEnabled(WidgetRef ref, bool enabled) async {
  await ref.read(appPreferencesProvider).setNotificationsEnabled(enabled);
  final scheduler = ref.read(reminderSchedulerProvider);
  final db = ref.read(appDatabaseProvider);
  if (!enabled) {
    await scheduler.cancelAll(db);
    return;
  }
  await ref.read(notificationServiceProvider).requestPermissions();
  await ref.read(taskRepositoryProvider).reconcileReminders();
  await ref.read(habitRepositoryProvider).reconcileReminders();
  await ref.read(eventRepositoryProvider).reconcileReminders();
}

Future<void> applyNotificationsEnabledFromContainer(
  ProviderContainer container,
  bool enabled,
) async {
  await container.read(appPreferencesProvider).setNotificationsEnabled(enabled);
  final scheduler = container.read(reminderSchedulerProvider);
  final db = container.read(appDatabaseProvider);
  if (!enabled) {
    await scheduler.cancelAll(db);
    return;
  }
  await container.read(notificationServiceProvider).requestPermissions();
  await container.read(taskRepositoryProvider).reconcileReminders();
  await container.read(habitRepositoryProvider).reconcileReminders();
  await container.read(eventRepositoryProvider).reconcileReminders();
}
