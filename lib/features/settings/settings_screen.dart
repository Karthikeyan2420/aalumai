import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/backgrounds/background_presets.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/providers/providers.dart';
import '../../core/router/app_router.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/restore_reconciler.dart';
import 'alarm_voice_settings_screen.dart';
import 'background_settings_screen.dart';
import 'data/lock_service.dart';

const _languages = <(String, String)>[
  ('en', 'English'),
  ('ta', 'தமிழ்'),
  ('te', 'తెలుగు'),
  ('ml', 'മലയാളം'),
  ('kn', 'ಕನ್ನಡ'),
];

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final prefs = ref.watch(appPreferencesProvider);
    final locale = ref.watch(localeCodeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          _SectionHeader(l10n.settingsGeneral),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.language),
            subtitle: Text(
              _languages
                  .firstWhere(
                    (l) => l.$1 == (locale ?? 'en'),
                    orElse: () => ('en', 'English'),
                  )
                  .$2,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickLanguage(context, ref, locale),
          ),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: Text(l10n.theme),
            subtitle: Text(_themeLabel(context, themeMode)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickTheme(context, ref, themeMode),
          ),
          ListTile(
            leading: const Icon(Icons.wallpaper_outlined),
            title: const Text('Home background'),
            subtitle: const Text('Relaxing image, colour or gradient'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openBackground(context, BackgroundSlot.home),
          ),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text('Alarm background'),
            subtitle: const Text('Night-sky image, colour or gradient'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openBackground(context, BackgroundSlot.alarm),
          ),
          ListTile(
            leading: const Icon(Icons.record_voice_over_outlined),
            title: Text(l10n.settingsAlarmVoice),
            subtitle: Text(l10n.settingsAlarmVoiceDesc),
            trailing: const Icon(Icons.chevron_right),
            onTap:
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AlarmVoiceSettingsScreen(),
                  ),
                ),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsFitness),
          ListTile(
            leading: const Icon(Icons.water_drop_outlined),
            title: Text(l10n.waterIntake),
            subtitle: Text('${prefs.dailyWaterGoalMl} ml'),
            onTap:
                () => _editNumber(
                  context,
                  l10n.waterIntake,
                  prefs.dailyWaterGoalMl,
                  (v) =>
                      ref.read(appPreferencesProvider).setDailyWaterGoalMl(v),
                ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.music_note_outlined),
            title: Text(l10n.settingsAudio),
            subtitle: const Text('Play music during workouts'),
            value: prefs.workoutMusicEnabled,
            onChanged:
                (v) =>
                    ref.read(appPreferencesProvider).setWorkoutMusicEnabled(v),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsNotifications),
          Consumer(
            builder: (context, ref, _) {
              return SwitchListTile(
                secondary: const Icon(Icons.notifications_outlined),
                title: Text(l10n.reminder),
                value: prefs.notificationsEnabled,
                onChanged: (v) async {
                  await ref
                      .read(appPreferencesProvider)
                      .setNotificationsEnabled(v);
                  if (v) {
                    await ref
                        .read(notificationServiceProvider)
                        .requestPermissions();
                  }
                },
              );
            },
          ),
          const Divider(),
          _SectionHeader(l10n.settingsData),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: Text(l10n.backupNow),
            subtitle:
                prefs.lastBackupAt == null
                    ? Text(l10n.backupDescription)
                    : Text(
                      DateFormat.yMMMd().add_Hm().format(prefs.lastBackupAt!),
                    ),
            onTap: () => _backup(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: Text(l10n.exportCsv),
            subtitle: Text(l10n.exportCsvDescription),
            onTap: () => _exportCsv(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.restore_outlined),
            title: Text(l10n.restoreBackup),
            onTap: () => _restore(context, ref),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsPrivacy),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(l10n.noteLock),
            onTap: () => _managePin(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.policy_outlined),
            title: Text(l10n.aboutPrivacy),
            onTap: () => context.push(AppRoutes.about),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.about),
            onTap: () => context.push(AppRoutes.about),
          ),
        ],
      ),
    );
  }

  String _themeLabel(BuildContext context, AppThemeMode mode) {
    final l10n = context.l10n;
    return switch (mode) {
      AppThemeMode.system => l10n.themeSystem,
      AppThemeMode.light => l10n.themeLight,
      AppThemeMode.dark => l10n.themeDark,
    };
  }

  Future<void> _pickLanguage(
    BuildContext context,
    WidgetRef ref,
    String? current,
  ) async {
    final code = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final lang in _languages)
                  ListTile(
                    title: Text(lang.$2),
                    trailing:
                        (current ?? 'en') == lang.$1
                            ? const Icon(Icons.check)
                            : null,
                    onTap: () => Navigator.pop(context, lang.$1),
                  ),
              ],
            ),
          ),
    );
    if (code != null) {
      await ref.read(localeCodeProvider.notifier).setLocale(code);
    }
  }

  Future<void> _pickTheme(
    BuildContext context,
    WidgetRef ref,
    AppThemeMode current,
  ) async {
    final l10n = context.l10n;
    final mode = await showModalBottomSheet<AppThemeMode>(
      context: context,
      showDragHandle: true,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final m in AppThemeMode.values)
                  ListTile(
                    title: Text(switch (m) {
                      AppThemeMode.system => l10n.themeSystem,
                      AppThemeMode.light => l10n.themeLight,
                      AppThemeMode.dark => l10n.themeDark,
                    }),
                    trailing: current == m ? const Icon(Icons.check) : null,
                    onTap: () => Navigator.pop(context, m),
                  ),
              ],
            ),
          ),
    );
    if (mode != null) {
      await ref.read(themeModeProvider.notifier).setMode(mode);
    }
  }

  void _openBackground(BuildContext context, BackgroundSlot slot) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BackgroundSettingsScreen(slot: slot),
      ),
    );
  }

  Future<void> _editNumber(
    BuildContext context,
    String title,
    int current,
    Future<void> Function(int) onSave,
  ) async {
    final ctrl = TextEditingController(text: '$current');
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.save),
              ),
            ],
          ),
    );
    final value = int.tryParse(ctrl.text.trim());
    if (ok == true && value != null && value > 0) {
      await onSave(value);
    }
  }

  Future<void> _backup(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    try {
      final result = await ref.read(backupServiceProvider).exportBackup();
      await ref.read(appPreferencesProvider).setLastBackupAt(DateTime.now());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.backupSuccess} · ${result.file.path}'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.backupFailed)));
      }
    }
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    try {
      final csv = await ref.read(backupServiceProvider).transactionsCsv();
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/aalumai_transactions.csv');
      await file.writeAsString(csv);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.exportCsv} · ${file.path}')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.backupFailed)));
      }
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: false,
    );
    final path = result?.files.single.path;
    if (path == null) return;
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.restoreBackup),
            content: Text(l10n.restoreWarning),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.restoreBackup),
              ),
            ],
          ),
    );
    if (ok != true) return;

    // Snapshot the schedules owned by the *current* database before it is
    // replaced, so schedules for records that the backup does not contain can
    // be cancelled instead of ringing forever.
    final ScheduleSnapshot before;
    try {
      before = await ref.read(restoreReconcilerProvider).snapshot();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.restoreFailed)));
      }
      return;
    }

    try {
      await ref.read(backupServiceProvider).restore(File(path));
    } catch (_) {
      // The database file itself could not be replaced: report failure and do
      // not touch the existing schedules.
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.restoreFailed)));
      }
      return;
    }

    // Rebuild every data provider against the restored file, then reconcile the
    // OS schedule set so it matches the restored records.
    ref.invalidate(appDatabaseProvider);
    final outcome = await _reconcileAfterRestore(ref, before);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          outcome.isComplete ? l10n.restoreSuccess : l10n.restorePartial,
        ),
      ),
    );
  }

  /// Best-effort reconciliation that never lets a scheduling failure surface as
  /// a crash. The database has already been restored; a failed re-arm is
  /// reported (not hidden) and the restored data is left intact.
  Future<RestoreOutcome> _reconcileAfterRestore(
    WidgetRef ref,
    ScheduleSnapshot before,
  ) async {
    try {
      return await ref.read(restoreReconcilerProvider).reconcile(before);
    } catch (e) {
      return RestoreOutcome(
        obsoleteCancelled: false,
        alarmsReconciled: false,
        remindersReconciled: false,
        errors: [e.toString()],
      );
    }
  }

  Future<void> _managePin(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final lock = ref.read(lockServiceProvider);
    final hasPin = await lock.hasPin;
    if (!context.mounted) return;
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(hasPin ? l10n.noteLock : l10n.noteLock),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.required),
            ),
            actions: [
              if (hasPin)
                TextButton(
                  onPressed: () async {
                    await lock.clearPin();
                    if (context.mounted) Navigator.pop(context, false);
                  },
                  child: Text(l10n.delete),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.save),
              ),
            ],
          ),
    );
    if (ok == true && ctrl.text.trim().length >= 4) {
      await lock.setPin(ctrl.text.trim());
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.secondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
