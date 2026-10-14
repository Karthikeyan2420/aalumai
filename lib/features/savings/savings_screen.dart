import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/common.dart';
import 'data/savings_repository.dart';

class SavingsScreen extends ConsumerWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final goals = ref.watch(savingsGoalsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.savingsGoals)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showSavingsGoalEditor(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.add),
      ),
      body: goals.when(
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
            itemBuilder:
                (context, i) => _GoalCard(
                  goal: list[i],
                  onTap: () => _openGoal(context, ref, list[i]),
                ),
          );
        },
      ),
    );
  }

  Future<void> _openGoal(
    BuildContext context,
    WidgetRef ref,
    SavingsGoal goal,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SavingsGoalDetailScreen(goal: goal)),
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
        final ratio =
            goal.targetPaise <= 0
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
                    '${formatMoney(saved, locale)} / '
                    '${formatMoney(goal.targetPaise, locale)}',
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
  const SavingsGoalDetailScreen({super.key, required this.goal});
  final SavingsGoal goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final contributions = ref.watch(_contributionsProvider(goal.id));
    return Scaffold(
      appBar: AppBar(title: Text(goal.name)),
      floatingActionButton: FloatingActionButton.extended(
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
                        formatMoney(goal.targetPaise, locale),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${l10n.progress}: '
                        '${formatMoney(snapshot.data ?? 0, locale)}',
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
                                    trailing: Text(
                                      formatMoney(c.amountPaise, locale),
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
  }
}

final _contributionsProvider =
    StreamProvider.family<List<SavingsContribution>, int>((ref, goalId) {
      return ref.watch(savingsRepositoryProvider).watchContributions(goalId);
    });

Future<void> showSavingsGoalEditor(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final nameCtrl = TextEditingController();
  final targetCtrl = TextEditingController();
  final saved = await showDialog<bool>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: Text(l10n.savingsGoal),
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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
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
    await ref
        .read(savingsRepositoryProvider)
        .createGoal(
          name: nameCtrl.text.trim(),
          targetPaise: Money.rupeesToPaise(target),
        );
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
    builder:
        (context) => StatefulBuilder(
          builder:
              (context, setState) => AlertDialog(
                title: Text(l10n.addContribution),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: amountCtrl,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
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
    await ref
        .read(savingsRepositoryProvider)
        .addContribution(
          goalId: goal.id,
          amountPaise: Money.rupeesToPaise(amount),
          date: DateTime.now(),
          isWithdrawal: isWithdrawal,
        );
  }
}

String formatMoney(int paise, String localeCode) =>
    Money.formatCompact(paise, locale: localeCode);
