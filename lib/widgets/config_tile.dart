import 'package:flutter/material.dart';
import '../models/config_item.dart';

class ConfigTile extends StatelessWidget {
  final ConfigItem item;
  final VoidCallback onTap;

  const ConfigTile({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: item.error == null
          ? null
          : Icon(Icons.error_outline,
              color: Theme.of(context).colorScheme.error),
      title: Text(
        item.command,
        style: item.error == null
            ? null
            : TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      subtitle: Text(item.description),
      onTap: onTap,
    );
  }
}
