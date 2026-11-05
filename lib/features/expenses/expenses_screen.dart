import 'package:collection/collection.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/utils/money.dart';
import '../../core/utils/recurrence.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/module_theme.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dashboard_components.dart';
import '../../core/widgets/module_scaffold.dart';
import 'data/finance_repository.dart';
import 'category_picker.dart';
import 'item_actions.dart';
import 'savings_goals_ui.dart';
import 'transaction_list_helpers.dart';
import 'transaction_editor.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final balance = ref.watch(totalBalanceProvider);
    final locale = Localizations.localeOf(context).toString();
    final onGoalsTab = _tabs.index == 3;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.expenses),
        backgroundColor: softTint(context, ModuleAccents.expenses, 0.08),
        actions: [
          IconButton(
            tooltip: l10n.recurring,
            icon: const Icon(Icons.event_repeat),
            onPressed: () => showRecurringManager(context, ref),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l10n.expense),
            Tab(text: l10n.budgets),
            Tab(text: l10n.debts),
            Tab(text: l10n.savingsGoals),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: onGoalsTab ? 'expensesGoalsAdd' : 'expensesAdd',
        onPressed: () => onGoalsTab
            ? showSavingsGoalEditor(context, ref)
            : showTransactionEditor(context, ref),
        icon: const Icon(Icons.add),
        label: Text(onGoalsTab ? l10n.newGoal : l10n.addTransaction),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              12,
              AppSpacing.screen,
              4,
            ),
            child: AppCard(
              onTap: () => showAccountsManager(context, ref),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  moduleIconWell(
                    context,
                    icon: Icons.account_balance_wallet,
                    accent: ModuleAccents.expenses,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      l10n.totalBalance,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    balance.valueOrNull == null
                        ? '—'
                        : formatMoney(balance.valueOrNull!, locale),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [
                _TransactionsTab(),
                _BudgetsTab(),
                _DebtsTab(),
                SavingsGoalsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionsTab extends ConsumerStatefulWidget {
  const _TransactionsTab();

  @override
  ConsumerState<_TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends ConsumerState<_TransactionsTab> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _month = DateTime(picked.year, picked.month));
    }
  }

  Future<void> _deleteWithUndo(Transaction t) async {
    final l10n = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l10n.deleteConfirmTitle,
      body: l10n.deleteConfirmBody,
      confirmLabel: l10n.delete,
    );
    if (!ok || !mounted) return;
    final repo = ref.read(financeRepositoryProvider);
    await repo.deleteTransaction(t.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.undoDelete),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () async {
            await repo.addTransaction(
              accountId: t.accountId,
              type: TransactionType.fromIndex(t.type),
              amountPaise: t.amountPaise,
              date: t.date,
              categoryId: t.categoryId,
              note: t.note,
              transferAccountId: t.transferAccountId,
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final txns = ref.watch(transactionsProvider);
    final accounts = ref.watch(accountsProvider).valueOrNull ?? const [];
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final accountNames = {for (final a in accounts) a.id: a.name};
    final categoryNames = {for (final c in categories) c.id: c.name};

    final spending = ref.watch(spendingByCategoryProvider);
    final slices = [
      for (final s in spending)
        ChartSlice(label: s.label, value: s.amountPaise / 100),
    ];
    final showChart = slices.isNotEmpty;

    return txns.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(message: e.toString()),
      data: (list) {
        final now = DateTime.now();
        final due =
            (ref.watch(recurringRulesProvider).valueOrNull ?? const [])
                .where((r) => r.isActive && !r.nextDate.isAfter(now))
                .toList();
        var monthList = filterTransactionsForMonth(list, _month);
        monthList = searchTransactions(monthList, _query);
        final grouped = groupTransactionsByDay(monthList);
        final dayKeys = grouped.keys.toList();

        if (list.isEmpty && due.isEmpty) {
          return EmptyState(
            icon: Icons.receipt_long_outlined,
            message: l10n.emptyExpenses,
            actionLabel: l10n.addTransaction,
            onAction: () => showTransactionEditor(context, ref),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: l10n.search,
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _pickMonth,
                    icon: const Icon(Icons.calendar_month),
                    label: Text(DateFormat.yMMM(locale).format(_month)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: monthList.isEmpty && due.isEmpty
                  ? EmptyState(
                      icon: Icons.receipt_long_outlined,
                      message: l10n.emptyExpenses,
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 96),
                      children: [
                        if (due.isNotEmpty) _DueRecurringCard(rules: due),
                        if (showChart)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                            child: SectionCard(
                              title: l10n.spendingByCategory,
                              icon: Icons.pie_chart_outline,
                              child: SimpleBarChart(slices: slices),
                            ),
                          ),
                        for (final day in dayKeys) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                            child: Text(
                              daySectionLabel(context, day),
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          for (final t in grouped[day]!)
                            _transactionTile(
                              context,
                              ref,
                              t,
                              locale,
                              categoryNames,
                              accountNames,
                            ),
                        ],
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _transactionTile(
    BuildContext context,
    WidgetRef ref,
    Transaction t,
    String locale,
    Map<int, String> categoryNames,
    Map<int, String> accountNames,
  ) {
    final type = TransactionType.fromIndex(t.type);
    final sign = switch (type) {
      TransactionType.income => '+',
      TransactionType.expense => '−',
      TransactionType.transfer => '↔',
    };
    final color = switch (type) {
      TransactionType.income => Colors.green,
      TransactionType.expense => Theme.of(context).colorScheme.error,
      TransactionType.transfer => Theme.of(context).colorScheme.primary,
    };
    final subtitle = [
      accountNames[t.accountId] ?? '',
      if (t.categoryId != null) categoryNames[t.categoryId] ?? '',
      DateFormat.jm(locale).format(t.date),
    ].where((s) => s.isNotEmpty).join(' · ');
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Text(sign, style: TextStyle(color: color)),
      ),
      title: Text(t.note.isEmpty ? type.name : t.note),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatMoney(t.amountPaise, locale),
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
          itemMoreButton(
            onPressed:
                () => showEditDeleteMenu(
                  context,
                  onEdit:
                      () => showTransactionEditor(
                        context,
                        ref,
                        transaction: t,
                      ),
                  onDelete: () => _deleteWithUndo(t),
                ),
          ),
        ],
      ),
      onTap: () => showTransactionEditor(context, ref, transaction: t),
      onLongPress: () => _deleteWithUndo(t),
    );
  }
}

class _BudgetsTab extends ConsumerWidget {
  const _BudgetsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final budgets = ref.watch(budgetsProvider);
    return budgets.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(message: e.toString()),
      data: (list) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: () => showBudgetEditor(context, ref),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.add),
                ),
              ),
            ),
            Expanded(
              child:
                  list.isEmpty
                      ? EmptyState(
                        icon: Icons.savings_outlined,
                        message: l10n.emptyExpenses,
                        actionLabel: l10n.add,
                        onAction: () => showBudgetEditor(context, ref),
                      )
                      : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          for (final b in list)
                            _BudgetTile(
                              budget: b,
                              locale: locale,
                              onEdit:
                                  () => showBudgetEditor(context, ref, budget: b),
                              onDelete: () async {
                                final ok = await confirmDialog(
                                  context,
                                  title: l10n.deleteConfirmTitle,
                                  body: l10n.deleteConfirmBody,
                                  confirmLabel: l10n.delete,
                                );
                                if (ok) {
                                  await ref
                                      .read(financeRepositoryProvider)
                                      .deleteBudget(b.id);
                                }
                              },
                            ),
                        ],
                      ),
            ),
          ],
        );
      },
    );
  }
}

class _BudgetTile extends ConsumerWidget {
  const _BudgetTile({
    required this.budget,
    required this.locale,
    required this.onEdit,
    required this.onDelete,
  });
  final Budget budget;
  final String locale;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final categoryLabel =
        budget.categoryId == null
            ? l10n.all
            : (categories
                    .where((c) => c.id == budget.categoryId)
                    .firstOrNull
                    ?.name ??
                l10n.category);
    return FutureBuilder<int>(
      future: ref
          .read(financeRepositoryProvider)
          .budgetSpent(budget, DateTime.now()),
      builder: (context, snapshot) {
        final spent = snapshot.data ?? 0;
        final ratio =
            budget.amountPaise <= 0
                ? 0.0
                : (spent / budget.amountPaise).clamp(0.0, 1.0);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        categoryLabel,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${formatMoney(spent, locale)} / '
                      '${formatMoney(budget.amountPaise, locale)}',
                    ),
                    itemMoreButton(
                      onPressed:
                          () => showEditDeleteMenu(
                            context,
                            onEdit: onEdit,
                            onDelete: onDelete,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: ratio.toDouble()),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DebtsTab extends ConsumerWidget {
  const _DebtsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final debts = ref.watch(debtsProvider);
    return debts.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(message: e.toString()),
      data:
          (list) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    onPressed: () => showDebtEditor(context, ref),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.add),
                  ),
                ),
              ),
              Expanded(
                child:
                    list.isEmpty
                        ? EmptyState(
                          icon: Icons.account_balance_outlined,
                          message: l10n.emptyExpenses,
                          actionLabel: l10n.add,
                          onAction: () => showDebtEditor(context, ref),
                        )
                        : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          children: [
                            for (final d in list)
                              _DebtTile(
                                debt: d,
                                locale: locale,
                                onEdit:
                                    () => showDebtEditor(context, ref, debt: d),
                                onDelete: () async {
                                  final ok = await confirmDialog(
                                    context,
                                    title: l10n.deleteConfirmTitle,
                                    body: l10n.deleteConfirmBody,
                                    confirmLabel: l10n.delete,
                                  );
                                  if (ok) {
                                    await ref
                                        .read(financeRepositoryProvider)
                                        .deleteDebt(d.id);
                                  }
                                },
                              ),
                          ],
                        ),
              ),
            ],
          ),
    );
  }
}

class _DebtTile extends ConsumerWidget {
  const _DebtTile({
    required this.debt,
    required this.locale,
    required this.onEdit,
    required this.onDelete,
  });
  final Debt debt;
  final String locale;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return FutureBuilder<int>(
      future: ref.read(financeRepositoryProvider).debtPaidPrincipal(debt.id),
      builder: (context, snapshot) {
        final paid = snapshot.data ?? 0;
        final outstanding = (debt.principalPaise - paid).clamp(
          0,
          debt.principalPaise,
        );
        return Card(
          child: ListTile(
            title: Text(debt.name),
            subtitle: Text(
              '${l10n.outstanding}: '
              '${formatMoney(outstanding, locale)}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.payments_outlined),
                  tooltip: l10n.payment,
                  onPressed: () => showPaymentEditor(context, ref, debt),
                ),
                itemMoreButton(
                  onPressed:
                      () => showEditDeleteMenu(
                        context,
                        onEdit: onEdit,
                        onDelete: onDelete,
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---- Editors ---------------------------------------------------------------

Future<void> showAccountsManager(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final locale = Localizations.localeOf(context).toString();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder:
        (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          builder:
              (context, controller) => ref
                  .watch(accountsProvider)
                  .when(
                    loading: () => const LoadingState(),
                    error: (e, _) => ErrorState(message: e.toString()),
                    data:
                        (accounts) => ListView(
                          controller: controller,
                          padding: const EdgeInsets.all(16),
                          children: [
                            Text(
                              l10n.account,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            for (final a in accounts)
                              ListTile(
                                leading: const Icon(
                                  Icons.account_balance_wallet_outlined,
                                ),
                                title: Text(a.name),
                                subtitle: Text(
                                  AccountType.fromIndex(a.type).name,
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      formatMoney(a.openingBalancePaise, locale),
                                    ),
                                    itemMoreButton(
                                      onPressed:
                                          () => showEditDeleteMenu(
                                            context,
                                            onEdit:
                                                () => showAccountEditor(
                                                  context,
                                                  ref,
                                                  account: a,
                                                ),
                                            onDelete: () async {
                                              final repo = ref.read(
                                                financeRepositoryProvider,
                                              );
                                              if (await repo.accountHasTransactions(
                                                a.id,
                                              )) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        l10n.accountInUse,
                                                      ),
                                                    ),
                                                  );
                                                }
                                                return;
                                              }
                                              if (!context.mounted) return;
                                              final ok = await confirmDialog(
                                                context,
                                                title: l10n.deleteConfirmTitle,
                                                body: l10n.deleteConfirmBody,
                                                confirmLabel: l10n.delete,
                                              );
                                              if (!context.mounted) return;
                                              if (ok) await repo.deleteAccount(a.id);
                                            },
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              onPressed: () async {
                                Navigator.pop(context);
                                await showAccountEditor(context, ref);
                              },
                              icon: const Icon(Icons.add),
                              label: Text(l10n.add),
                            ),
                          ],
                        ),
                  ),
        ),
  );
}

Future<void> showBudgetEditor(
  BuildContext context,
  WidgetRef ref, {
  Budget? budget,
}) async {
  final l10n = context.l10n;
  final amountCtrl = TextEditingController(
    text:
        budget == null
            ? ''
            : Money.paiseToRupees(budget.amountPaise).toString(),
  );
  int? categoryId = budget?.categoryId;
  final saved = await showDialog<bool>(
    context: context,
    builder:
        (dialogContext) => Consumer(
          builder:
              (context, ref, _) => StatefulBuilder(
                builder:
                    (context, setState) {
                      final categories =
                          ref.watch(categoriesProvider).valueOrNull ??
                          const <Category>[];
                      final expense =
                          categories.where((c) => c.kind == 1).toList();
                      return AlertDialog(
                        title: Text(budget == null ? l10n.budgets : l10n.edit),
                        content: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: amountCtrl,
                                autofocus: true,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: InputDecoration(
                                  labelText: l10n.amount,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                l10n.category,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(height: 8),
                              CategoryChipPicker(
                                categories: expense,
                                selectedId: categoryId,
                                kind: CategoryKind.expense,
                                noneLabel: l10n.all,
                                onSelected:
                                    (id) => setState(() => categoryId = id),
                              ),
                            ],
                          ),
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
                      );
                    },
              ),
        ),
  );
  final rupees = double.tryParse(amountCtrl.text.trim());
  if (saved == true && rupees != null && rupees > 0) {
    final repo = ref.read(financeRepositoryProvider);
    final paise = Money.rupeesToPaise(rupees);
    if (budget == null) {
      await repo.createBudget(
        categoryId: categoryId,
        amountPaise: paise,
        startDate: DateTime.now(),
      );
    } else {
      await repo.updateBudget(
        budget.copyWith(
          categoryId: Value(categoryId),
          amountPaise: paise,
        ),
      );
    }
  }
}

Future<void> showDebtEditor(
  BuildContext context,
  WidgetRef ref, {
  Debt? debt,
}) async {
  final l10n = context.l10n;
  final nameCtrl = TextEditingController(text: debt?.name ?? '');
  final amountCtrl = TextEditingController(
    text:
        debt == null
            ? ''
            : Money.paiseToRupees(debt.principalPaise).toString(),
  );
  var type = debt?.type ?? 0;
  final saved = await showDialog<bool>(
    context: context,
    builder:
        (context) => StatefulBuilder(
          builder:
              (context, setState) => AlertDialog(
                title: Text(debt == null ? l10n.debts : l10n.edit),
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
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(labelText: l10n.principal),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<int>(
                      segments: [
                        ButtonSegment(value: 0, label: Text(l10n.debtIOwe)),
                        ButtonSegment(value: 1, label: Text(l10n.debtTheyOwe)),
                      ],
                      selected: {type},
                      onSelectionChanged: (s) => setState(() => type = s.first),
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
  final rupees = double.tryParse(amountCtrl.text.trim());
  if (saved == true &&
      rupees != null &&
      rupees > 0 &&
      nameCtrl.text.trim().isNotEmpty) {
    final repo = ref.read(financeRepositoryProvider);
    final paise = Money.rupeesToPaise(rupees);
    if (debt == null) {
      await repo.createDebt(
        name: nameCtrl.text.trim(),
        type: type,
        principalPaise: paise,
        startDate: DateTime.now(),
      );
    } else {
      await repo.updateDebt(
        debt.copyWith(
          name: nameCtrl.text.trim(),
          type: type,
          principalPaise: paise,
        ),
      );
    }
  }
}

Future<void> showPaymentEditor(
  BuildContext context,
  WidgetRef ref,
  Debt debt,
) async {
  final l10n = context.l10n;
  final accounts = ref.read(accountsProvider).valueOrNull ?? const <Account>[];
  final principalCtrl = TextEditingController();
  final interestCtrl = TextEditingController();
  int? accountId = accounts.isNotEmpty ? accounts.first.id : null;
  final saved = await showDialog<bool>(
    context: context,
    builder:
        (context) => StatefulBuilder(
          builder:
              (context, setState) => AlertDialog(
                title: Text(l10n.payment),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: principalCtrl,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(labelText: l10n.principal),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: interestCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(labelText: l10n.interest),
                    ),
                    if (accounts.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: accountId,
                        decoration: InputDecoration(labelText: l10n.account),
                        items: [
                          for (final a in accounts)
                            DropdownMenuItem(value: a.id, child: Text(a.name)),
                        ],
                        onChanged: (v) => setState(() => accountId = v),
                      ),
                    ],
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
  final principal = double.tryParse(principalCtrl.text.trim()) ?? 0;
  final interest = double.tryParse(interestCtrl.text.trim()) ?? 0;
  if (saved == true && (principal > 0 || interest > 0)) {
    await ref
        .read(financeRepositoryProvider)
        .addPayment(
          debtId: debt.id,
          principalPaise: Money.rupeesToPaise(principal),
          interestPaise: Money.rupeesToPaise(interest),
          date: DateTime.now(),
          accountId: accountId,
        );
  }
}

/// Banner shown at the top of the transactions list when recurring rules are
/// due. Each row can be confirmed (recorded as a transaction and advanced).
class _DueRecurringCard extends ConsumerWidget {
  const _DueRecurringCard({required this.rules});
  final List<RecurringRule> rules;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final accounts = ref.watch(accountsProvider).valueOrNull ?? const [];
    final accountNames = {for (final a in accounts) a.id: a.name};
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: SectionCard(
        title: l10n.dueRecurring,
        icon: Icons.event_repeat,
        child: Column(
          children: [
            for (final rule in rules)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  rule.note.isEmpty
                      ? frequencyLabel(l10n, rule.frequency)
                      : rule.note,
                ),
                subtitle: Text(
                  '${formatMoney(rule.amountPaise, locale)} · '
                  '${accountNames[rule.accountId] ?? ''}',
                ),
                trailing: TextButton(
                  onPressed:
                      () => ref
                          .read(financeRepositoryProvider)
                          .confirmRecurring(rule),
                  child: Text(l10n.confirm),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Lists every recurring rule (active or paused) with confirm / pause / delete
/// actions and a button to create a new one.
Future<void> showRecurringManager(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final locale = Localizations.localeOf(context).toString();
  final accounts = ref.read(accountsProvider).valueOrNull ?? const <Account>[];
  final accountNames = {for (final a in accounts) a.id: a.name};
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder:
        (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          builder:
              (context, controller) => ref
                  .watch(recurringRulesProvider)
                  .when(
                    loading: () => const LoadingState(),
                    error: (e, _) => ErrorState(message: e.toString()),
                    data:
                        (rules) => ListView(
                          controller: controller,
                          padding: const EdgeInsets.all(16),
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    l10n.recurring,
                                    style:
                                        Theme.of(context).textTheme.titleLarge,
                                  ),
                                ),
                                FilledButton.icon(
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    await showRecurringEditor(context, ref);
                                  },
                                  icon: const Icon(Icons.add),
                                  label: Text(l10n.add),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (rules.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(l10n.emptyExpenses),
                              ),
                            for (final rule in rules)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  rule.note.isEmpty
                                      ? frequencyLabel(l10n, rule.frequency)
                                      : rule.note,
                                ),
                                subtitle: Text(
                                  '${formatMoney(rule.amountPaise, locale)} · '
                                  '${accountNames[rule.accountId] ?? ''}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: l10n.edit,
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () async {
                                        Navigator.pop(context);
                                        await showRecurringEditor(
                                          context,
                                          ref,
                                          rule: rule,
                                        );
                                      },
                                    ),
                                    IconButton(
                                      tooltip: l10n.confirm,
                                      icon: const Icon(Icons.check_circle),
                                      onPressed:
                                          rule.isActive
                                              ? () => ref
                                                  .read(
                                                    financeRepositoryProvider,
                                                  )
                                                  .confirmRecurring(rule)
                                              : null,
                                    ),
                                    Switch(
                                      value: rule.isActive,
                                      onChanged:
                                          (v) => ref
                                              .read(financeRepositoryProvider)
                                              .setRecurringActive(rule.id, v),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed:
                                          () => ref
                                              .read(financeRepositoryProvider)
                                              .deleteRecurring(rule.id),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                  ),
        ),
  );
}

/// Editor for a new or existing recurring rule (expense or income).
Future<void> showRecurringEditor(
  BuildContext context,
  WidgetRef ref, {
  RecurringRule? rule,
}) async {
  final l10n = context.l10n;
  final accounts = ref.read(accountsProvider).valueOrNull ?? const <Account>[];
  if (accounts.isEmpty) {
    await showAccountEditor(context, ref);
    return;
  }
  final amountCtrl = TextEditingController(
    text:
        rule == null ? '' : Money.paiseToRupees(rule.amountPaise).toString(),
  );
  final noteCtrl = TextEditingController(text: rule?.note ?? '');
  var type =
      rule == null
          ? TransactionType.expense
          : TransactionType.fromIndex(rule.type);
  var accountId = rule?.accountId ?? accounts.first.id;
  int? categoryId = rule?.categoryId;
  var frequency =
      rule == null
          ? RecurrenceFrequency.monthly
          : RecurrenceFrequency.values[rule.frequency.clamp(0, 4)];
  var nextDate = rule?.nextDate ?? DateTime.now();

  final saved = await showDialog<bool>(
    context: context,
    builder:
        (dialogContext) => Consumer(
          builder:
              (context, ref, _) => StatefulBuilder(
                builder: (context, setState) {
                  final categories =
                      ref.watch(categoriesProvider).valueOrNull ??
                      const <Category>[];
                  final filtered =
                      categories
                          .where(
                            (c) =>
                                (type == TransactionType.income && c.kind == 0) ||
                                (type == TransactionType.expense && c.kind == 1),
                          )
                          .toList();
                  return AlertDialog(
                    title: Text(rule == null ? l10n.recurring : l10n.edit),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SegmentedButton<TransactionType>(
                            segments: [
                              ButtonSegment(
                                value: TransactionType.expense,
                                label: Text(l10n.expense),
                              ),
                              ButtonSegment(
                                value: TransactionType.income,
                                label: Text(l10n.income),
                              ),
                            ],
                            selected: {type},
                            onSelectionChanged:
                                (s) => setState(() {
                                  type = s.first;
                                  categoryId = null;
                                }),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: amountCtrl,
                            autofocus: true,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                            decoration: InputDecoration(labelText: l10n.amount),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            value: accountId,
                            decoration: InputDecoration(labelText: l10n.account),
                            items: [
                              for (final a in accounts)
                                DropdownMenuItem(
                                  value: a.id,
                                  child: Text(a.name),
                                ),
                            ],
                            onChanged:
                                (v) => setState(() => accountId = v ?? accountId),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.category,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          CategoryChipPicker(
                            categories: filtered,
                            selectedId: categoryId,
                            kind:
                                type == TransactionType.income
                                    ? CategoryKind.income
                                    : CategoryKind.expense,
                            onSelected: (id) => setState(() => categoryId = id),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<RecurrenceFrequency>(
                            value: frequency,
                            decoration: InputDecoration(
                              labelText: l10n.frequency,
                            ),
                            items: [
                              for (final f in const [
                                RecurrenceFrequency.daily,
                                RecurrenceFrequency.weekly,
                                RecurrenceFrequency.monthly,
                                RecurrenceFrequency.yearly,
                              ])
                                DropdownMenuItem(
                                  value: f,
                                  child: Text(frequencyLabel(l10n, f.index)),
                                ),
                            ],
                            onChanged:
                                (v) => setState(() => frequency = v ?? frequency),
                          ),
                          const SizedBox(height: 12),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.event),
                            title: Text(l10n.taskDue),
                            subtitle: Text(
                              MaterialLocalizations.of(
                                context,
                              ).formatMediumDate(nextDate),
                            ),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: nextDate,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setState(() => nextDate = picked);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: noteCtrl,
                            decoration: InputDecoration(
                              labelText: l10n.description,
                            ),
                          ),
                        ],
                      ),
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
                  );
                },
              ),
        ),
  );
  final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
  if (saved == true && amount > 0) {
    final repo = ref.read(financeRepositoryProvider);
    final paise = Money.rupeesToPaise(amount);
    if (rule == null) {
      await repo.createRecurring(
        type: type.index,
        accountId: accountId,
        amountPaise: paise,
        nextDate: nextDate,
        categoryId: categoryId,
        note: noteCtrl.text.trim(),
        frequency: frequency.index,
      );
    } else {
      await repo.updateRecurring(
        rule.copyWith(
          type: type.index,
          accountId: accountId,
          amountPaise: paise,
          nextDate: nextDate,
          categoryId: Value(categoryId),
          note: noteCtrl.text.trim(),
          frequency: frequency.index,
        ),
      );
    }
  }
}
