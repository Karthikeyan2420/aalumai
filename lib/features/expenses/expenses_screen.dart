import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/common.dart';
import 'data/finance_repository.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final balance = ref.watch(totalBalanceProvider);
    final locale = Localizations.localeOf(context).toString();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.expenses),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.expense),
              Tab(text: l10n.budgets),
              Tab(text: l10n.debts),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => showTransactionEditor(context, ref),
          icon: const Icon(Icons.add),
          label: Text(l10n.addTransaction),
        ),
        body: Column(
          children: [
            Card(
              margin: const EdgeInsets.all(12),
              child: ListTile(
                leading: const Icon(Icons.account_balance_wallet),
                title: Text(l10n.totalBalance),
                trailing: Text(
                  balance.valueOrNull == null
                      ? '—'
                      : formatMoney(balance.valueOrNull!, locale),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                onTap: () => showAccountsManager(context, ref),
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [_TransactionsTab(), _BudgetsTab(), _DebtsTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionsTab extends ConsumerWidget {
  const _TransactionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        if (list.isEmpty) {
          return EmptyState(
            icon: Icons.receipt_long_outlined,
            message: l10n.emptyExpenses,
            actionLabel: l10n.addTransaction,
            onAction: () => showTransactionEditor(context, ref),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: list.length + (showChart ? 1 : 0),
          itemBuilder: (context, i) {
            if (showChart && i == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: SectionCard(
                  title: l10n.spendingByCategory,
                  icon: Icons.pie_chart_outline,
                  child: SimpleBarChart(slices: slices),
                ),
              );
            }
            final t = list[i - (showChart ? 1 : 0)];
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
              DateFormat.yMMMd(locale).format(t.date),
            ].where((s) => s.isNotEmpty).join(' · ');
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Text(sign, style: TextStyle(color: color)),
              ),
              title: Text(t.note.isEmpty ? type.name : t.note),
              subtitle: Text(subtitle),
              trailing: Text(
                formatMoney(t.amountPaise, locale),
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
              onLongPress: () async {
                final ok = await confirmDialog(
                  context,
                  title: l10n.deleteConfirmTitle,
                  body: l10n.deleteConfirmBody,
                  confirmLabel: l10n.delete,
                );
                if (ok) {
                  await ref
                      .read(financeRepositoryProvider)
                      .deleteTransaction(t.id);
                }
              },
            );
          },
        );
      },
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
                            _BudgetTile(budget: b, locale: locale),
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
  const _BudgetTile({required this.budget, required this.locale});
  final Budget budget;
  final String locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    Expanded(child: Text(context.l10n.budget)),
                    Text(
                      '${formatMoney(spent, locale)} / '
                      '${formatMoney(budget.amountPaise, locale)}',
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
                              _DebtTile(debt: d, locale: locale),
                          ],
                        ),
              ),
            ],
          ),
    );
  }
}

class _DebtTile extends ConsumerWidget {
  const _DebtTile({required this.debt, required this.locale});
  final Debt debt;
  final String locale;

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
            trailing: IconButton(
              icon: const Icon(Icons.payments_outlined),
              tooltip: l10n.payment,
              onPressed: () => showPaymentEditor(context, ref, debt),
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
                                trailing: Text(
                                  formatMoney(a.openingBalancePaise, locale),
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

Future<void> showAccountEditor(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final controller = TextEditingController();
  var type = AccountType.cash;
  final saved = await showDialog<bool>(
    context: context,
    builder:
        (context) => StatefulBuilder(
          builder:
              (context, setState) => AlertDialog(
                title: Text(l10n.account),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: InputDecoration(labelText: l10n.accountName),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<AccountType>(
                      value: type,
                      decoration: InputDecoration(labelText: l10n.account),
                      items: [
                        for (final t in AccountType.values)
                          DropdownMenuItem(value: t, child: Text(t.name)),
                      ],
                      onChanged: (v) => setState(() => type = v ?? type),
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
  if (saved == true && controller.text.trim().isNotEmpty) {
    await ref
        .read(financeRepositoryProvider)
        .createAccount(name: controller.text.trim(), type: type);
  }
}

Future<void> showTransactionEditor(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final accounts = ref.read(accountsProvider).valueOrNull ?? const <Account>[];
  if (accounts.isEmpty) {
    await showAccountEditor(context, ref);
    return;
  }
  final categories =
      ref.read(categoriesProvider).valueOrNull ?? const <Category>[];
  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  var type = TransactionType.expense;
  var accountId = accounts.first.id;
  var transferId = accounts.length > 1 ? accounts[1].id : accounts.first.id;
  var categoryId = -1;

  final saved = await showDialog<bool>(
    context: context,
    builder:
        (context) => StatefulBuilder(
          builder: (context, setState) {
            final filtered =
                categories
                    .where(
                      (c) =>
                          (type == TransactionType.income && c.kind == 0) ||
                          (type == TransactionType.expense && c.kind == 1),
                    )
                    .toList();
            return AlertDialog(
              title: Text(l10n.addTransaction),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                        if (accounts.length > 1)
                          ButtonSegment(
                            value: TransactionType.transfer,
                            label: Text(l10n.transfer),
                          ),
                      ],
                      selected: {type},
                      onSelectionChanged:
                          (s) => setState(() {
                            type = s.first;
                            categoryId = -1;
                          }),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(labelText: l10n.amount),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: accountId,
                      decoration: InputDecoration(
                        labelText:
                            type == TransactionType.transfer
                                ? l10n.fromAccount
                                : l10n.account,
                      ),
                      items: [
                        for (final a in accounts)
                          DropdownMenuItem(value: a.id, child: Text(a.name)),
                      ],
                      onChanged:
                          (v) => setState(() => accountId = v ?? accountId),
                    ),
                    if (type == TransactionType.transfer) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: transferId,
                        decoration: InputDecoration(labelText: l10n.toAccount),
                        items: [
                          for (final a in accounts)
                            DropdownMenuItem(value: a.id, child: Text(a.name)),
                        ],
                        onChanged:
                            (v) => setState(() => transferId = v ?? transferId),
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: categoryId,
                        decoration: InputDecoration(labelText: l10n.category),
                        items: [
                          DropdownMenuItem(value: -1, child: Text(l10n.none)),
                          for (final c in filtered)
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                        ],
                        onChanged: (v) => setState(() => categoryId = v ?? -1),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteCtrl,
                      decoration: InputDecoration(labelText: l10n.description),
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
  );

  final rupees = double.tryParse(amountCtrl.text.trim());
  if (saved == true && rupees != null && rupees > 0) {
    final repo = ref.read(financeRepositoryProvider);
    final paise = Money.rupeesToPaise(rupees);
    if (type == TransactionType.transfer) {
      await repo.addTransfer(
        fromAccountId: accountId,
        toAccountId: transferId,
        amountPaise: paise,
        date: DateTime.now(),
        note: noteCtrl.text.trim(),
      );
    } else {
      await repo.addTransaction(
        accountId: accountId,
        type: type,
        amountPaise: paise,
        date: DateTime.now(),
        categoryId: categoryId == -1 ? null : categoryId,
        note: noteCtrl.text.trim(),
      );
    }
  }
}

Future<void> showBudgetEditor(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final categories =
      ref.read(categoriesProvider).valueOrNull ?? const <Category>[];
  final amountCtrl = TextEditingController();
  var categoryId = -1;
  final saved = await showDialog<bool>(
    context: context,
    builder:
        (context) => StatefulBuilder(
          builder:
              (context, setState) => AlertDialog(
                title: Text(l10n.budgets),
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
                    DropdownButtonFormField<int>(
                      value: categoryId,
                      decoration: InputDecoration(labelText: l10n.category),
                      items: [
                        DropdownMenuItem(value: -1, child: Text(l10n.all)),
                        for (final c in categories.where((c) => c.kind == 1))
                          DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ],
                      onChanged: (v) => setState(() => categoryId = v ?? -1),
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
  if (saved == true && rupees != null && rupees > 0) {
    await ref
        .read(financeRepositoryProvider)
        .createBudget(
          categoryId: categoryId == -1 ? null : categoryId,
          amountPaise: Money.rupeesToPaise(rupees),
          startDate: DateTime.now(),
        );
  }
}

Future<void> showDebtEditor(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final nameCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  var type = 0;
  final saved = await showDialog<bool>(
    context: context,
    builder:
        (context) => StatefulBuilder(
          builder:
              (context, setState) => AlertDialog(
                title: Text(l10n.debts),
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
                        ButtonSegment(value: 0, label: Text(l10n.debt)),
                        ButtonSegment(value: 1, label: Text(l10n.payment)),
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
    await ref
        .read(financeRepositoryProvider)
        .createDebt(
          name: nameCtrl.text.trim(),
          type: type,
          principalPaise: Money.rupeesToPaise(rupees),
          startDate: DateTime.now(),
        );
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
