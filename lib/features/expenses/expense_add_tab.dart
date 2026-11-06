import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dashboard_components.dart';
import 'category_picker.dart';
import 'data/finance_repository.dart';
import 'transaction_editor.dart';

class ExpenseAddTab extends ConsumerStatefulWidget {
  const ExpenseAddTab({super.key});

  @override
  ConsumerState<ExpenseAddTab> createState() => _ExpenseAddTabState();
}

class _ExpenseAddTabState extends ConsumerState<ExpenseAddTab> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _accountNameCtrl = TextEditingController();
  final _openingBalanceCtrl = TextEditingController();
  final _categoryNameCtrl = TextEditingController();

  TransactionType _type = TransactionType.expense;
  AccountType _accountType = AccountType.cash;
  CategoryKind _categoryKind = CategoryKind.expense;
  int? _accountId;
  int? _transferId;
  int? _categoryId;
  DateTime _date = DateTime.now();
  String? _amountError;
  String? _accountNameError;
  String? _categoryNameError;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _accountNameCtrl.dispose();
    _openingBalanceCtrl.dispose();
    _categoryNameCtrl.dispose();
    super.dispose();
  }

  TransactionType _effectiveType(List<Account> accounts) =>
      _type == TransactionType.transfer && accounts.length < 2
          ? TransactionType.expense
          : _type;

  int? _selectedAccount(List<Account> accounts) {
    if (accounts.isEmpty) return null;
    if (_accountId != null && accounts.any((a) => a.id == _accountId)) {
      return _accountId;
    }
    return accounts.first.id;
  }

  int? _selectedTransfer(List<Account> accounts) {
    if (accounts.length < 2) return null;
    if (_transferId != null && accounts.any((a) => a.id == _transferId)) {
      return _transferId;
    }
    final from = _selectedAccount(accounts);
    return accounts.firstWhere((a) => a.id != from).id;
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

  Future<void> _save(List<Account> accounts) async {
    final l10n = context.l10n;
    final rupees = double.tryParse(_amountCtrl.text.trim());
    if (rupees == null || rupees <= 0) {
      setState(() => _amountError = l10n.required);
      return;
    }
    final from = _selectedAccount(accounts);
    if (from == null) return;
    final type = _effectiveType(accounts);
    final to = _selectedTransfer(accounts);
    if (type == TransactionType.transfer && (to == null || to == from)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.sameAccount)));
      return;
    }

    final repo = ref.read(financeRepositoryProvider);
    final paise = Money.rupeesToPaise(rupees);
    final note = _noteCtrl.text.trim();
    if (type == TransactionType.transfer) {
      await repo.addTransfer(
        fromAccountId: from,
        toAccountId: to!,
        amountPaise: paise,
        date: _date,
        note: note,
      );
    } else {
      await repo.addTransaction(
        accountId: from,
        type: type,
        amountPaise: paise,
        date: _date,
        categoryId: _categoryId,
        note: note,
      );
    }
    if (!mounted) return;
    _amountCtrl.clear();
    _noteCtrl.clear();
    setState(() {
      _amountError = null;
      _categoryId = null;
      _date = DateTime.now();
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Transaction saved')));
  }

  Future<void> _addAccount() async {
    final l10n = context.l10n;
    final name = _accountNameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _accountNameError = l10n.required);
      return;
    }
    final opening = double.tryParse(_openingBalanceCtrl.text.trim()) ?? 0;
    await ref
        .read(financeRepositoryProvider)
        .createAccount(
          name: name,
          type: _accountType,
          openingBalancePaise: Money.rupeesToPaise(opening),
        );
    _accountNameCtrl.clear();
    _openingBalanceCtrl.clear();
    if (!mounted) return;
    setState(() {
      _accountNameError = null;
      _accountType = AccountType.cash;
    });
  }

  Future<void> _addCategory() async {
    final l10n = context.l10n;
    final name = _categoryNameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _categoryNameError = l10n.required);
      return;
    }
    final repo = ref.read(financeRepositoryProvider);
    if (await repo.categoryNameExists(name, _categoryKind)) {
      if (mounted) setState(() => _categoryNameError = l10n.categoryExists);
      return;
    }
    await repo.createCategory(name, _categoryKind);
    _categoryNameCtrl.clear();
    if (!mounted) return;
    setState(() => _categoryNameError = null);
  }

  Future<void> _archiveCategory(Category category) async {
    if (!category.isCustom) return;
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l10n.deleteConfirmTitle),
            content: Text(l10n.deleteConfirmBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.delete),
              ),
            ],
          ),
    );
    if (ok != true) return;
    await ref.read(financeRepositoryProvider).archiveCategory(category.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final accounts = ref.watch(accountsProvider).valueOrNull ?? const [];
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final type = _effectiveType(accounts);
    final selectedAccount = _selectedAccount(accounts);
    final filteredCategories =
        categories
            .where(
              (c) =>
                  (type == TransactionType.income && c.kind == 0) ||
                  (type == TransactionType.expense && c.kind == 1),
            )
            .toList();
    final kindCategories =
        categories.where((c) => c.kind == _categoryKind.index).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        10,
        AppSpacing.screen,
        96,
      ),
      children: [
        SectionHeader(title: l10n.addTransaction),
        SectionCard(
          title: l10n.addTransaction,
          icon: Icons.add_card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                onSelectionChanged: (selection) {
                  setState(() {
                    _type = selection.first;
                    _categoryId = null;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l10n.amount,
                  errorText: _amountError,
                ),
                onChanged: (_) {
                  if (_amountError != null) {
                    setState(() => _amountError = null);
                  }
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: Text(l10n.date),
                subtitle: Text(
                  MaterialLocalizations.of(context).formatMediumDate(_date),
                ),
                onTap: _pickDate,
              ),
              DropdownButtonFormField<int>(
                value: selectedAccount,
                decoration: InputDecoration(
                  labelText:
                      type == TransactionType.transfer
                          ? l10n.fromAccount
                          : l10n.account,
                ),
                items: [
                  for (final account in accounts)
                    DropdownMenuItem(
                      value: account.id,
                      child: Text(account.name),
                    ),
                ],
                onChanged: (value) => setState(() => _accountId = value),
              ),
              if (type == TransactionType.transfer) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _selectedTransfer(accounts),
                  decoration: InputDecoration(labelText: l10n.toAccount),
                  items: [
                    for (final account in accounts)
                      DropdownMenuItem(
                        value: account.id,
                        child: Text(
                          '${account.name} · '
                          '${AccountType.fromIndex(account.type).label}',
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _transferId = value),
                ),
              ] else ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.category,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(height: 8),
                CategoryChipPicker(
                  categories: filteredCategories,
                  selectedId: _categoryId,
                  kind:
                      type == TransactionType.income
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
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: accounts.isEmpty ? null : () => _save(accounts),
                icon: const Icon(Icons.save_outlined),
                label: Text(l10n.save),
              ),
              if (accounts.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Add an account below to record a transaction.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionHeader(title: 'Accounts'),
        SectionCard(
          title: 'New account',
          icon: Icons.account_balance_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _accountNameCtrl,
                decoration: InputDecoration(
                  labelText: l10n.accountName,
                  errorText: _accountNameError,
                ),
                onChanged: (_) {
                  if (_accountNameError != null) {
                    setState(() => _accountNameError = null);
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AccountType>(
                value: _accountType,
                decoration: const InputDecoration(labelText: 'Account type'),
                items: [
                  for (final accountType in AccountType.values)
                    DropdownMenuItem(
                      value: accountType,
                      child: Text(accountType.label),
                    ),
                ],
                onChanged:
                    (value) =>
                        setState(() => _accountType = value ?? _accountType),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _openingBalanceCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: l10n.openingBalance),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: _addAccount,
                icon: const Icon(Icons.add),
                label: Text(l10n.add),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (accounts.isEmpty)
          const EmptyState(
            icon: Icons.account_balance_wallet_outlined,
            title: 'No accounts yet',
            message: 'Create a cash, bank or UPI account to get started.',
          )
        else
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final account in accounts)
                  ListTile(
                    leading: Icon(_accountIcon(account)),
                    title: Text(account.name),
                    subtitle: Text(
                      '${AccountType.fromIndex(account.type).label} · '
                      'Opening ${formatMoney(account.openingBalancePaise, locale)}',
                    ),
                    trailing: IconButton(
                      tooltip: l10n.edit,
                      icon: const Icon(Icons.edit_outlined),
                      onPressed:
                          () =>
                              showAccountEditor(context, ref, account: account),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 14),
        SectionHeader(title: 'Categories'),
        SectionCard(
          title: l10n.newCategory,
          icon: Icons.category_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<CategoryKind>(
                segments: [
                  ButtonSegment(
                    value: CategoryKind.expense,
                    label: Text(l10n.expense),
                  ),
                  ButtonSegment(
                    value: CategoryKind.income,
                    label: Text(l10n.income),
                  ),
                ],
                selected: {_categoryKind},
                onSelectionChanged:
                    (selection) =>
                        setState(() => _categoryKind = selection.first),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _categoryNameCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.name,
                        errorText: _categoryNameError,
                      ),
                      onChanged: (_) {
                        if (_categoryNameError != null) {
                          setState(() => _categoryNameError = null);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: FilledButton.tonal(
                      onPressed: _addCategory,
                      child: Text(l10n.add),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (kindCategories.isEmpty)
                Text(
                  'No ${_categoryKind.name} categories yet.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final category in kindCategories)
                      GestureDetector(
                        onLongPress:
                            category.isCustom
                                ? () => _archiveCategory(category)
                                : null,
                        child: Chip(
                          label: Text(category.name),
                          onDeleted:
                              category.isCustom
                                  ? () => _archiveCategory(category)
                                  : null,
                          deleteIcon: const Icon(Icons.close, size: 16),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

IconData _accountIcon(Account account) {
  return switch (AccountType.fromIndex(account.type)) {
    AccountType.cash => Icons.payments_outlined,
    AccountType.bank => Icons.account_balance_outlined,
    AccountType.wallet => Icons.account_balance_wallet_outlined,
    AccountType.credit => Icons.credit_card_outlined,
    AccountType.other => Icons.savings_outlined,
    AccountType.upi => Icons.qr_code_2_outlined,
  };
}
