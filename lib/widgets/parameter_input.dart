import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/command_config.dart';
import 'searchable_options_field.dart';

class ParameterInput extends StatefulWidget {
  final CommandParameter param;
  final Object? value;
  final ValueChanged<Object?> onChanged;
  final VoidCallback? onAction;
  final Future<CommandOption?> Function()? onAddOption;
  final bool required;

  const ParameterInput({
    super.key,
    required this.param,
    this.value,
    required this.onChanged,
    this.onAction,
    this.onAddOption,
    this.required = false,
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
        title: Text(_label(param.name)),
        subtitle: Text(param.description),
        value: widget.value as bool? ?? false,
        onChanged: widget.onChanged,
      ),
      CommandParameterType.options => SearchableOptionsField(
        label: _label(param.name),
        description: param.description,
        options: param.options,
        value: widget.value as String?,
        required: widget.required,
        onChanged: widget.onChanged,
        onAddOption: widget.onAddOption,
      ),
      CommandParameterType.button => ElevatedButton(
        onPressed: widget.onAction,
        child: Text(param.label ?? param.name),
      ),
      CommandParameterType.textList => _TextListInput(
        param: param,
        values: _listValues(widget.value),
        required: widget.required,
        onChanged: widget.onChanged,
      ),
      CommandParameterType.text => _textField(),
    };
  }

  TextField _textField() {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: _label(widget.param.name),
        hintText: widget.param.example ?? widget.param.description,
        helperText: widget.param.example == null
            ? null
            : widget.param.description,
      ),
      onChanged: widget.onChanged,
    );
  }

  String _label(String label) => widget.required ? '$label *' : label;

  List<String> _listValues(Object? value) {
    if (value is! Iterable) return const [];
    return value.map((entry) => entry.toString()).toList(growable: false);
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

class _TextListInput extends StatefulWidget {
  final CommandParameter param;
  final List<String> values;
  final bool required;
  final ValueChanged<Object?> onChanged;

  const _TextListInput({
    required this.param,
    required this.values,
    required this.required,
    required this.onChanged,
  });

  @override
  State<_TextListInput> createState() => _TextListInputState();
}

class _TextListInputState extends State<_TextListInput> {
  late List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = _createControllers(widget.values);
  }

  @override
  void didUpdateWidget(covariant _TextListInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentValues = _controllers
        .map((controller) => controller.text)
        .toList();
    final nextValues = widget.values.isEmpty ? const [''] : widget.values;
    if (!_listsEqual(currentValues, nextValues)) {
      for (final controller in _controllers) {
        controller.dispose();
      }
      _controllers = _createControllers(nextValues);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < _controllers.length; index++)
          Padding(
            key: ObjectKey(_controllers[index]),
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controllers[index],
                    decoration: InputDecoration(
                      labelText:
                          '${widget.param.name} ${index + 1}${widget.required ? ' *' : ''}',
                      hintText: widget.param.example,
                      helperText: index == 0 ? widget.param.description : null,
                    ),
                    onChanged: (_) => _notifyChanged(),
                  ),
                ),
                IconButton(
                  tooltip: 'Eintrag entfernen',
                  onPressed: _controllers.length == 1
                      ? null
                      : () => _remove(index),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: const Text('Weiteren Eintrag hinzufügen'),
          ),
        ),
      ],
    );
  }

  List<TextEditingController> _createControllers(List<String> values) {
    final initialValues = values.isEmpty ? const [''] : values;
    return initialValues
        .map((value) => TextEditingController(text: value))
        .toList();
  }

  void _add() {
    setState(() => _controllers.add(TextEditingController()));
    _notifyChanged();
  }

  void _remove(int index) {
    setState(() => _controllers.removeAt(index).dispose());
    _notifyChanged();
  }

  void _notifyChanged() {
    widget.onChanged(
      List<String>.unmodifiable(
        _controllers.map((controller) => controller.text),
      ),
    );
  }

  bool _listsEqual(List<String> first, List<String> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }
}
