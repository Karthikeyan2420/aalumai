import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/l10n_extension.dart';
import '../../core/providers/providers.dart';

class _LanguageOption {
  const _LanguageOption(this.code, this.nativeName, this.englishName);
  final String code;
  final String nativeName;
  final String englishName;
}

const _languages = <_LanguageOption>[
  _LanguageOption('en', 'English', 'English'),
  _LanguageOption('ta', 'தமிழ்', 'Tamil'),
  _LanguageOption('te', 'తెలుగు', 'Telugu'),
  _LanguageOption('ml', 'മലയാളം', 'Malayalam'),
  _LanguageOption('kn', 'ಕನ್ನಡ', 'Kannada'),
];

/// First-launch language selection. Fully skippable so users can start
/// immediately; the language can be changed later in Settings.
class LanguageSetupScreen extends ConsumerWidget {
  const LanguageSetupScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  Future<void> _choose(WidgetRef ref, String? code) async {
    final notifier = ref.read(localeCodeProvider.notifier);
    await notifier.setLocale(code);
    await ref.read(appPreferencesProvider).setFirstRunComplete(true);
    onFinished();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final current = ref.watch(localeCodeProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(24),
              shrinkWrap: true,
              children: [
                const SizedBox(height: 16),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    l10n.appNameScript,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    l10n.tagline,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  l10n.chooseLanguage,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.languageSubtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                for (final lang in _languages)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _LanguageTile(
                      option: lang,
                      selected: current == lang.code,
                      onTap: () => _choose(ref, lang.code),
                    ),
                  ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _choose(ref, null),
                  child: Text(l10n.skip),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _LanguageOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: CircleAvatar(
          backgroundColor:
              selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerHighest,
          child: Text(
            option.nativeName.characters.first,
            style: TextStyle(
              color:
                  selected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          option.nativeName,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(option.englishName),
        trailing: selected ? const Icon(Icons.check_circle) : null,
      ),
    );
  }
}
