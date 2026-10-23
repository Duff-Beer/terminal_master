import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/l10n/app_localizations.dart';

/// Guards the translation files against drift.
///
/// Adding a string to the template without translating it is the easy mistake
/// to make, and nothing else catches it: gen-l10n silently falls back to the
/// template text, so an untranslated key looks fine in English and shows
/// English inside the German UI. These tests fail instead.
void main() {
  final arbDirectory = Directory('lib/l10n');

  Map<String, Object?> readArb(String fileName) {
    final file = File('${arbDirectory.path}/$fileName');
    expect(file.existsSync(), isTrue, reason: '${file.path} is missing');
    return jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  }

  /// Message ids only — `@@locale` and the `@key` metadata entries are not
  /// translatable strings.
  Set<String> messageKeys(Map<String, Object?> arb) =>
      arb.keys.where((key) => !key.startsWith('@')).toSet();

  test('every supported locale has an ARB file', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final file = File('${arbDirectory.path}/app_${locale.languageCode}.arb');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'no ARB file for supported locale ${locale.languageCode}',
      );
    }
  });

  test('translations cover exactly the template keys', () {
    final template = messageKeys(readArb('app_en.arb'));
    expect(template, isNotEmpty);

    for (final locale in AppLocalizations.supportedLocales) {
      if (locale.languageCode == 'en') continue;
      final translation = messageKeys(
        readArb('app_${locale.languageCode}.arb'),
      );

      expect(
        template.difference(translation),
        isEmpty,
        reason:
            'app_${locale.languageCode}.arb is missing keys present in the '
            'template',
      );
      expect(
        translation.difference(template),
        isEmpty,
        reason:
            'app_${locale.languageCode}.arb has keys the template does not '
            'declare',
      );
    }
  });

  test('placeholders match between template and translations', () {
    // A placeholder is `{name}` or an ICU argument `{name, plural, …}`. The
    // trailing `[,}]` is what keeps plural branch text such as
    // `other{{count} files}` from being mistaken for a placeholder named
    // "files".
    final placeholder = RegExp(r'\{(\w+)\s*[,}]');
    Set<String> placeholdersOf(String message) =>
        placeholder.allMatches(message).map((m) => m.group(1)!).toSet();

    final template = readArb('app_en.arb');
    for (final locale in AppLocalizations.supportedLocales) {
      if (locale.languageCode == 'en') continue;
      final translation = readArb('app_${locale.languageCode}.arb');

      for (final key in messageKeys(template)) {
        final templateMessage = template[key] as String;
        final translatedMessage = translation[key] as String?;
        if (translatedMessage == null) continue;
        expect(
          placeholdersOf(translatedMessage),
          placeholdersOf(templateMessage),
          reason:
              '$key uses different placeholders in '
              'app_${locale.languageCode}.arb',
        );
      }
    }
  });

  test('no message is left as an empty string', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final arb = readArb('app_${locale.languageCode}.arb');
      for (final key in messageKeys(arb)) {
        expect(
          (arb[key] as String).trim(),
          isNotEmpty,
          reason: '$key is empty in app_${locale.languageCode}.arb',
        );
      }
    }
  });
}
