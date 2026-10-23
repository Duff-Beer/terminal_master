import 'package:flutter/material.dart';
import 'package:terminal_master/l10n/app_localizations.dart';

/// A [MaterialApp] wired up with the app's localization delegates and a pinned
/// locale.
///
/// Widget tests must not inherit the host machine's system locale: the
/// expectations in this suite are written against one language, so the locale
/// is fixed here rather than resolved from the platform. German is the default
/// because the suite predates localization and its expectations are German.
MaterialApp localizedApp({
  required Widget home,
  GlobalKey<NavigatorState>? navigatorKey,
  String languageCode = 'de',
}) => MaterialApp(
  navigatorKey: navigatorKey,
  locale: Locale(languageCode),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);
