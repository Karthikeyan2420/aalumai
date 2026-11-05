import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/common.dart';
import '../savings/data/savings_repository.dart';
import 'item_actions.dart';

class SavingsGoalsTab extends ConsumerWidget {
  const SavingsGoalsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final goals = ref.watch(savingsGoalsProvider);
    return goals.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(message: e.toString()),
      data: (list) {
        if (list.isEmpty) {
          return EmptyState(
            icon: Icons.savings_outlined,
            message: l10n.emptySavings,
            actionLabel: l10n.add,
            onAction: () => showSavingsGoalEditor(context, ref),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _GoalCard(
            goal: list[i],
            onTap: () => _openGoal(context, ref, list[i]),
          ),
        );
      },
    );
  }

  Future<void> _openGoal(
    BuildContext context,
    WidgetRef ref,
    SavingsGoal goal,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SavingsGoalDetailScreen(goalId: goal.id),
      ),
    );
  }
}

class _GoalCard extends ConsumerWidget {
  const _GoalCard({required this.goal, required this.onTap});
  final SavingsGoal goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context).toString();
    return FutureBuilder<int>(
      future: ref.read(savingsRepositoryProvider).savedFor(goal.id),
      builder: (context, snapshot) {
        final saved = snapshot.data ?? 0;
        final ratio = goal.targetPaise <= 0
            ? 0.0
            : (saved / goal.targetPaise).clamp(0.0, 1.0);
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          goal.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (goal.isCompleted)
                        const Icon(Icons.check_circle, color: Colors.green),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: ratio.toDouble()),
                  const SizedBox(height: 8),
                  Text(
                    '${Money.formatCompact(saved, locale: locale)} / '
                    '${Money.formatCompact(goal.targetPaise, locale: locale)}',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class SavingsGoalDetailScreen extends ConsumerWidget {
  const SavingsGoalDetailScreen({super.key, required this.goalId});
  final int goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final goalAsync = ref.watch(_goalProvider(goalId));
    return goalAsync.when(
      loading: () => Scaffold(appBar: AppBar(), body: const LoadingState()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorState(message: e.toString()),
      ),
      data: (goal) {
        if (goal == null) {
          return Scaffold(
            appBar: AppBar(),
            body: EmptyState(icon: Icons.savings_outlined, message: l10n.emptySavings),
          );
        }
        final contributions = ref.watch(_contributionsProvider(goal.id));
        return Scaffold(
          appBar: AppBar(
            title: Text(goal.name),
            actions: [
              itemMoreButton(
                onPressed:
                    () => showEditDeleteMenu(
                      context,
                      onEdit:
                          () => showSavingsGoalEditor(context, ref, goal: goal),
                      onDelete: () async {
                        final ok = await confirmDialog(
                          context,
                          title: l10n.deleteConfirmTitle,
                          body: l10n.deleteConfirmBody,
                          confirmLabel: l10n.delete,
                        );
                        if (ok) {
                          await ref
                              .read(savingsRepositoryProvider)
                              .deleteGoal(goal.id);
                          if (context.mounted) Navigator.pop(context);
                        }
                      },
                    ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'savingsDetailAdd',
            onPressed: () => showContributionEditor(context, ref, goal),
            icon: const Icon(Icons.add),
            label: Text(l10n.addContribution),
          ),
          body: FutureBuilder<int>(
            future: ref.read(savingsRepositoryProvider).savedFor(goal.id),
            builder: (context, snapshot) {
              return Column(
                children: [
                  Card(
                    margin: const EdgeInsets.all(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.targetAmount),
                          Text(
                            Money.formatCompact(goal.targetPaise, locale: locale),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${l10n.progress}: '
                            '${Money.formatCompact(snapshot.data ?? 0, locale: locale)}',
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: contributions.when(
                      loading: () => const LoadingState(),
                      error: (e, _) => ErrorState(message: e.toString()),
                      data:
                          (list) =>
                              list.isEmpty
                                  ? EmptyState(
                                    icon: Icons.savings_outlined,
                                    message: l10n.emptySavings,
                                    actionLabel: l10n.addContribution,
                                    onAction:
                                        () => showContributionEditor(
                                          context,
                                          ref,
                                          goal,
                                        ),
                                  )
                                  : ListView.builder(
                                    itemCount: list.length,
                                    itemBuilder: (context, i) {
                                      final c = list[i];
                                      return ListTile(
                                        leading: Icon(
                                          c.isWithdrawal
                                              ? Icons.arrow_upward
                                              : Icons.arrow_downward,
                                          color:
                                              c.isWithdrawal
                                                  ? Theme.of(
                                                    context,
                                                  ).colorScheme.error
                                                  : Colors.green,
                                        ),
                                        title: Text(
                                          c.note.isEmpty
                                              ? (c.isWithdrawal
                                                  ? l10n.withdraw
                                                  : l10n.contribution)
                                              : c.note,
                                        ),
                                        subtitle: Text(
                                          DateFormat.yMMMd(locale).format(c.date),
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              Money.formatCompact(
                                                c.amountPaise,
                                                locale: locale,
                                              ),
                                            ),
                                            itemMoreButton(
                                              onPressed: () async {
                                                final ok = await confirmDialog(
                                                  context,
                                                  title: l10n.deleteConfirmTitle,
                                                  body: l10n.deleteConfirmBody,
                                                  confirmLabel: l10n.delete,
                                                );
                                                if (ok) {
                                                  await ref
                                                      .read(
                                                        savingsRepositoryProvider,
                                                      )
                                                      .deleteContribution(c.id);
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

final _contributionsProvider =
    StreamProvider.family<List<SavingsContribution>, int>((ref, goalId) {
      return ref.watch(savingsRepositoryProvider).watchContributions(goalId);
    });

final _goalProvider = StreamProvider.family<SavingsGoal?, int>((ref, goalId) {
  return ref.watch(savingsRepositoryProvider).watchGoal(goalId);
});

Future<void> showSavingsGoalEditor(
  BuildContext context,
  WidgetRef ref, {
  SavingsGoal? goal,
}) async {
  final l10n = context.l10n;
  final nameCtrl = TextEditingController(text: goal?.name ?? '');
  final targetCtrl = TextEditingController(
    text:
        goal == null
            ? ''
            : Money.paiseToRupees(goal.targetPaise).toString(),
  );
  final saved = await showDialog<bool>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: Text(goal == null ? l10n.savingsGoal : l10n.edit),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameCtrl,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.name),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: targetCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l10n.targetAmount),
          ),
        ],
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
  final target = double.tryParse(targetCtrl.text.trim());
  if (saved == true &&
      target != null &&
      target > 0 &&
      nameCtrl.text.trim().isNotEmpty) {
    final repo = ref.read(savingsRepositoryProvider);
    if (goal == null) {
      await repo.createGoal(
        name: nameCtrl.text.trim(),
        targetPaise: Money.rupeesToPaise(target),
      );
    } else {
      await repo.updateGoal(
        goal.copyWith(
          name: nameCtrl.text.trim(),
          targetPaise: Money.rupeesToPaise(target),
        ),
      );
    }
  }
}

Future<void> showContributionEditor(
  BuildContext context,
  WidgetRef ref,
  SavingsGoal goal,
) async {
  final l10n = context.l10n;
  final amountCtrl = TextEditingController();
  var isWithdrawal = false;
  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(l10n.addContribution),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.amount),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.withdraw),
              value: isWithdrawal,
              onChanged: (v) => setState(() => isWithdrawal = v),
            ),
          ],
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
    ),
  );
  final amount = double.tryParse(amountCtrl.text.trim());
  if (saved == true && amount != null && amount > 0) {
    await ref.read(savingsRepositoryProvider).addContribution(
          goalId: goal.id,
          amountPaise: Money.rupeesToPaise(amount),
          date: DateTime.now(),
          isWithdrawal: isWithdrawal,
        );
  }
}
