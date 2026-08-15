import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/command_config.dart';

class SearchableOptionsField extends StatelessWidget {
  final String label;
  final String description;
  final List<CommandOption> options;
  final String? value;
  final bool required;
  final ValueChanged<String?> onChanged;
  final Future<CommandOption?> Function()? onAddOption;
  final Future<bool> Function(CommandOption option)? onDeleteOption;

  const SearchableOptionsField({
    super.key,
    required this.label,
    required this.description,
    required this.options,
    required this.value,
    required this.required,
    required this.onChanged,
    this.onAddOption,
    this.onDeleteOption,
  });

  @override
  Widget build(BuildContext context) {
    final selected = options
        .where((option) => option.value == value)
        .firstOrNull;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        key: Key('searchable-options-field-$label'),
        borderRadius: BorderRadius.circular(4),
        onTap: () => _showOptions(context),
        child: InputDecorator(
          isEmpty: false,
          decoration: InputDecoration(
            labelText: label,
            helperText: description,
            suffixIcon: const Icon(Icons.arrow_drop_down),
          ),
          child: Text(
            selected == null
                ? required
                      ? 'Bitte auswählen'
                      : 'Nicht verwenden'
                : '${selected.value}: ${selected.description}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: selected == null
                ? TextStyle(color: Theme.of(context).hintColor)
                : null,
          ),
        ),
      ),
    );
  }

  Future<void> _showOptions(BuildContext context) async {
    final result = await showDialog<_OptionSelection>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SearchableOptionsDialog(
        title: label,
        options: options,
        selectedValue: value,
        required: required,
        onAddOption: onAddOption,
        onDeleteOption: onDeleteOption,
        onSelectedOptionDeleted: () => onChanged(null),
      ),
    );
    if (!context.mounted || result == null) return;
    onChanged(result.value);
  }
}

class _OptionSelection {
  final String? value;

  const _OptionSelection(this.value);
}

class _SearchableOptionsDialog extends StatefulWidget {
  final String title;
  final List<CommandOption> options;
  final String? selectedValue;
  final bool required;
  final Future<CommandOption?> Function()? onAddOption;
  final Future<bool> Function(CommandOption option)? onDeleteOption;
  final VoidCallback onSelectedOptionDeleted;

  const _SearchableOptionsDialog({
    required this.title,
    required this.options,
    required this.selectedValue,
    required this.required,
    this.onAddOption,
    this.onDeleteOption,
    required this.onSelectedOptionDeleted,
  });

  @override
  State<_SearchableOptionsDialog> createState() =>
      _SearchableOptionsDialogState();
}

class _SearchableOptionsDialogState extends State<_SearchableOptionsDialog> {
  final _searchController = TextEditingController();
  late final FocusNode _searchFocusNode;
  var _query = '';
  var _highlightedIndex = 0;
  var _isMutating = false;
  late final List<CommandOption> _options;
  String? _selectedValue;

  List<CommandOption> get _filteredOptions {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _options;
    return _options
        .where(
          (option) =>
              option.value.toLowerCase().contains(query) ||
              option.description.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  int get _selectionCount =>
      _filteredOptions.length + (widget.required ? 0 : 1);

  @override
  void initState() {
    super.initState();
    _options = List.of(widget.options);
    _selectedValue = widget.selectedValue;
    _searchFocusNode = FocusNode(onKeyEvent: _handleSearchKeyEvent);
    final selectedIndex = _options.indexWhere(
      (option) => option.value == _selectedValue,
    );
    _highlightedIndex = widget.required
        ? selectedIndex.clamp(0, _options.length - 1)
        : selectedIndex + 1;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = _filteredOptions;
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowDown): _MoveSelectionIntent(1),
        SingleActivator(LogicalKeyboardKey.arrowUp): _MoveSelectionIntent(-1),
        SingleActivator(LogicalKeyboardKey.enter): _AcceptSelectionIntent(),
        SingleActivator(LogicalKeyboardKey.escape): _CancelSelectionIntent(),
      },
      child: Actions(
        actions: {
          _MoveSelectionIntent: CallbackAction<_MoveSelectionIntent>(
            onInvoke: (intent) {
              _moveSelection(intent.offset);
              return null;
            },
          ),
          _AcceptSelectionIntent: CallbackAction<_AcceptSelectionIntent>(
            onInvoke: (_) {
              _acceptSelection();
              return null;
            },
          ),
          _CancelSelectionIntent: CallbackAction<_CancelSelectionIntent>(
            onInvoke: (_) {
              Navigator.pop(context);
              return null;
            },
          ),
        },
        child: AlertDialog(
          title: Text(widget.title),
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          content: SizedBox(
            width: 560,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    key: const Key('searchable-options-query'),
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    autofocus: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Wert oder Beschreibung durchsuchen',
                      isDense: true,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _query = value;
                        _highlightedIndex = 0;
                      });
                    },
                    onSubmitted: (_) => _acceptSelection(),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: _selectionCount == 0
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Text('Keine Treffer'),
                          )
                        : ListView.builder(
                            key: const Key('searchable-options-results'),
                            shrinkWrap: true,
                            itemCount:
                                _selectionCount +
                                (options.isEmpty && !widget.required ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (!widget.required && index == 0) {
                                return _optionTile(
                                  index: index,
                                  title: 'Nicht verwenden',
                                  selected: _selectedValue == null,
                                  onTap: () => Navigator.pop(
                                    context,
                                    const _OptionSelection(null),
                                  ),
                                );
                              }
                              if (options.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Center(child: Text('Keine Treffer')),
                                );
                              }
                              final option =
                                  options[index - (widget.required ? 0 : 1)];
                              return _optionTile(
                                index: index,
                                title: option.value,
                                subtitle: option.description,
                                selected: _selectedValue == option.value,
                                onTap: () => Navigator.pop(
                                  context,
                                  _OptionSelection(option.value),
                                ),
                                onDelete:
                                    widget.onDeleteOption == null ||
                                        _options.length == 1 ||
                                        _isMutating
                                    ? null
                                    : () => _confirmDeleteOption(option),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (widget.onAddOption != null)
              TextButton.icon(
                key: const Key('add-searchable-option'),
                onPressed: _isMutating ? null : _addOption,
                icon: const Icon(Icons.add),
                label: const Text('Eintrag hinzufügen'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionTile({
    required int index,
    required String title,
    String? subtitle,
    required bool selected,
    required VoidCallback onTap,
    VoidCallback? onDelete,
  }) {
    return ListTile(
      key: Key('searchable-option-$title'),
      dense: true,
      selected: index == _highlightedIndex,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        size: 18,
      ),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: onDelete == null
          ? null
          : IconButton(
              key: Key('delete-searchable-option-$title'),
              tooltip: 'Eintrag löschen',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
      onTap: onTap,
    );
  }

  void _moveSelection(int offset) {
    final count = _selectionCount;
    if (count == 0) return;
    setState(() => _highlightedIndex = (_highlightedIndex + offset) % count);
  }

  KeyEventResult _handleSearchKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveSelection(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveSelection(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.pop(context);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _acceptSelection() {
    final options = _filteredOptions;
    if (_selectionCount == 0) return;
    if (!widget.required && _highlightedIndex == 0) {
      Navigator.pop(context, const _OptionSelection(null));
      return;
    }
    final option = options[_highlightedIndex - (widget.required ? 0 : 1)];
    Navigator.pop(context, _OptionSelection(option.value));
  }

  Future<void> _addOption() async {
    if (_isMutating) return;
    setState(() => _isMutating = true);
    final option = await widget.onAddOption?.call();
    if (!mounted) return;
    if (option == null) {
      setState(() => _isMutating = false);
      return;
    }
    Navigator.pop(context, _OptionSelection(option.value));
  }

  Future<void> _confirmDeleteOption(CommandOption option) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eintrag löschen?'),
        content: Text(
          'Soll „${option.value}“ dauerhaft aus der YAML-Datei gelöscht werden?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            key: const Key('confirm-delete-option'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isMutating = true);
    final deleted = await widget.onDeleteOption?.call(option) ?? false;
    if (!mounted) return;
    if (!deleted) {
      setState(() => _isMutating = false);
      return;
    }
    final selectedOptionDeleted = _selectedValue == option.value;
    setState(() {
      _options.removeWhere((candidate) => candidate.value == option.value);
      if (selectedOptionDeleted) _selectedValue = null;
      _highlightedIndex = _selectionCount == 0
          ? 0
          : _highlightedIndex.clamp(0, _selectionCount - 1);
      _isMutating = false;
    });
    if (selectedOptionDeleted) widget.onSelectedOptionDeleted();
  }
}

class _MoveSelectionIntent extends Intent {
  final int offset;

  const _MoveSelectionIntent(this.offset);
}

class _AcceptSelectionIntent extends Intent {
  const _AcceptSelectionIntent();
}

class _CancelSelectionIntent extends Intent {
  const _CancelSelectionIntent();
}
