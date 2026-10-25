import 'dart:io';

import 'package:terminal_master/models/command_config.dart';
import 'package:terminal_master/utils/config_loader.dart';

CommandConfig loadTestCommandConfig(String yaml) {
  final directory = Directory.systemTemp.createTempSync(
    'terminal-master-command-config-',
  );
  final file = File('${directory.path}${Platform.pathSeparator}config.yaml')
    ..writeAsStringSync(yaml);
  try {
    return ConfigLoader.loadConfig(file.path);
  } finally {
    directory.deleteSync(recursive: true);
  }
}

CommandConfig sshCommandConfig() => loadTestCommandConfig('''
schema_version: 1
command: ssh
parameters:
  - name: username
    type: text
    flag: -l
  - name: port
    type: text
    flag: -p
  - name: identity_file
    type: filepath
    flag: -i
  - name: jump_host
    type: text
    flag: -J
  - name: force_ipv4
    type: boolean
    flag: "-4"
  - name: compression
    type: boolean
    flag: -C
  - name: agent_forwarding
    type: boolean
    flag: -A
  - name: batch_mode
    type: boolean
    flag: "-o BatchMode=yes"
  - name: host_key_checking
    type: options
    options:
      - value: "-o StrictHostKeyChecking=accept-new"
        description: Accept new host keys.
  - name: verbosity
    type: options
    options:
      - value: -vv
        description: Verbose output.
  - name: host
    type: options
    required: true
    options:
      - value: production.example.com
        description: Example host.
  - name: remote_command
    type: text
''');

CommandConfig ddCommandConfig() => loadTestCommandConfig('''
schema_version: 1
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
  - name: block_size
    type: text
    flag: bs=
  - name: conv
    type: text
    flag: conv=
  - name: status
    type: options
    flag: status=
    default: progress
    options:
      - value: progress
        description: Show progress.
      - value: none
        description: Suppress progress.
''');

CommandConfig gitCloneCommandConfig() => loadTestCommandConfig('''
schema_version: 1
command: git clone
parameters:
  - name: repository
    type: text
    required: true
  - name: depth
    type: text
    flag: --depth
''');

CommandConfig flutterCommandConfig() => loadTestCommandConfig('''
schema_version: 1
command: flutter
parameters:
  - name: action
    type: options
    required: true
    options:
      - value: pub get
        description: Resolve dependencies.
      - value: doctor
        description: Inspect the Flutter installation.
''');

CommandConfig nmapCommandConfig() => loadTestCommandConfig('''
schema_version: 1
command: nmap
parameters:
  - name: use_sudo
    type: boolean
    flag: sudo
    placement: before_command
    order: 0
  - name: scan_technique
    type: options
    options:
      - value: -sS
        description: TCP SYN scan.
    order: 10
  - name: syn_discovery_ports
    type: text
    flag: -PS
    join: attached
    order: 20
  - name: dns_servers
    type: text
    flag: --dns-servers
    order: 30
  - name: ports
    type: text
    flag: -p
    order: 40
  - name: version_detection
    type: boolean
    flag: -sV
    order: 50
  - name: version_intensity
    type: text
    flag: --version-intensity
    order: 60
  - name: default_scripts
    type: boolean
    flag: -sC
    order: 70
  - name: scripts
    type: text
    flag: --script
    order: 80
  - name: os_detection
    type: boolean
    flag: -O
    order: 90
  - name: timing_template
    type: options
    options:
      - value: -T4
        description: Faster timing.
    order: 100
  - name: output_xml
    type: filepath
    flag: -oX
    order: 110
  - name: verbosity
    type: options
    options:
      - value: -vv
        description: Very verbose.
    order: 120
  - name: show_reason
    type: boolean
    flag: --reason
    order: 130
  - name: target
    type: text_list
    required: true
    order: 140
''');

CommandConfig nmapBasicCommandConfig() => loadTestCommandConfig('''
schema_version: 1
command: nmap
parameters:
  - name: host_discovery_only
    type: boolean
    flag: -sn
    placement: argument
    order: 0
  - name: scan_type
    type: options
    visible_when:
      parameter: host_discovery_only
      active: false
    options:
      - value: -sT
        description: TCP connect scan.
    order: 10
  - name: port_preset
    type: options
    flag: -p
    conflicts_with: [custom_ports]
    visible_when:
      parameter: host_discovery_only
      active: false
    options:
      - value: 80,443
        description: Web ports.
    order: 20
  - name: custom_ports
    type: text
    flag: -p
    conflicts_with: [port_preset]
    visible_when:
      parameter: host_discovery_only
      active: false
    order: 21
  - name: version_detection
    type: boolean
    flag: -sV
    visible_when:
      parameter: host_discovery_only
      active: false
    order: 30
  - name: os_detection
    type: boolean
    flag: -O
    visible_when:
      parameter: host_discovery_only
      active: false
    order: 40
  - name: default_scripts
    type: boolean
    flag: -sC
    visible_when:
      parameter: host_discovery_only
      active: false
    order: 50
  - name: timing_template
    type: options
    flag: ""
    default: -T3
    options:
      - value: -T3
        description: Normal timing.
      - value: -T4
        description: Faster timing.
    order: 60
  - name: open_only
    type: boolean
    flag: --open
    visible_when:
      parameter: host_discovery_only
      active: false
    order: 70
  - name: verbosity
    type: options
    flag: ""
    visible_when:
      parameter: host_discovery_only
      active: false
    options:
      - value: -v
        description: Verbose output.
    order: 80
  - name: target
    type: text
    required: true
    default: 127.0.0.1
    order: 90
''');

CommandConfig pishrinkCommandConfig() => loadTestCommandConfig('''
schema_version: 1
command: pishrink
parameters:
  - name: use_sudo
    type: boolean
    flag: sudo
    placement: before_command
    default: true
    order: 0
  - name: input_file
    type: filepath
    required: true
    order: 10
  - name: output_file
    type: filepath
    flag: --output
    depends_on: [input_file]
    conflicts_with: [preserve_original]
    order: 20
  - name: preserve_original
    type: boolean
    flag: -p
    conflicts_with: [output_file]
    default: false
    order: 30
''');
