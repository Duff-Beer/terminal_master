import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

void showOutputDialog(BuildContext context, String output) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(AppLocalizations.of(dialogContext).outputTitle),
      content: SingleChildScrollView(child: Text(output)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(AppLocalizations.of(dialogContext).commonClose),
        ),
      ],
    ),
  );
}
