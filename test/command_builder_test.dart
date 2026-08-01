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

    test('quotes PowerShell metacharacters and embedded apostrophes', () {
      final config = ConfigLoader.loadConfig('data/git_clone.yaml');
      final command = CommandBuilder(
        config: config,
        values: {
          ...config.defaultValues,
          'repository': r"repo's folder; Write-Output $env:PATH",
          'depth': '1',
        },
        shell: CommandShell.powerShell,
      ).build();

      expect(
        command,
        r"git clone 'repo''s folder; Write-Output $env:PATH' --depth 1",
      );
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

    test('renders a combined Nmap scan with required option values', () {
      final config = ConfigLoader.loadConfig('data/nmap.yaml');
      final command = CommandBuilder(
        config: config,
        values: {
          ...config.defaultValues,
          'use_sudo': true,
          'scan_technique': '-sS',
          'syn_discovery_ports': '80,443',
          'dns_servers': '1.1.1.1,8.8.8.8',
          'ports': '22,80,443',
          'version_detection': true,
          'version_intensity': '7',
          'default_scripts': true,
          'scripts': 'http-title,safe',
          'os_detection': true,
          'timing_template': '-T4',
          'output_xml': '/tmp/scan report.xml',
          'verbosity': '-vv',
          'show_reason': true,
          'target': ['scanme.nmap.org', '192.168.1.0/24'],
        },
        shell: CommandShell.posix,
      ).build();

      expect(
        command,
        "sudo nmap -sS -PS80,443 --dns-servers 1.1.1.1,8.8.8.8 "
        "-p 22,80,443 -sV --version-intensity 7 -sC --script "
        "http-title,safe -O -T4 -oX '/tmp/scan report.xml' -vv --reason "
        'scanme.nmap.org 192.168.1.0/24',
      );
    });

    test('renders the basic Nmap defaults and selected common options', () {
      final config = ConfigLoader.loadConfig('data/nmap_basic.yaml');
      final command = CommandBuilder(
        config: config,
        values: {
          ...config.defaultValues,
          'scan_type': '-sT',
          'port_preset': '80,443',
          'version_detection': true,
          'open_only': true,
          'verbosity': '-v',
        },
        shell: CommandShell.posix,
      ).build();

      expect(command, 'nmap -sT -p 80,443 -sV -T3 --open -v 127.0.0.1');
    });

    test('ignores hidden values and enforces conditional requirements', () {
      final directory = Directory.systemTemp.createTempSync('conditions-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final configFile = File('${directory.path}/conditional.yaml')
        ..writeAsStringSync('''
schema_version: 1
command: demo
parameters:
  - name: advanced
    type: boolean
  - name: hidden_value
    type: text
    flag: --hidden
    visible_when:
      parameter: advanced
      equals: true
  - name: mode
    type: options
    flag: --mode
    options:
      - value: basic
        description: Basic
      - value: secure
        description: Secure
  - name: consumer
    type: boolean
    flag: --consumer
    depends_on: [hidden_value]
  - name: token
    type: text
    flag: --token
    visible_when:
      parameter: mode
      equals: secure
    required_when:
      parameter: mode
      equals: secure
  - name: targets
    type: text_list
    required: true
''');
      final config = ConfigLoader.loadConfig(configFile.path);

      final basicCommand = CommandBuilder(
        config: config,
        values: const {
          'advanced': false,
          'hidden_value': 'stale-value',
          'mode': 'basic',
          'token': 'stale-token',
          'consumer': false,
          'targets': ['first.example', 'second; touch /tmp/injected'],
        },
        shell: CommandShell.posix,
      ).build();

      expect(
        basicCommand,
        "demo --mode basic first.example 'second; touch /tmp/injected'",
      );
      expect(
        () => CommandBuilder(
          config: config,
          values: const {
            'advanced': false,
            'hidden_value': 'stale-value',
            'mode': 'basic',
            'consumer': true,
            'targets': ['first.example'],
          },
          shell: CommandShell.posix,
        ).build(),
        throwsA(
          isA<CommandBuildException>().having(
            (error) => error.message,
            'message',
            contains('hidden_value'),
          ),
        ),
      );
      expect(
        () => CommandBuilder(
          config: config,
          values: const {
            'mode': 'secure',
            'targets': ['first.example'],
          },
          shell: CommandShell.posix,
        ).build(),
        throwsA(
          isA<CommandBuildException>().having(
            (error) => error.message,
            'message',
            contains('token'),
          ),
        ),
      );
    });

    test('removes port scan options from basic Nmap host discovery', () {
      final config = ConfigLoader.loadConfig('data/nmap_basic.yaml');
      final command = CommandBuilder(
        config: config,
        values: {
          ...config.defaultValues,
          'host_discovery_only': true,
          'scan_type': '-sT',
          'port_preset': '80,443',
          'version_detection': true,
          'os_detection': true,
          'default_scripts': true,
          'open_only': true,
        },
        shell: CommandShell.posix,
      ).build();

      expect(command, 'nmap -sn -T3 127.0.0.1');
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
