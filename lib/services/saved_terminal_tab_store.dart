import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/saved_terminal_tab.dart';

abstract interface class SavedTerminalTabStore {
  Future<List<SavedTerminalTab>> load();

  Future<void> save(List<SavedTerminalTab> tabs);
}

class MemorySavedTerminalTabStore implements SavedTerminalTabStore {
  List<SavedTerminalTab> _tabs;

  MemorySavedTerminalTabStore([List<SavedTerminalTab> tabs = const []])
    : _tabs = List.of(tabs);

  @override
  Future<List<SavedTerminalTab>> load() async => List.unmodifiable(_tabs);

  @override
  Future<void> save(List<SavedTerminalTab> tabs) async {
    _tabs = List.of(tabs);
  }
}

class FileSavedTerminalTabStore implements SavedTerminalTabStore {
  static const fileName = 'saved_terminal_tabs.json';
  static const _version = 1;

  final Directory directory;
  Future<void> _writeOperation = Future.value();
  final List<Object?> _unparsedTabs = [];

  FileSavedTerminalTabStore(this.directory);

  File get _file => File('${directory.path}${Platform.pathSeparator}$fileName');

  @override
  Future<List<SavedTerminalTab>> load() async {
    final file = _file;
    final backup = File('${file.path}.bak');
    final temporary = File('${file.path}.tmp');
    if (!await file.exists()) {
      if (await backup.exists()) {
        await backup.rename(file.path);
      } else if (await temporary.exists()) {
        await temporary.rename(file.path);
      } else {
        return const [];
      }
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, Object?> || decoded['version'] != _version) {
      throw const FormatException('Unbekanntes Snapshot-Format.');
    }
    final tabs = <SavedTerminalTab>[];
    _unparsedTabs.clear();
    for (final value in (decoded['tabs'] as List<Object?>? ?? const [])) {
      if (value case final Map<String, Object?> tabJson) {
        try {
          tabs.add(SavedTerminalTab.fromJson(tabJson));
        } on Object {
          _unparsedTabs.add(value);
        }
      } else {
        _unparsedTabs.add(value);
      }
    }
    tabs.sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return List.unmodifiable(tabs);
  }

  @override
  Future<void> save(List<SavedTerminalTab> tabs) {
    final snapshot = List<SavedTerminalTab>.of(tabs);
    final result = Completer<void>();
    _writeOperation = _writeOperation.then((_) async {
      try {
        await _save(snapshot);
        result.complete();
      } on Object catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  Future<void> _save(List<SavedTerminalTab> tabs) async {
    await directory.create(recursive: true);
    final file = _file;
    final temporary = File('${file.path}.tmp');
    final backup = File('${file.path}.bak');
    final content = const JsonEncoder.withIndent('  ').convert({
      'version': _version,
      'tabs': [...tabs.map((tab) => tab.toJson()), ..._unparsedTabs],
    });
    await temporary.writeAsString(content, flush: true);
    if (!await file.exists()) {
      await temporary.rename(file.path);
      return;
    }
    if (await backup.exists()) await backup.delete();
    await file.rename(backup.path);
    try {
      await temporary.rename(file.path);
      await backup.delete();
    } on Object {
      if (!await file.exists() && await backup.exists()) {
        await backup.rename(file.path);
      }
      rethrow;
    }
  }
}
