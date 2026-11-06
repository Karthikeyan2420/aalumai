import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dashboard_components.dart';
import 'data/finance_repository.dart';

enum AnalysisPeriod { thisMonth, lastMonth, last3Months, thisYear, allTime }

extension AnalysisPeriodX on AnalysisPeriod {
  String get label => switch (this) {
    AnalysisPeriod.thisMonth => 'This month',
    AnalysisPeriod.lastMonth => 'Last month',
    AnalysisPeriod.last3Months => 'Last 3 months',
    AnalysisPeriod.thisYear => 'This year',
    AnalysisPeriod.allTime => 'All time',
  };

  ({DateTime from, DateTime to}) range(DateTime now) {
    switch (this) {
      case AnalysisPeriod.thisMonth:
        return (from: DateTime(now.year, now.month, 1), to: _endOfMonth(now));
      case AnalysisPeriod.lastMonth:
        return (
          from: DateTime(now.year, now.month - 1, 1),
          to: DateTime(now.year, now.month, 0, 23, 59, 59),
        );
      case AnalysisPeriod.last3Months:
        return (
          from: DateTime(now.year, now.month - 2, 1),
          to: _endOfMonth(now),
        );
      case AnalysisPeriod.thisYear:
        return (from: DateTime(now.year, 1, 1), to: _endOfDay(now));
      case AnalysisPeriod.allTime:
        return (from: DateTime(2000, 1, 1), to: _endOfDay(now));
    }
  }
}

DateTime _endOfMonth(DateTime value) =>
    DateTime(value.year, value.month + 1, 0, 23, 59, 59);

DateTime _endOfDay(DateTime value) =>
    DateTime(value.year, value.month, value.day, 23, 59, 59);

({DateTime from, DateTime to}) _lastSixMonths(DateTime now) => (
  from: DateTime(now.year, now.month - 5, 1),
  to: _endOfDay(now),
);

List<DateTime> _monthStarts(DateTime now) => [
  for (var i = 5; i >= 0; i--) DateTime(now.year, now.month - i, 1),
];

class ExpenseDashboardTab extends ConsumerStatefulWidget {
  const ExpenseDashboardTab({super.key});

  @override
  ConsumerState<ExpenseDashboardTab> createState() =>
      _ExpenseDashboardTabState();
}

class _ExpenseDashboardTabState extends ConsumerState<ExpenseDashboardTab> {
  AnalysisPeriod _period = AnalysisPeriod.thisMonth;
  int _accountId = -1;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final now = DateTime.now();

    final range = _period.range(now);
    final txnsAsync = ref.watch(transactionsBetweenProvider(range));
    final trendAsync = ref.watch(
      transactionsBetweenProvider(_lastSixMonths(now)),
    );
    final accounts = ref.watch(accountsProvider).valueOrNull ?? const [];
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];

    final selectedAccount =
        _accountId == -1 || accounts.any((a) => a.id == _accountId)
            ? _accountId
            : -1;
    bool matchesAccount(Transaction t) =>
        selectedAccount == -1 ||
        t.accountId == selectedAccount ||
        t.transferAccountId == selectedAccount;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        10,
        AppSpacing.screen,
        96,
      ),
      children: [
        AppCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<AnalysisPeriod>(
                  value: _period,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: 'Period',
                    isDense: true,
                  ),
                  items: [
                    for (final period in AnalysisPeriod.values)
                      DropdownMenuItem(
                        value: period,
                        child: Text(period.label),
                      ),
                  ],
                  onChanged:
                      (value) => setState(() => _period = value ?? _period),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: selectedAccount,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: 'Account',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: -1,
                      child: Text('All accounts'),
                    ),
                    for (final account in accounts)
                      DropdownMenuItem(
                        value: account.id,
                        child: Text(
                          '${account.name} · '
                          '${AccountType.fromIndex(account.type).label}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged:
                      (value) => setState(() => _accountId = value ?? -1),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.cardGap),
        txnsAsync.when(
          loading:
              () => const Padding(
                padding: EdgeInsets.all(32),
                child: LoadingState(),
              ),
          error: (e, _) => ErrorState(message: e.toString()),
          data: (all) {
            final txns = all.where(matchesAccount).toList();
            var income = 0;
            var expense = 0;
            var transfers = 0;
            for (final t in txns) {
              switch (TransactionType.fromIndex(t.type)) {
                case TransactionType.income:
                  income += t.amountPaise;
                case TransactionType.expense:
                  expense += t.amountPaise;
                case TransactionType.transfer:
                  transfers += t.amountPaise;
              }
            }
            final net = income - expense;
            final categoryNames = {for (final c in categories) c.id: c.name};
            final categorySpends = aggregateTransactionsByCategory(
              transactions: txns,
              categoryNames: categoryNames,
              type: TransactionType.expense,
            );
            final categorySlices = [
              for (final spend in categorySpends)
                ChartSlice(
                  label: spend.label,
                  value: Money.paiseToRupees(spend.amountPaise),
                ),
            ];

            final trendTxns =
                (trendAsync.valueOrNull ?? const <Transaction>[])
                    .where(matchesAccount)
                    .toList();
            final trendSlices = [
              for (final month in _monthStarts(now))
                ChartSlice(
                  label: DateFormat.MMM(locale).format(month),
                  value: Money.paiseToRupees(
                    trendTxns
                        .where(
                          (t) =>
                              t.type == TransactionType.expense.index &&
                              t.date.year == month.year &&
                              t.date.month == month.month,
                        )
                        .fold<int>(0, (sum, t) => sum + t.amountPaise),
                  ),
                ),
            ];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(title: 'Summary'),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        icon: Icons.trending_up,
                        accent: Colors.green,
                        label: l10n.income,
                        value: formatMoney(income, locale),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatTile(
                        icon: Icons.trending_down,
                        accent: theme.colorScheme.error,
                        label: l10n.expense,
                        value: formatMoney(expense, locale),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        icon: Icons.account_balance_wallet,
                        accent:
                            net >= 0
                                ? theme.colorScheme.primary
                                : theme.colorScheme.error,
                        label: 'Net',
                        value: formatMoney(net, locale),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatTile(
                        icon: Icons.swap_horiz,
                        accent: Colors.blueGrey,
                        label: l10n.transfer,
                        value: formatMoney(transfers, locale),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Expense by category',
                  icon: Icons.pie_chart_outline,
                  child:
                      categorySpends.isEmpty
                          ? _EmptyAnalysis(message: l10n.emptyExpenses)
                          : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SimpleBarChart(slices: categorySlices),
                              const SizedBox(height: 12),
                              for (final spend in categorySpends.take(5))
                                ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(spend.label),
                                  trailing: Text(
                                    formatMoney(spend.amountPaise, locale),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Monthly trend · last 6 months',
                  icon: Icons.show_chart,
                  child:
                      trendSlices.every((slice) => slice.value == 0)
                          ? _EmptyAnalysis(message: l10n.emptyExpenses)
                          : SimpleBarChart(slices: trendSlices),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _EmptyAnalysis extends StatelessWidget {
  const _EmptyAnalysis({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
