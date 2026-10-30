import 'dart:io';
import 'dart:convert';
import 'package:yaml/yaml.dart';

import '../models/shell_profile.dart';
import 'terminal_fonts.dart';

class SettingsLoader {
  /// Value stored in `settings.yaml` for "follow the operating system".
  static const String systemLanguage = 'system';

  /// Language codes the app ships translations for. Keep in sync with
  /// `AppLocalizations.supportedLocales` (lib/l10n/*.arb).
  static const List<String> supportedLanguageCodes = ['en', 'de'];

  static late String terminalCommand;
  static late String fileManagerCommand;
  static late String yamlDirectoryPath;
  static late List<ShellProfile> integratedTerminalProfiles;

  /// `null` means "follow the operating system locale".
  static late String? languageCode;
  static late bool commandBarPinned;
  static late String terminalFontFamily;

  static const terminalFontFamilies = TerminalFonts.families;

  static Future<void> saveDefaultIntegratedTerminalProfile(
    String dirPath,
    String profileId,
  ) => _updateSettings(dirPath, (lines) {
    final sectionIndex = lines.indexWhere(
      (line) => RegExp(r'^integrated_terminal:\s*(?:#.*)?$').hasMatch(line),
    );
    final encodedId = jsonEncode(profileId);

    if (sectionIndex < 0) {
      if (lines.isNotEmpty && lines.last.isNotEmpty) lines.add('');
      lines
        ..add('integrated_terminal:')
        ..add('  default_profile: $encodedId');
      return;
    }
    var sectionEnd = lines.length;
    for (var index = sectionIndex + 1; index < lines.length; index++) {
      final line = lines[index];
      final trimmed = line.trimLeft();
      if (line.isNotEmpty && trimmed == line && !trimmed.startsWith('#')) {
        sectionEnd = index;
        break;
      }
    }
    final defaultIndex = lines.indexWhere(
      (line) => RegExp(r'^\s+default_profile\s*:').hasMatch(line),
      sectionIndex + 1,
    );
    if (defaultIndex >= sectionEnd || defaultIndex < 0) {
      lines.insert(sectionIndex + 1, '  default_profile: $encodedId');
    } else {
      final indent = RegExp(r'^\s*').firstMatch(lines[defaultIndex])![0]!;
      lines[defaultIndex] = '${indent}default_profile: $encodedId';
    }
  });

  /// Persists the UI language. Pass `null` to follow the operating system.
  static Future<void> saveLanguage(String dirPath, String? code) =>
      _updateSettings(dirPath, (lines) {
        final settingIndex = lines.indexWhere(
          (line) => RegExp(r'^language\s*:').hasMatch(line),
        );
        final setting = 'language: ${jsonEncode(code ?? systemLanguage)}';
        if (settingIndex < 0) {
          lines.insert(0, setting);
        } else {
          lines[settingIndex] = setting;
        }
      });

  static Future<void> saveTerminalFontFamily(
    String dirPath,
    String fontFamily,
  ) => _updateSettings(dirPath, (lines) {
    if (!terminalFontFamilies.contains(fontFamily)) {
      throw ArgumentError.value(fontFamily, 'fontFamily', 'Unsupported font.');
    }
    final setting = 'terminal_font_family: ${jsonEncode(fontFamily)}';
    final settingIndex = lines.indexWhere(
      (line) => RegExp(r'^terminal_font_family\s*:').hasMatch(line),
    );
    if (settingIndex < 0) {
      lines.add(setting);
    } else {
      lines[settingIndex] = setting;
    }
  });

  static Future<void> saveCommandBarPinned(String dirPath, bool pinned) =>
      _updateSettings(dirPath, (lines) {
        final setting = 'terminal_command_bar_pinned: $pinned';
        final settingIndex = lines.indexWhere(
          (line) => RegExp(r'^terminal_command_bar_pinned\s*:').hasMatch(line),
        );
        if (settingIndex < 0) {
          lines.add(setting);
        } else {
          lines[settingIndex] = setting;
        }
      });

  static Future<void> saveYamlDirectoryPath(String dirPath, String yamlPath) =>
      _updateSettings(dirPath, (lines) {
        final settingIndex = lines.indexWhere(
          (line) => RegExp(r'^yaml_directory\s*:').hasMatch(line),
        );
        final setting = 'yaml_directory: ${jsonEncode(yamlPath)}';
        if (settingIndex < 0) {
          lines.insert(0, setting);
        } else {
          lines[settingIndex] = setting;
        }
      });

  static Future<void> _updateSettings(
    String dirPath,
    void Function(List<String> lines) update,
  ) async {
    final file = File('$dirPath/settings.yaml');
    final original = await file.exists() ? await file.readAsString() : '';
    final lines = const LineSplitter().convert(original);
    update(lines);

    final temporary = File('${file.path}.tmp');
    final backup = File('${file.path}.bak');
    await temporary.writeAsString('${lines.join('\n')}\n', flush: true);
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

  static void initialize(String dirPath) {
    final file = File('$dirPath/settings.yaml');
    final defaults = _defaultValues();
    final defaultProfiles = ShellProfile.platformDefaults();

    if (!file.existsSync()) {
      file.writeAsStringSync(
        'terminal: ${defaults['terminal']}\nfile_manager: ${defaults['file_manager']}\n',
      );
      terminalCommand = defaults['terminal']!;
      fileManagerCommand = defaults['file_manager']!;
      yamlDirectoryPath = dirPath;
      integratedTerminalProfiles = defaultProfiles;
      languageCode = null;
      commandBarPinned = false;
      terminalFontFamily = TerminalFonts.defaultFamily;
      return;
    }

    final doc = loadYaml(file.readAsStringSync());
    languageCode = _loadLanguage(doc['language']);
    commandBarPinned = doc['terminal_command_bar_pinned'] == true;
    terminalFontFamily = _loadTerminalFontFamily(doc['terminal_font_family']);
    terminalCommand = doc['terminal']?.toString() ?? defaults['terminal']!;
    fileManagerCommand =
        doc['file_manager']?.toString() ?? defaults['file_manager']!;
    yamlDirectoryPath = doc['yaml_directory'] == null
        ? dirPath
        : _expandHome(doc['yaml_directory'].toString());
    integratedTerminalProfiles = _loadProfiles(
      doc['integrated_terminal'],
      defaultProfiles,
    );
  }

  /// An unknown or absent value (e.g. a formerly supported system font) falls
  /// back to the bundled default font rather than failing startup.
  static String _loadTerminalFontFamily(Object? configuration) {
    final fontFamily = configuration?.toString().trim();
    return terminalFontFamilies.contains(fontFamily)
        ? fontFamily!
        : TerminalFonts.defaultFamily;
  }

  static String? _loadLanguage(Object? configuration) {
    final code = configuration?.toString().trim();
    if (code == null || code.isEmpty || code == systemLanguage) return null;
    return supportedLanguageCodes.contains(code) ? code : null;
  }

  static List<ShellProfile> _loadProfiles(
    Object? configuration,
    List<ShellProfile> defaults,
  ) {
    if (configuration == null) return defaults;
    if (configuration is! YamlMap) {
      throw const FormatException('integrated_terminal muss eine Map sein.');
    }
    final entries = configuration['profiles'];
    if (entries == null) {
      return _withDefaultProfile(defaults, configuration['default_profile']);
    }
    if (entries is! YamlList || entries.isEmpty) {
      throw const FormatException(
        'integrated_terminal.profiles muss eine nicht leere Liste sein.',
      );
    }

    final profiles = <ShellProfile>[];
    final ids = <String>{};
    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      if (entry is! YamlMap) {
        throw FormatException(
          'Terminal-Profil ${index + 1} muss eine Map sein.',
        );
      }
      final id = _requiredString(entry, 'id', index);
      final name = entry['name']?.toString().trim();
      final executable = _requiredString(entry, 'executable', index);
      if (!ids.add(id)) {
        throw FormatException('Doppelte Terminal-Profil-ID: $id');
      }
      final argumentsNode = entry['arguments'];
      if (argumentsNode != null && argumentsNode is! YamlList) {
        throw FormatException('$id.arguments muss eine Liste sein.');
      }
      final environmentNode = entry['environment'];
      if (environmentNode != null && environmentNode is! YamlMap) {
        throw FormatException('$id.environment muss eine Map sein.');
      }
      final dialect = switch (entry['dialect']?.toString() ?? 'posix') {
        'posix' => ShellDialect.posix,
        'windows_cmd' => ShellDialect.windowsCmd,
        'powershell' => ShellDialect.powerShell,
        final value => throw FormatException(
          'Unbekannter Shell-Dialekt für $id: $value',
        ),
      };
      profiles.add(
        ShellProfile(
          id: id,
          name: name == null || name.isEmpty ? id : name,
          executable: _expandHome(executable),
          arguments: argumentsNode == null
              ? const []
              : argumentsNode.map<String>((value) => value.toString()).toList(),
          workingDirectory: entry['working_directory'] == null
              ? null
              : _expandHome(entry['working_directory'].toString()),
          environment: environmentNode == null
              ? const {}
              : {
                  for (final key in environmentNode.keys)
                    key.toString(): environmentNode[key].toString(),
                },
          dialect: dialect,
        ),
      );
    }

    return _withDefaultProfile(profiles, configuration['default_profile']);
  }

  static List<ShellProfile> _withDefaultProfile(
    List<ShellProfile> profiles,
    Object? configuredId,
  ) {
    final defaultId = configuredId?.toString();
    if (defaultId == null) return profiles;
    final defaultIndex = profiles.indexWhere(
      (profile) => profile.id == defaultId,
    );
    if (defaultIndex < 0) {
      throw FormatException('Unbekanntes Standardprofil: $defaultId');
    }
    return [
      profiles[defaultIndex],
      ...profiles.where((p) => p.id != defaultId),
    ];
  }

  static String _requiredString(YamlMap entry, String key, int index) {
    final value = entry[key]?.toString().trim();
    if (value == null || value.isEmpty) {
      throw FormatException('Terminal-Profil ${index + 1} benötigt "$key".');
    }
    return value;
  }

  static String _expandHome(String value) {
    if (value == '~' || value.startsWith('~/') || value.startsWith('~\\')) {
      final home =
          Platform.environment[Platform.isWindows ? 'USERPROFILE' : 'HOME'];
      if (home != null) return '$home${value.substring(1)}';
    }
    return value;
  }

  static Map<String, String> _defaultValues() {
    if (Platform.isWindows) {
      return {'terminal': 'cmd.exe', 'file_manager': 'explorer'};
    } else if (Platform.isMacOS) {
      return {'terminal': 'Terminal', 'file_manager': 'open'};
    } else {
      return {'terminal': 'gnome-terminal', 'file_manager': 'xdg-open'};
    }
  }
}
