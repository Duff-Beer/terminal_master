import 'package:flutter/material.dart';
import '../models/config_item.dart';

class ConfigTile extends StatelessWidget {
  final ConfigItem item;
  final VoidCallback onTap;

  const ConfigTile({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(item.command),
      subtitle: Text(item.description),
      onTap: onTap,
    );
  }
}
