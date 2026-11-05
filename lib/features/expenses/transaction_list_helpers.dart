import 'package:flutter/material.dart';

import '../../core/db/database.dart';
import '../../core/localization/l10n_extension.dart';

/// Groups transactions by calendar day (newest day first).
Map<DateTime, List<Transaction>> groupTransactionsByDay(
  List<Transaction> transactions,
) {
  final map = <DateTime, List<Transaction>>{};
  for (final t in transactions) {
    final key = DateTime(t.date.year, t.date.month, t.date.day);
    map.putIfAbsent(key, () => []).add(t);
  }
  final keys = map.keys.toList()..sort((a, b) => b.compareTo(a));
  return {for (final k in keys) k: map[k]!};
}

String daySectionLabel(BuildContext context, DateTime day) {
  final l10n = context.l10n;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final d = DateTime(day.year, day.month, day.day);
  if (d == today) return l10n.today;
  if (d == yesterday) return l10n.yesterday;
  return MaterialLocalizations.of(context).formatMediumDate(d);
}

List<Transaction> filterTransactionsForMonth(
  List<Transaction> all,
  DateTime month,
) {
  final from = DateTime(month.year, month.month, 1);
  final to = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
  return all.where((t) => !t.date.isBefore(from) && !t.date.isAfter(to)).toList();
}

List<Transaction> searchTransactions(List<Transaction> list, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return list;
  return list.where((t) {
    if (t.note.toLowerCase().contains(q)) return true;
    final amount = (t.amountPaise / 100).toString();
    return amount.contains(q);
  }).toList();
}
