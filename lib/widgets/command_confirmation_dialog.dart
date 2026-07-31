import 'package:flutter/material.dart';

import '../services/command_risk_assessor.dart';

Future<bool> showCommandConfirmationDialog(
  BuildContext context, {
  required List<String> commands,
  required CommandRiskAssessment assessment,
}) async {
  var acknowledged = false;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        final colors = Theme.of(context).colorScheme;
        final isDestructive = assessment.level == CommandRiskLevel.destructive;
        final warningColor = isDestructive ? colors.error : colors.tertiary;

        return AlertDialog(
          icon: Icon(
            isDestructive ? Icons.warning_amber_rounded : Icons.terminal,
            color: assessment.level == CommandRiskLevel.standard
                ? colors.primary
                : warningColor,
          ),
          title: Text(switch (assessment.level) {
            CommandRiskLevel.standard => 'Kommando prüfen',
            CommandRiskLevel.elevated => 'Erhöhte Rechte bestätigen',
            CommandRiskLevel.destructive => 'Destruktives Kommando bestätigen',
          }),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (assessment.containsRawConfiguration)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Diese Befehle stammen direkt aus einer YAML-Datei. '
                        'Führe sie nur aus, wenn du die Datei und ihren Inhalt vertraust.',
                      ),
                    ),
                  if (assessment.reasons.isNotEmpty) ...[
                    for (final reason in assessment.reasons)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 18,
                              color: warningColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(reason)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    commands.length == 1
                        ? 'Auszuführendes Kommando'
                        : 'Auszuführende Kommandos',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 260),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        commands.join('\n\n'),
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                  ),
                  if (assessment.requiresAcknowledgement) ...[
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      key: const Key('command-risk-acknowledgement'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'Ich habe das Kommando geprüft und verstehe das Risiko.',
                      ),
                      value: acknowledged,
                      onChanged: (value) =>
                          setDialogState(() => acknowledged = value ?? false),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              key: const Key('confirm-command-execution'),
              style: isDestructive
                  ? FilledButton.styleFrom(backgroundColor: colors.error)
                  : null,
              onPressed: assessment.requiresAcknowledgement && !acknowledged
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Ausführen'),
            ),
          ],
        );
      },
    ),
  );
  return result ?? false;
}
