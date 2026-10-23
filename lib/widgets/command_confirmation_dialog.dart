import 'package:flutter/material.dart';

import '../services/command_risk_assessor.dart';
import '../l10n/app_localizations.dart';
import '../l10n/error_presenter.dart';

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
        final l10n = AppLocalizations.of(context);
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
            CommandRiskLevel.standard => l10n.confirmTitleStandard,
            CommandRiskLevel.elevated => l10n.confirmTitleElevated,
            CommandRiskLevel.destructive => l10n.confirmTitleDestructive,
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
                      child: Text(l10n.confirmRawConfigWarning),
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
                            Expanded(
                              child: Text(localizeRiskReason(l10n, reason)),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    l10n.confirmCommandsLabel(commands.length),
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
                      title: Text(l10n.confirmAcknowledgement),
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
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              key: const Key('confirm-command-execution'),
              style: isDestructive
                  ? FilledButton.styleFrom(backgroundColor: colors.error)
                  : null,
              onPressed: assessment.requiresAcknowledgement && !acknowledged
                  ? null
                  : () => Navigator.pop(context, true),
              child: Text(l10n.confirmRun),
            ),
          ],
        );
      },
    ),
  );
  return result ?? false;
}
