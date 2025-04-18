import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/command_config.dart';

class ParameterInput extends StatelessWidget {
  final CommandParameter param;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  const ParameterInput({
    super.key,
    required this.param,
    this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    switch (param.type) {
      case 'filepath':
        return Row(
          children: [
            Expanded(
              child: TextField(
                controller: TextEditingController(text: value ?? ''),
                decoration: InputDecoration(
                  labelText: param.name,
                  hintText: param.description,
                ),
                onChanged: onChanged,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.folder_open),
              onPressed: () async {
                String? path;
                if (param.options?.first['mode'] == 'directory') {
                  path = await FilePicker.platform.getDirectoryPath();
                } else {
                  path = (await FilePicker.platform.pickFiles())
                      ?.files
                      .single
                      .path;
                }
                if (path != null) onChanged(path);
              },
            ),
          ],
        );
      case 'boolean':
        return SwitchListTile(
          title: Text(param.name),
          subtitle: Text(param.description),
          value: value ?? false,
          onChanged: onChanged,
        );
      case 'options':
        return DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: param.name,
            helperText: param.description,
          ),
          value: value,
          items: param.options!
              .map((o) => DropdownMenuItem(
                    value: o['value'],
                    child: Text('${o['value']}: ${o['description']}'),
                  ))
              .toList(),
          onChanged: onChanged,
        );
      case 'button':
        return ElevatedButton(
          onPressed: () => onChanged(null),
          child: Text(param.name),
        );
      default:
        return TextField(
          decoration: InputDecoration(
            labelText: param.name,
            hintText: param.description,
          ),
          onChanged: onChanged,
        );
    }
  }
}
