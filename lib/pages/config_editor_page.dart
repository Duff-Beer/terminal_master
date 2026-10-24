import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/error_presenter.dart';
import '../models/config_editor_document.dart';
import '../services/config_editor_file_service.dart';

class ConfigEditorPage extends StatefulWidget {
  final String directoryPath;
  final String? filePath;
  final ConfigEditorFileService fileService;

  const ConfigEditorPage({
    super.key,
    required this.directoryPath,
    this.filePath,
    this.fileService = const ConfigEditorFileService(),
  });

  @override
  State<ConfigEditorPage> createState() => _ConfigEditorPageState();
}

class _ConfigEditorPageState extends State<ConfigEditorPage> {
  late final Future<void> _loading;
  ConfigEditorDocument? _document;
  String? _error;
  String? _filePath;
  bool _saving = false;
  bool _dirty = false;
  Map<String, Object?>? _expandedParameter;
  int _nextParameterId = 0;

  static const _types = [
    'text',
    'options',
    'boolean',
    'filepath',
    'text_list',
    'button',
  ];

  @override
  void initState() {
    super.initState();
    _filePath = widget.filePath;
    _loading = _load();
  }

  Future<void> _load() async {
    if (widget.filePath == null) {
      _document = ConfigEditorDocument.empty();
      return;
    }
    try {
      _document = await widget.fileService.load(widget.filePath!);
      _nextParameterId = _document!.parameters.length;
    } on Object catch (error) {
      _error = '$error';
    }
  }

  void _changed() {
    setState(() => _dirty = true);
  }

  Future<void> _save() async {
    final document = _document;
    if (document == null || _saving) return;
    setState(() => _saving = true);
    try {
      var path = _filePath;
      path ??= await widget.fileService.createPath(
        widget.directoryPath,
        document.command,
      );
      await widget.fileService.save(path, document);
      if (!mounted) return;
      setState(() {
        _filePath = path;
        _dirty = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).configEditorSaved)),
      );
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context, true);
    } on Object catch (error) {
      if (!mounted) return;
      final message = error is FormatException
          ? localizeError(AppLocalizations.of(context), error)
          : '$error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).configEditorSaveFailed(message),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope<void>(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmDiscard();
      },
      child: FutureBuilder<void>(
        future: _loading,
        builder: (context, snapshot) {
          final document = _document;
          return Scaffold(
            appBar: AppBar(
              title: Text(
                widget.filePath == null
                    ? l10n.configEditorNew
                    : l10n.configEditorEdit,
              ),
              actions: [
                IconButton(
                  key: const Key('save-config-editor'),
                  tooltip: l10n.configEditorSave,
                  onPressed: document == null || _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                ),
              ],
            ),
            body: snapshot.connectionState != ConnectionState.done
                ? const Center(child: CircularProgressIndicator())
                : document == null
                ? Center(child: Text(_error ?? l10n.configEditorInvalid))
                : _buildEditor(document, l10n),
          );
        },
      ),
    );
  }

  Future<void> _confirmDiscard() async {
    final l10n = AppLocalizations.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.configEditorDiscardTitle),
        content: Text(l10n.configEditorDiscardMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.configEditorDiscard),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      setState(() => _dirty = false);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context);
    }
  }

  Widget _buildEditor(ConfigEditorDocument document, AppLocalizations l10n) {
    return ListView(
      key: const Key('config-editor-form'),
      padding: const EdgeInsets.all(16),
      children: [
        _textField(
          label: l10n.configEditorCommand,
          value: document.data['command'],
          key: const Key('config-editor-command'),
          onChanged: (value) {
            document.command = value;
            _changed();
          },
        ),
        _textField(
          label: l10n.configEditorDisplayName,
          value: document.data['display_name'],
          key: const Key('config-editor-display-name'),
          onChanged: (value) =>
              _setOptionalText(document.data, 'display_name', value),
        ),
        _textField(
          label: l10n.configEditorDescription,
          value: document.data['description'],
          key: const Key('config-editor-description'),
          maxLines: 3,
          onChanged: (value) =>
              _setOptionalText(document.data, 'description', value),
        ),
        _textField(
          label: l10n.configEditorHelpText,
          value: document.data['help_text'],
          key: const Key('config-editor-help-text'),
          maxLines: 4,
          onChanged: (value) =>
              _setOptionalText(document.data, 'help_text', value),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.configEditorParameters,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            FilledButton.tonalIcon(
              key: const Key('add-config-editor-parameter'),
              onPressed: () {
                var name = 'parameter_${_nextParameterId++}';
                while (document.parameters.any(
                  (parameter) => parameter['name'] == name,
                )) {
                  name = 'parameter_${_nextParameterId++}';
                }
                final parameter = <String, Object?>{
                  'name': name,
                  'type': 'text',
                };
                setState(() {
                  document.parameters.add(parameter);
                  _expandedParameter = parameter;
                  _dirty = true;
                });
              },
              icon: const Icon(Icons.add),
              label: Text(l10n.configEditorAddParameter),
            ),
          ],
        ),
        if (document.parameters.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(l10n.configEditorNoParameters),
          )
        else
          ReorderableListView.builder(
            key: const Key('config-editor-parameter-list'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: document.parameters.length,
            onReorderItem: (oldIndex, newIndex) {
              setState(() {
                final item = document.parameters.removeAt(oldIndex);
                document.parameters.insert(newIndex, item);
                for (
                  var order = 0;
                  order < document.parameters.length;
                  order++
                ) {
                  final parameter = document.parameters[order];
                  if (parameter['order'] == 0 &&
                      (parameter['placement'] == null ||
                          parameter['placement'] == 'automatic') &&
                      parameter['flag'] != 'sudo') {
                    parameter['placement'] = 'before_command';
                  }
                  parameter['order'] = order + 1;
                }
                _dirty = true;
              });
            },
            itemBuilder: (context, index) {
              final parameter = document.parameters[index];
              return _parameterCard(
                document,
                parameter,
                index,
                l10n,
                key: ObjectKey(parameter),
              );
            },
          ),
        const SizedBox(height: 28),
        FilledButton.icon(
          key: const Key('config-editor-save-button'),
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.save_outlined),
          label: Text(l10n.configEditorSave),
        ),
      ],
    );
  }

  Widget _parameterCard(
    ConfigEditorDocument document,
    Map<String, Object?> parameter,
    int index,
    AppLocalizations l10n, {
    required Key key,
  }) {
    final type = _types.contains(parameter['type'])
        ? parameter['type'] as String
        : 'text';
    return Card(
      key: key,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ExpansionTile(
        initiallyExpanded: identical(parameter, _expandedParameter),
        leading: ReorderableDragStartListener(
          index: index,
          child: const Icon(Icons.drag_handle),
        ),
        title: Text(
          (parameter['name'] as String?)?.isNotEmpty == true
              ? parameter['name']! as String
              : l10n.configEditorElementName,
        ),
        subtitle: Text(_typeName(type, l10n)),
        trailing: IconButton(
          tooltip: l10n.configEditorDeleteElement,
          onPressed: () => setState(() {
            document.parameters.removeAt(index);
            _dirty = true;
          }),
          icon: const Icon(Icons.delete_outline),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                _textField(
                  label: l10n.configEditorElementName,
                  value: parameter['name'],
                  onChanged: (value) =>
                      _renameParameter(document, parameter, value),
                ),
                DropdownButtonFormField<String>(
                  key: ValueKey('type-${identityHashCode(parameter)}'),
                  initialValue: type,
                  decoration: InputDecoration(
                    labelText: l10n.configEditorElementType,
                  ),
                  items: _types
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_typeName(value, l10n)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      parameter['type'] = value;
                      if (value != 'options') parameter.remove('options');
                      if (value != 'filepath') parameter.remove('mode');
                      if (value != 'button') {
                        parameter.remove('executable');
                        parameter.remove('args');
                      }
                      final defaultValue = parameter['default'];
                      if ((value == 'boolean' && defaultValue is! bool) ||
                          (value == 'text_list' && defaultValue is! List) ||
                          (value != 'boolean' &&
                              value != 'text_list' &&
                              defaultValue is! String)) {
                        parameter.remove('default');
                      }
                      _dirty = true;
                    });
                  },
                ),
                _textField(
                  label: l10n.configEditorDescription,
                  value: parameter['description'],
                  maxLines: 2,
                  onChanged: (value) =>
                      _setOptionalText(parameter, 'description', value),
                ),
                _textField(
                  label: l10n.configEditorFlag,
                  value: parameter['flag'],
                  onChanged: (value) =>
                      _setOptionalText(parameter, 'flag', value),
                ),
                if (type == 'boolean')
                  DropdownButtonFormField<String>(
                    initialValue: parameter['default'] == true
                        ? 'true'
                        : parameter['default'] == false
                        ? 'false'
                        : 'none',
                    decoration: InputDecoration(
                      labelText: l10n.configEditorDefault,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'none',
                        child: Text(l10n.configEditorAutomatic),
                      ),
                      const DropdownMenuItem(
                        value: 'true',
                        child: Text('true'),
                      ),
                      const DropdownMenuItem(
                        value: 'false',
                        child: Text('false'),
                      ),
                    ],
                    onChanged: (value) => setState(() {
                      if (value == null || value == 'none') {
                        parameter.remove('default');
                      } else {
                        parameter['default'] = value == 'true';
                      }
                      _dirty = true;
                    }),
                  ),
                if (type != 'boolean' && type != 'button')
                  _textField(
                    label: l10n.configEditorDefault,
                    value: parameter['default'] is List
                        ? (parameter['default'] as List).join(', ')
                        : parameter['default'],
                    onChanged: (value) => _setDefault(parameter, type, value),
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.configEditorRequired),
                  value: parameter['required'] == true,
                  onChanged: (value) => setState(() {
                    parameter['required'] = value;
                    _dirty = true;
                  }),
                ),
                if (type == 'options') _optionsEditor(parameter, l10n),
                if (type == 'filepath') _fileModeEditor(parameter, l10n),
                if (type == 'button') ...[
                  _textField(
                    label: l10n.configEditorExecutable,
                    value: parameter['executable'],
                    onChanged: (value) =>
                        _setText(parameter, 'executable', value),
                  ),
                  _textField(
                    label: l10n.configEditorArguments,
                    value: parameter['args'] is List
                        ? (parameter['args'] as List).join(' ')
                        : parameter['args'],
                    onChanged: (value) => setState(() {
                      parameter['args'] = value
                          .split(RegExp(r'\s+'))
                          .where((part) => part.isNotEmpty)
                          .toList();
                      _dirty = true;
                    }),
                  ),
                ],
                _textField(
                  label: l10n.configEditorPrefix,
                  value: parameter['prefix'],
                  onChanged: (value) =>
                      _setOptionalText(parameter, 'prefix', value),
                ),
                _textField(
                  label: l10n.configEditorSuffix,
                  value: parameter['suffix'],
                  onChanged: (value) =>
                      _setOptionalText(parameter, 'suffix', value),
                ),
                _enumEditor(
                  label: l10n.configEditorPlacement,
                  value: parameter['placement']?.toString() ?? 'automatic',
                  options: const [
                    'automatic',
                    'before_command',
                    'argument',
                    'pipeline',
                  ],
                  labels: [
                    l10n.configEditorAutomatic,
                    l10n.configEditorBeforeCommand,
                    l10n.configEditorArgument,
                    l10n.configEditorPipeline,
                  ],
                  onChanged: (value) => _setOptionalText(
                    parameter,
                    'placement',
                    value == 'automatic' ? '' : value,
                  ),
                ),
                _enumEditor(
                  label: l10n.configEditorJoin,
                  value: parameter['join']?.toString() ?? 'automatic',
                  options: const ['automatic', 'separated', 'attached'],
                  labels: [
                    l10n.configEditorAutomatic,
                    l10n.configEditorSeparated,
                    l10n.configEditorAttached,
                  ],
                  onChanged: (value) => _setOptionalText(
                    parameter,
                    'join',
                    value == 'automatic' ? '' : value,
                  ),
                ),
                _textField(
                  label: l10n.configEditorLabel,
                  value: parameter['label'],
                  onChanged: (value) =>
                      _setOptionalText(parameter, 'label', value),
                ),
                _textField(
                  label: l10n.configEditorExample,
                  value: parameter['example'],
                  onChanged: (value) =>
                      _setOptionalText(parameter, 'example', value),
                ),
                _textField(
                  label: l10n.configEditorNote,
                  value: parameter['note'],
                  onChanged: (value) =>
                      _setOptionalText(parameter, 'note', value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.configEditorMustDiffer),
                  value: parameter['must_differ'] == true,
                  onChanged: (value) => setState(() {
                    if (value) {
                      parameter['must_differ'] = true;
                    } else {
                      parameter.remove('must_differ');
                    }
                    _dirty = true;
                  }),
                ),
                _referenceChips(
                  document,
                  parameter,
                  'depends_on',
                  l10n.configEditorDependencies,
                  l10n,
                ),
                _referenceChips(
                  document,
                  parameter,
                  'conflicts_with',
                  l10n.configEditorConflicts,
                  l10n,
                ),
                _conditionEditor(
                  document,
                  parameter,
                  'visible_when',
                  l10n.configEditorVisibleWhen,
                  l10n,
                ),
                _conditionEditor(
                  document,
                  parameter,
                  'required_when',
                  l10n.configEditorRequiredWhen,
                  l10n,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _optionsEditor(Map<String, Object?> parameter, AppLocalizations l10n) {
    final options =
        (parameter['options'] as List?)
            ?.whereType<Map<String, Object?>>()
            .toList() ??
        <Map<String, Object?>>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(l10n.configEditorOptions),
        ),
        for (var index = 0; index < options.length; index++)
          Row(
            key: ObjectKey(options[index]),
            children: [
              Expanded(
                child: _textField(
                  label: l10n.configEditorOptionValue,
                  value: options[index]['value'],
                  onChanged: (value) =>
                      _setText(options[index], 'value', value),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _textField(
                  label: l10n.configEditorOptionDescription,
                  value: options[index]['description'],
                  onChanged: (value) =>
                      _setOptionalText(options[index], 'description', value),
                ),
              ),
              IconButton(
                tooltip: l10n.configEditorRemove,
                onPressed: () => setState(() {
                  options.removeAt(index);
                  parameter['options'] = options;
                  _dirty = true;
                }),
                icon: const Icon(Icons.remove_circle_outline),
              ),
            ],
          ),
        TextButton.icon(
          onPressed: () => setState(() {
            options.add({'value': ''});
            parameter['options'] = options;
            _dirty = true;
          }),
          icon: const Icon(Icons.add),
          label: Text(l10n.configEditorAddOption),
        ),
      ],
    );
  }

  Widget _fileModeEditor(
    Map<String, Object?> parameter,
    AppLocalizations l10n,
  ) {
    final value = switch (parameter['mode']) {
      'directory' => 'directory',
      'any' => 'any',
      _ => 'file',
    };
    return DropdownButtonFormField<String>(
      key: ValueKey('file-mode-${identityHashCode(parameter)}-$value'),
      initialValue: value,
      decoration: InputDecoration(labelText: l10n.configEditorMode),
      items: [
        DropdownMenuItem(value: 'file', child: Text(l10n.configEditorModeFile)),
        DropdownMenuItem(
          value: 'directory',
          child: Text(l10n.configEditorModeDirectory),
        ),
        DropdownMenuItem(value: 'any', child: Text(l10n.configEditorModeAny)),
      ],
      onChanged: (mode) => setState(() {
        parameter['mode'] = mode;
        _dirty = true;
      }),
    );
  }

  Widget _enumEditor({
    required String label,
    required String value,
    required List<String> options,
    required List<String> labels,
    required ValueChanged<String> onChanged,
  }) {
    final selected = options.contains(value) ? value : options.first;
    return DropdownButtonFormField<String>(
      key: ValueKey('$label-$selected'),
      initialValue: selected,
      decoration: InputDecoration(labelText: label),
      items: [
        for (var index = 0; index < options.length; index++)
          DropdownMenuItem(value: options[index], child: Text(labels[index])),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }

  Widget _referenceChips(
    ConfigEditorDocument document,
    Map<String, Object?> parameter,
    String key,
    String label,
    AppLocalizations l10n,
  ) {
    final names = document.parameters
        .map((candidate) => candidate['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty && name != parameter['name'])
        .toList();
    if (names.isEmpty) return const SizedBox.shrink();
    final selected = (parameter[key] as List?)?.cast<String>().toSet() ?? {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(alignment: Alignment.centerLeft, child: Text(label)),
        Wrap(
          spacing: 6,
          children: [
            for (final name in names)
              FilterChip(
                label: Text(name),
                selected: selected.contains(name),
                onSelected: (value) => setState(() {
                  if (value) {
                    selected.add(name);
                  } else {
                    selected.remove(name);
                  }
                  parameter[key] = selected.toList();
                  _dirty = true;
                }),
              ),
          ],
        ),
      ],
    );
  }

  Widget _conditionEditor(
    ConfigEditorDocument document,
    Map<String, Object?> parameter,
    String key,
    String label,
    AppLocalizations l10n,
  ) {
    final references = document.parameters
        .where((candidate) => candidate != parameter)
        .where(
          (candidate) => (candidate['name'] as String?)?.isNotEmpty == true,
        )
        .toList();
    if (references.isEmpty) return const SizedBox.shrink();
    final group = _readConditionGroup(parameter[key]);
    final conditions = group.$2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(alignment: Alignment.centerLeft, child: Text(label)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.configEditorMatchAny),
          value: group.$1,
          onChanged: (value) => setState(() {
            parameter[key] = {value ? 'any' : 'all': conditions};
            _dirty = true;
          }),
        ),
        for (var index = 0; index < conditions.length; index++)
          _conditionRow(parameter, key, conditions, index, references, l10n),
        TextButton.icon(
          key: Key('add-condition-$key-${parameter['name']}'),
          onPressed: () => setState(() {
            conditions.add({
              'parameter': references.first['name'],
              'active': true,
            });
            parameter[key] = {group.$1 ? 'any' : 'all': conditions};
            _dirty = true;
          }),
          icon: const Icon(Icons.add),
          label: Text(l10n.configEditorAddCondition),
        ),
      ],
    );
  }

  Widget _conditionRow(
    Map<String, Object?> owner,
    String field,
    List<Map<String, Object?>> conditions,
    int index,
    List<Map<String, Object?>> references,
    AppLocalizations l10n,
  ) {
    final condition = conditions[index];
    final selectedName = condition['parameter']?.toString();
    final ref = references.firstWhere(
      (candidate) => candidate['name'] == selectedName,
      orElse: () => references.first,
    );
    final parameterNames = references
        .map((candidate) => candidate['name'].toString())
        .toList();
    final selectedOperator = condition.containsKey('equals')
        ? 'equals'
        : condition.containsKey('in')
        ? 'in'
        : 'active';
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey(
                  'condition-param-${identityHashCode(condition)}-${ref['name']}',
                ),
                initialValue: ref['name'] as String,
                decoration: InputDecoration(
                  labelText: l10n.configEditorConditionParameter,
                ),
                items: parameterNames
                    .map(
                      (name) =>
                          DropdownMenuItem(value: name, child: Text(name)),
                    )
                    .toList(),
                onChanged: (name) => setState(() {
                  condition['parameter'] = name;
                  _writeConditionGroup(owner, field, conditions);
                  _dirty = true;
                }),
              ),
            ),
            IconButton(
              tooltip: l10n.configEditorRemove,
              onPressed: () => setState(() {
                conditions.removeAt(index);
                _writeConditionGroup(owner, field, conditions);
                _dirty = true;
              }),
              icon: const Icon(Icons.remove_circle_outline),
            ),
          ],
        ),
        DropdownButtonFormField<String>(
          key: ValueKey(
            'condition-operator-${identityHashCode(condition)}-$selectedOperator',
          ),
          initialValue: selectedOperator,
          decoration: InputDecoration(
            labelText: l10n.configEditorConditionOperator,
          ),
          items: [
            DropdownMenuItem(
              value: 'equals',
              child: Text(l10n.configEditorConditionEquals),
            ),
            DropdownMenuItem(
              value: 'in',
              child: Text(l10n.configEditorConditionIn),
            ),
            DropdownMenuItem(
              value: 'active',
              child: Text(l10n.configEditorConditionActive),
            ),
          ],
          onChanged: (operator) => setState(() {
            condition.remove('equals');
            condition.remove('in');
            condition.remove('active');
            if (operator == 'equals') {
              condition['equals'] = _firstOptionValue(ref);
            } else if (operator == 'in') {
              condition['in'] = [_firstOptionValue(ref)];
            } else {
              condition['active'] = true;
            }
            _writeConditionGroup(owner, field, conditions);
            _dirty = true;
          }),
        ),
        if (selectedOperator == 'active')
          DropdownButtonFormField<bool>(
            key: ValueKey(
              'condition-active-${identityHashCode(condition)}-${condition['active']}',
            ),
            initialValue: condition['active'] == false ? false : true,
            decoration: InputDecoration(
              labelText: l10n.configEditorConditionValue,
            ),
            items: const [
              DropdownMenuItem(value: true, child: Text('true')),
              DropdownMenuItem(value: false, child: Text('false')),
            ],
            onChanged: (value) => setState(() {
              condition['active'] = value;
              _writeConditionGroup(owner, field, conditions);
              _dirty = true;
            }),
          )
        else if (selectedOperator != 'active')
          _textField(
            label: l10n.configEditorConditionValue,
            value: selectedOperator == 'equals'
                ? condition['equals']
                : (condition['in'] as List?)?.join(', '),
            onChanged: (value) => setState(() {
              final values = selectedOperator == 'equals'
                  ? [_typedConditionValue(ref, value)]
                  : value
                        .split(',')
                        .map((part) => _typedConditionValue(ref, part.trim()))
                        .toList();
              if (selectedOperator == 'equals') {
                condition['equals'] = values.first;
              } else {
                condition['in'] = values;
              }
              _writeConditionGroup(owner, field, conditions);
              _dirty = true;
            }),
          ),
      ],
    );
  }

  (bool, List<Map<String, Object?>>) _readConditionGroup(Object? value) {
    if (value is Map &&
        (value.containsKey('all') || value.containsKey('any'))) {
      final any = value.containsKey('any');
      final raw = value[any ? 'any' : 'all'];
      return (any, _conditionList(raw));
    }
    if (value is Map) return (false, [value.cast<String, Object?>()]);
    if (value is List) return (false, _conditionList(value));
    return (false, <Map<String, Object?>>[]);
  }

  List<Map<String, Object?>> _conditionList(Object? value) => value is List
      ? value.whereType<Map<String, Object?>>().toList()
      : value is Map
      ? [value.cast<String, Object?>()]
      : <Map<String, Object?>>[];

  void _writeConditionGroup(
    Map<String, Object?> owner,
    String field,
    List<Map<String, Object?>> conditions,
  ) {
    final current = _readConditionGroup(owner[field]);
    owner[field] = {current.$1 ? 'any' : 'all': conditions};
  }

  Object _firstOptionValue(Map<String, Object?> reference) {
    if (reference['type'] == 'boolean') return true;
    if (reference['type'] == 'options') {
      final options = reference['options'] as List? ?? [];
      if (options.isNotEmpty && options.first is Map) {
        return (options.first as Map)['value']?.toString() ?? '';
      }
    }
    return '';
  }

  Object _typedConditionValue(Map<String, Object?> reference, String value) =>
      reference['type'] == 'boolean' ? value.trim() == 'true' : value;

  Widget _textField({
    required String label,
    required Object? value,
    required ValueChanged<String> onChanged,
    Key? key,
    int maxLines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: TextFormField(
      key: key,
      initialValue: value?.toString() ?? '',
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: onChanged,
    ),
  );

  String _typeName(String type, AppLocalizations l10n) => switch (type) {
    'options' => l10n.configEditorTypeOptions,
    'boolean' => l10n.configEditorTypeBoolean,
    'filepath' => l10n.configEditorTypeFilepath,
    'text_list' => l10n.configEditorTypeTextList,
    'button' => l10n.configEditorTypeButton,
    _ => l10n.configEditorTypeText,
  };

  void _renameParameter(
    ConfigEditorDocument document,
    Map<String, Object?> parameter,
    String name,
  ) {
    final previous = parameter['name']?.toString();
    setState(() {
      parameter['name'] = name;
      if (previous != null && previous != name) {
        for (final candidate in document.parameters) {
          for (final field in ['depends_on', 'conflicts_with']) {
            final references = candidate[field];
            if (references is List) {
              candidate[field] = references
                  .map((reference) => reference == previous ? name : reference)
                  .toList();
            }
          }
          for (final field in ['visible_when', 'required_when']) {
            _replaceConditionReference(candidate[field], previous, name);
          }
        }
      }
      _dirty = true;
    });
  }

  void _replaceConditionReference(Object? value, String previous, String name) {
    if (value is Map) {
      if (value['parameter'] == previous) value['parameter'] = name;
      for (final key in ['all', 'any']) {
        if (value.containsKey(key)) {
          _replaceConditionReference(value[key], previous, name);
        }
      }
    } else if (value is List) {
      for (final condition in value) {
        _replaceConditionReference(condition, previous, name);
      }
    }
  }

  void _setText(Map<String, Object?> map, String key, String value) {
    setState(() {
      map[key] = value;
      _dirty = true;
    });
  }

  void _setOptionalText(Map<String, Object?> map, String key, String value) {
    setState(() {
      if (value.isEmpty) {
        map.remove(key);
      } else {
        map[key] = value;
      }
      _dirty = true;
    });
  }

  void _setDefault(Map<String, Object?> parameter, String type, String value) {
    setState(() {
      if (value.isEmpty) {
        parameter.remove('default');
      } else if (type == 'text_list') {
        parameter['default'] = value
            .split(',')
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .toList();
      } else {
        parameter['default'] = value;
      }
      _dirty = true;
    });
  }
}
