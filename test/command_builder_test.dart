import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/services/command_builder.dart';
import 'package:terminal_master/utils/config_loader.dart';

void main() {
  group('CommandBuilder', () {
    test('renders attached dd flags and defaults', () {
      final config = ConfigLoader.loadConfig('data/dd.yaml');
      final command = CommandBuilder(
        config: config,
        values: {
          ...config.defaultValues,
          'input_file': '/tmp/input image.img',
          'output_file': '/dev/disk2',
          'block_size': '4M',
          'conv': 'noerror',
        },
        shell: CommandShell.posix,
      ).build();

      expect(
        command,
        "dd 'if=/tmp/input image.img' of=/dev/disk2 bs=4M conv=noerror status=progress",
      );
    });

    test('quotes user input instead of interpreting shell syntax', () {
      final config = ConfigLoader.loadConfig('data/git_clone.yaml');
      final command = CommandBuilder(
        config: config,
        values: {
          ...config.defaultValues,
          'repository': 'repo; touch /tmp/injected',
          'depth': '1',
        },
        shell: CommandShell.posix,
      ).build();

      expect(command, "git clone 'repo; touch /tmp/injected' --depth 1");
    });

    test('renders configured multi-token options', () {
      final config = ConfigLoader.loadConfig('data/flutter.yaml');
      final command = CommandBuilder(
        config: config,
        values: {...config.defaultValues, 'action': 'pub get'},
        shell: CommandShell.posix,
      ).build();

      expect(command, 'flutter pub get');
    });

    test('renders structured pipeline after all arguments', () {
      final config = ConfigLoader.loadConfig('data/nmap.yaml');
      final command = CommandBuilder(
        config: config,
        values: {
          ...config.defaultValues,
          'target': '192.168.0.0/24',
          'filter_up': true,
        },
        shell: CommandShell.posix,
      ).build();

      expect(command, 'nmap 192.168.0.0/24 | grep Up');
    });

    test('treats false values as inactive for conflicts', () {
      final config = ConfigLoader.loadConfig('data/pishrink.yaml');
      final command = CommandBuilder(
        config: config,
        values: {
          ...config.defaultValues,
          'input_file': '/tmp/input.img',
          'output_file': '/tmp/output.img',
          'preserve_original': false,
        },
        shell: CommandShell.posix,
      ).build();

      expect(command, 'sudo pishrink /tmp/input.img --output /tmp/output.img');
    });

    test('rejects cmd expansion characters on Windows', () {
      final config = ConfigLoader.loadConfig('data/git_clone.yaml');

      expect(
        () => CommandBuilder(
          config: config,
          values: {'repository': r'%PATH%'},
          shell: CommandShell.windowsCmd,
        ).build(),
        throwsA(isA<CommandBuildException>()),
      );
    });

    test('escapes a trailing backslash in quoted Windows arguments', () {
      final config = ConfigLoader.loadConfig('data/git_clone.yaml');
      final command = CommandBuilder(
        config: config,
        values: {'repository': 'C:\\Program Files\\'},
        shell: CommandShell.windowsCmd,
      ).build();

      expect(command, r'git clone "C:\Program Files\\"');
    });

    test('validates required parameters', () {
      final config = ConfigLoader.loadConfig('data/dd.yaml');

      expect(
        () => CommandBuilder(
          config: config,
          values: config.defaultValues,
          shell: CommandShell.posix,
        ).build(),
        throwsA(
          isA<CommandBuildException>().having(
            (error) => error.message,
            'message',
            contains('input_file'),
          ),
        ),
      );
    });

    test('supports the pipeline syntax from previously installed configs', () {
      final directory = Directory.systemTemp.createTempSync('legacy-nmap-');
      final file = File('${directory.path}/legacy-nmap.yaml')
        ..writeAsStringSync('''
command: nmap
parameters:
  - name: target
    type: text
    required: true
    prefix: "- "
  - name: filter_up
    type: boolean
    flag: "| grep 'Up'"
''');
      addTearDown(() => directory.deleteSync(recursive: true));
      final config = ConfigLoader.loadConfig(file.path);
      final command = CommandBuilder(
        config: config,
        values: {'target': '192.168.0.0/24', 'filter_up': true},
        shell: CommandShell.posix,
      ).build();

      expect(command, 'nmap 192.168.0.0/24 | grep Up');
    });

    test('rejects canonically identical input and output paths', () {
      final directory = Directory.systemTemp.createTempSync('dd-paths-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final input = File('${directory.path}/input.img')..writeAsStringSync('x');
      final equivalentOutput = '${directory.path}/nested/../input.img';
      final config = ConfigLoader.loadConfig('data/dd.yaml');

      expect(
        () => CommandBuilder(
          config: config,
          values: {
            ...config.defaultValues,
            'input_file': input.path,
            'output_file': equivalentOutput,
          },
          shell: CommandShell.posix,
        ).build(),
        throwsA(
          isA<CommandBuildException>().having(
            (error) => error.message,
            'message',
            contains('unterscheiden'),
          ),
        ),
      );
    });

    test('protects legacy dd configs without a must_differ declaration', () {
      final directory = Directory.systemTemp.createTempSync('legacy-dd-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final configFile = File('${directory.path}/dd.yaml')
        ..writeAsStringSync('''
command: dd
parameters:
  - name: input_file
    type: filepath
    required: true
    flag: if=
  - name: output_file
    type: filepath
    required: true
    flag: of=
''');
      final config = ConfigLoader.loadConfig(configFile.path);

      expect(
        () => CommandBuilder(
          config: config,
          values: const {
            'input_file': '/tmp/image.img',
            'output_file': '/tmp/./image.img',
          },
          shell: CommandShell.posix,
        ).build(),
        throwsA(isA<CommandBuildException>()),
      );
    });
  });
}
