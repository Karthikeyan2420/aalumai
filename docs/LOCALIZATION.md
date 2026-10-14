# Localization

AALUMAI ships in **five languages**:

| Code | Language | ARB file |
| --- | --- | --- |
| `en` | English | `lib/core/localization/l10n/app_en.arb` |
| `ta` | தமிழ் (Tamil) | `app_ta.arb` |
| `te` | తెలుగు (Telugu) | `app_te.arb` |
| `ml` | മലയാളം (Malayalam) | `app_ml.arb` |
| `kn` | ಕನ್ನಡ (Kannada) | `app_kn.arb` |

## How it is wired

- `l10n.yaml` configures generation with `synthetic-package: false`, so output is
  checked into the repository at `lib/core/localization/generated/`.
- The app registers `AppLocalizations.delegate` plus the global Material /
  Widgets / Cupertino delegates in `lib/app.dart`.
- `supportedLocales` comes from the generated `AppLocalizations`.
- The active locale is chosen by the `localeCodeProvider` and is persisted;
  `null` means "follow the system locale".

## Using strings in widgets

Import the extension and read `context.l10n`:

```dart
import '../../core/localization/l10n_extension.dart';

Text(context.l10n.appName)
```

`l10n_extension.dart` is a tiny `BuildContext` extension that calls
`AppLocalizations.of(context)`.

## Adding or editing a string

1. Add the key + English value to **`app_en.arb`**.
2. Add the same key with a translation to **every** other ARB (`app_ta.arb`,
   `app_te.arb`, `app_ml.arb`, `app_kn.arb`). Missing keys fall back to English
   but should be translated.
3. Regenerate:

   ```bash
   flutter gen-l10n
   ```

4. Use `context.l10n.yourKey` in code and run `flutter analyze`.

## Adding a whole new language

1. Create `lib/core/localization/l10n/app_<code>.arb` mirroring `app_en.arb`.
2. Add the locale to the language pickers in
   `lib/features/settings/language_setup_screen.dart` and
   `lib/features/settings/settings_screen.dart` (the `_languages` list).
3. Run `flutter gen-l10n`.

## Notes

- Dates: `initializeDateFormatting()` is called at startup so `DateFormat` works
  with non-English locales. Add `intl` locale data awareness when introducing a
  language that `intl` does not ship.
- Placeholders: ARB entries with placeholders must include an
  `@keyName` metadata block in `app_en.arb` describing the placeholder types.
- The brand name **AALUMAI / ஆளுமை** is defined in `lib/core/app_info.dart` and
  intentionally kept the same across locales.
