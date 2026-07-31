import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/command_config.dart';

class ParameterInput extends StatefulWidget {
  final CommandParameter param;
  final Object? value;
  final ValueChanged<Object?> onChanged;
  final VoidCallback? onAction;

  const ParameterInput({
    super.key,
    required this.param,
    this.value,
    required this.onChanged,
    this.onAction,
  });

  @override
  State<ParameterInput> createState() => _ParameterInputState();
}

class _ParameterInputState extends State<ParameterInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant ParameterInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final text = widget.value?.toString() ?? '';
    if (_controller.text != text) {
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final param = widget.param;
    return switch (param.type) {
      CommandParameterType.filepath => Row(
        children: [
          Expanded(child: _textField()),
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: param.mode == FilePickerMode.directory
                ? 'Verzeichnis auswählen'
                : param.mode == FilePickerMode.any
                ? 'Datei oder Verzeichnis auswählen'
                : 'Datei auswählen',
            onPressed: _pickPath,
          ),
        ],
      ),
      CommandParameterType.boolean => SwitchListTile(
        title: Text(param.name),
        subtitle: Text(param.description),
        value: widget.value as bool? ?? false,
        onChanged: widget.onChanged,
      ),
      CommandParameterType.options => DropdownButtonFormField<String>(
        isExpanded: true,
        decoration: InputDecoration(
          labelText: param.name,
          helperText: param.description,
        ),
        initialValue: widget.value as String?,
        items: param.options
            .map(
              (option) => DropdownMenuItem(
                value: option.value,
                child: Text(
                  '${option.value}: ${option.description}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: widget.onChanged,
      ),
      CommandParameterType.button => ElevatedButton(
        onPressed: widget.onAction,
        child: Text(param.label ?? param.name),
      ),
      CommandParameterType.text => _textField(),
    };
  }

  TextField _textField() {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: widget.param.name,
        hintText: widget.param.example ?? widget.param.description,
        helperText: widget.param.example == null
            ? null
            : widget.param.description,
      ),
      onChanged: widget.onChanged,
    );
  }

  Future<void> _pickPath() async {
    String? path;
    if (widget.param.mode == FilePickerMode.directory) {
      path = await FilePicker.platform.getDirectoryPath();
    } else if (widget.param.mode == FilePickerMode.any) {
      final mode = await showModalBottomSheet<FilePickerMode>(
        context: context,
        builder: (context) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: const Text('Datei auswählen'),
                onTap: () => Navigator.pop(context, FilePickerMode.file),
              ),
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: const Text('Verzeichnis auswählen'),
                onTap: () => Navigator.pop(context, FilePickerMode.directory),
              ),
            ],
          ),
        ),
      );
      if (!mounted || mode == null) return;
      path = mode == FilePickerMode.directory
          ? await FilePicker.platform.getDirectoryPath()
          : (await FilePicker.platform.pickFiles())?.files.single.path;
    } else {
      path = (await FilePicker.platform.pickFiles())?.files.single.path;
    }
    if (mounted && path != null) widget.onChanged(path);
  }
}
