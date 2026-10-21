import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/localization/generated/app_localizations.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/widgets/common.dart';
import 'data/yoga_repository.dart';
import 'domain/yoga.dart';

/// The user's yoga practice history, newest first. Each entry can be expanded
/// to show the poses performed and how each one ended.
class YogaHistoryScreen extends ConsumerWidget {
  const YogaHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sessions = ref.watch(yogaSessionsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.yogaHistory)),
      body: sessions.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.yogaNoHistory,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: list.length,
            itemBuilder: (context, index) => _SessionTile(session: list[index]),
          );
        },
      ),
    );
  }
}

class _SessionTile extends ConsumerWidget {
  const _SessionTile({required this.session});

  final YogaSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final date = DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).add_Hm().format(session.startedAt);
    final minutes = session.durationSec ~/ 60;
    final outline = _outcomeLabel(l10n, session.outcome);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: const Icon(Icons.self_improvement),
        title: Text(session.title.isEmpty ? l10n.yoga : session.title),
        subtitle: Text(
          '$date\n'
          '${l10n.yogaMinutes(minutes)} · '
          '${session.completedPoses}/${session.poseCount} · $outline',
        ),
        isThreeLine: true,
        trailing: IconButton(
          tooltip: l10n.delete,
          icon: const Icon(Icons.delete_outline),
          onPressed:
              () => ref.read(yogaRepositoryProvider).deleteSession(session.id),
        ),
        onTap: () => _showPoses(context, ref, l10n),
      ),
    );
  }

  void _showPoses(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder:
          (context) => SafeArea(
            child: ref
                .watch(yogaPoseLogsProvider(session.id))
                .when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(e.toString()),
                  ),
                  data: (logs) {
                    if (logs.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(l10n.yogaNoHistory),
                      );
                    }
                    return ListView(
                      shrinkWrap: true,
                      children: [
                        for (final log in logs)
                          ListTile(
                            dense: true,
                            leading: Icon(
                              log.outcome == YogaPoseOutcome.completed.index
                                  ? Icons.check_circle_outline
                                  : Icons.skip_next,
                              color: theme.colorScheme.secondary,
                            ),
                            title: Text(
                              log.englishName.isEmpty
                                  ? log.poseKey
                                  : log.englishName,
                            ),
                            trailing: Text('${log.actualSec}s'),
                          ),
                      ],
                    );
                  },
                ),
          ),
    );
  }

  String _outcomeLabel(AppLocalizations l10n, int outcome) {
    if (outcome == YogaSessionOutcome.completed.index) {
      return l10n.statusCompleted;
    }
    if (outcome == YogaSessionOutcome.partial.index) {
      return l10n.sessionOutcomePartial;
    }
    return l10n.sessionOutcomeCancelled;
  }
}
