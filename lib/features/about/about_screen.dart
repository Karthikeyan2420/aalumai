import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/app_info.dart';
import '../../core/localization/l10n_extension.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.about)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/images/logo.png',
                width: 120,
                height: 120,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              AppInfo.nameTa,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Center(
            child: Text(
              AppInfo.nameEn,
              style: theme.textTheme.titleMedium?.copyWith(letterSpacing: 4),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              AppInfo.taglineTa,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 24),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final info = snapshot.data;
              final version =
                  info == null ? '—' : '${info.version} (${info.buildNumber})';
              return Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: Text(l10n.versionLabel),
                      trailing: Text(version),
                    ),
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(l10n.developer),
                      trailing: Text(AppInfo.developer),
                    ),
                    ListTile(
                      leading: const Icon(Icons.new_releases_outlined),
                      title: Text(l10n.releaseLabel),
                      trailing: Text(AppInfo.releaseLabel),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 20,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.privacyLocalFirst,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.aboutDescription),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(l10n.aboutLicenses),
              trailing: const Icon(Icons.chevron_right),
              onTap:
                  () => showLicensePage(
                    context: context,
                    applicationName: AppInfo.nameEn,
                    applicationLegalese: AppInfo.developer,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
