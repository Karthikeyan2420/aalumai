import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/localization/generated/app_localizations.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/utils/money.dart';
import '../../core/utils/recurrence.dart';
import 'category_picker.dart';
import 'data/finance_repository.dart';

Future<void> showTransactionEditor(
  BuildContext context,
  WidgetRef ref, {
  Transaction? transaction,
}) async {
  final accounts = ref.read(accountsProvider).valueOrNull ?? const <Account>[];
  if (accounts.isEmpty) {
    await showAccountEditor(context, ref);
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder:
        (ctx) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: _TransactionEditorSheet(
            transaction: transaction,
            accounts: accounts,
          ),
        ),
  );
}

/// Account editor — exported for use from transaction flow.
Future<void> showAccountEditor(
  BuildContext context,
  WidgetRef ref, {
  Account? account,
}) async {
  final l10n = context.l10n;
  final nameCtrl = TextEditingController(text: account?.name ?? '');
  final balanceCtrl = TextEditingController(
    text:
        account == null
            ? ''
            : Money.paiseToRupees(account.openingBalancePaise).toString(),
  );
  var type = AccountType.fromIndex(account?.type ?? 0);
  final saved = await showDialog<bool>(
    context: context,
    builder:
        (context) => StatefulBuilder(
          builder:
              (context, setState) => AlertDialog(
                title: Text(account == null ? l10n.account : l10n.edit),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
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
                    if (account != null) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: balanceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: l10n.openingBalance,
                        ),
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
  if (saved != true || nameCtrl.text.trim().isEmpty) return;
  final repo = ref.read(financeRepositoryProvider);
  if (account == null) {
    await repo.createAccount(name: nameCtrl.text.trim(), type: type);
  } else {
    final opening =
        double.tryParse(balanceCtrl.text.trim()) ?? account.openingBalancePaise / 100;
    await repo.updateAccount(
      account.copyWith(
        name: nameCtrl.text.trim(),
        type: type.index,
        openingBalancePaise: Money.rupeesToPaise(opening),
      ),
    );
  }
}

class _TransactionEditorSheet extends ConsumerStatefulWidget {
  const _TransactionEditorSheet({
    required this.transaction,
    required this.accounts,
  });

  final Transaction? transaction;
  final List<Account> accounts;

  @override
  ConsumerState<_TransactionEditorSheet> createState() =>
      _TransactionEditorSheetState();
}

class _TransactionEditorSheetState
    extends ConsumerState<_TransactionEditorSheet> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  late TransactionType _type;
  late int _accountId;
  late int _transferId;
  int? _categoryId;
  late DateTime _date;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    _amountCtrl = TextEditingController(
      text:
          t == null ? '' : Money.paiseToRupees(t.amountPaise).toString(),
    );
    _noteCtrl = TextEditingController(text: t?.note ?? '');
    _type =
        t == null
            ? TransactionType.expense
            : TransactionType.fromIndex(t.type);
    _accountId = t?.accountId ?? widget.accounts.first.id;
    _transferId =
        t?.transferAccountId ??
        (widget.accounts.length > 1
            ? widget.accounts[1].id
            : widget.accounts.first.id);
    _categoryId = t?.categoryId;
    _date = t?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  List<Category> _filteredCategories(List<Category> all) {
    return all
        .where(
          (c) =>
              (_type == TransactionType.income && c.kind == 0) ||
              (_type == TransactionType.expense && c.kind == 1),
        )
        .toList();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final rupees = double.tryParse(_amountCtrl.text.trim());
    if (rupees == null || rupees <= 0) {
      setState(() => _amountError = l10n.required);
      return;
    }
    if (_type == TransactionType.transfer && _accountId == _transferId) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.sameAccount)));
      return;
    }
    final repo = ref.read(financeRepositoryProvider);
    final paise = Money.rupeesToPaise(rupees);
    final note = _noteCtrl.text.trim();
    final existing = widget.transaction;

    if (existing == null) {
      if (_type == TransactionType.transfer) {
        await repo.addTransfer(
          fromAccountId: _accountId,
          toAccountId: _transferId,
          amountPaise: paise,
          date: _date,
          note: note,
        );
      } else {
        await repo.addTransaction(
          accountId: _accountId,
          type: _type,
          amountPaise: paise,
          date: _date,
          categoryId: _categoryId,
          note: note,
        );
      }
    } else {
      final updated = existing.copyWith(
        accountId: _accountId,
        type: _type.index,
        amountPaise: paise,
        date: _date,
        categoryId:
            _type == TransactionType.transfer
                ? const Value(null)
                : Value(_categoryId),
        note: note,
        transferAccountId:
            _type == TransactionType.transfer
                ? Value(_transferId)
                : const Value(null),
      );
      await repo.updateTransaction(updated);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final categories =
        ref.watch(categoriesProvider).valueOrNull ?? const <Category>[];
    final filtered = _filteredCategories(categories);
    final editing = widget.transaction != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            editing ? l10n.edit : l10n.addTransaction,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
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
              if (widget.accounts.length > 1)
                ButtonSegment(
                  value: TransactionType.transfer,
                  label: Text(l10n.transfer),
                ),
            ],
            selected: {_type},
            onSelectionChanged: (s) {
              setState(() {
                _type = s.first;
                if (_type == TransactionType.transfer) {
                  _categoryId = null;
                } else if (_categoryId != null) {
                  final cat = categories
                      .where((c) => c.id == _categoryId)
                      .firstOrNull;
                  if (cat != null &&
                      ((_type == TransactionType.income && cat.kind != 0) ||
                          (_type == TransactionType.expense && cat.kind != 1))) {
                    _categoryId = null;
                  }
                }
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            autofocus: !editing,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.amount,
              errorText: _amountError,
            ),
            onChanged: (_) {
              if (_amountError != null) setState(() => _amountError = null);
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(l10n.date),
            subtitle: Text(
              MaterialLocalizations.of(context).formatMediumDate(_date),
            ),
            onTap: _pickDate,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _accountId,
            decoration: InputDecoration(
              labelText:
                  _type == TransactionType.transfer
                      ? l10n.fromAccount
                      : l10n.account,
            ),
            items: [
              for (final a in widget.accounts)
                DropdownMenuItem(value: a.id, child: Text(a.name)),
            ],
            onChanged: (v) => setState(() => _accountId = v ?? _accountId),
          ),
          if (_type == TransactionType.transfer) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _transferId,
              decoration: InputDecoration(labelText: l10n.toAccount),
              items: [
                for (final a in widget.accounts)
                  DropdownMenuItem(value: a.id, child: Text(a.name)),
              ],
              onChanged: (v) => setState(() => _transferId = v ?? _transferId),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(l10n.category, style: Theme.of(context).textTheme.labelLarge),
            ),
            const SizedBox(height: 8),
            CategoryChipPicker(
              categories: filtered,
              selectedId: _categoryId,
              kind:
                  _type == TransactionType.income
                      ? CategoryKind.income
                      : CategoryKind.expense,
              onSelected: (id) => setState(() => _categoryId = id),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            decoration: InputDecoration(labelText: l10n.description),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  child: Text(l10n.save),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String frequencyLabel(AppLocalizations l10n, int frequency) {
  final freq = RecurrenceFrequency.values[frequency.clamp(0, 4)];
  return switch (freq) {
    RecurrenceFrequency.none => l10n.none,
    RecurrenceFrequency.daily => l10n.everyDay,
    RecurrenceFrequency.weekly => l10n.everyWeek,
    RecurrenceFrequency.monthly => l10n.everyMonth,
    RecurrenceFrequency.yearly => l10n.everyYear,
  };
}
