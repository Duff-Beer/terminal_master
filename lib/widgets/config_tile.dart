import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../l10n/error_presenter.dart';
import '../models/config_item.dart';

class ConfigTile extends StatelessWidget {
  final ConfigItem item;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  const ConfigTile({
    super.key,
    required this.item,
    required this.onTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final error = item.error;
    final errorColor = Theme.of(context).colorScheme.error;
    return ListTile(
      leading: error == null
          ? null
          : Icon(Icons.error_outline, color: errorColor),
      title: Text(
        error == null ? item.command : l10n.configItemLoadError(item.command),
        style: error == null ? null : TextStyle(color: errorColor),
      ),
      subtitle: Text(_subtitle(l10n)),
      trailing: onEdit == null
          ? null
          : IconButton(
              tooltip: l10n.configEditorEdit,
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
      onTap: onTap,
    );
  }

  String _subtitle(AppLocalizations l10n) {
    if (item.error case final error?) return localizeError(l10n, error);
    if (item.batchCommandCount case final count?) {
      return l10n.configItemBatchCommands(count);
    }
    return item.description ?? l10n.configItemNoDescription;
  }
}
