import 'package:flutter/material.dart';

void showOutputDialog(BuildContext context, String output) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Command Output'),
      content: SingleChildScrollView(child: Text(output)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Schließen'),
        ),
      ],
    ),
  );
}
