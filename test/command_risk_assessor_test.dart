import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/models/command_config.dart';
import 'package:terminal_master/services/command_risk_assessor.dart';
import 'package:terminal_master/utils/config_loader.dart';

void main() {
  group('CommandRiskAssessor', () {
    test('classifies ordinary commands as standard', () {
      final config = ConfigLoader.loadConfig('data/flutter.yaml');

      final assessment = CommandRiskAssessor.assessConfig(config, {
        'action': 'doctor',
      });

      expect(assessment.level, CommandRiskLevel.standard);
      expect(assessment.requiresAcknowledgement, isFalse);
    });

    test('classifies sudo commands as elevated', () {
      final config = ConfigLoader.loadConfig('data/nmap.yaml');

      final assessment = CommandRiskAssessor.assessConfig(config, {
        'target': '192.168.0.0/24',
        'use_sudo': true,
      });

      expect(assessment.level, CommandRiskLevel.elevated);
      expect(assessment.reasons, contains(contains('erhöhten Rechten')));
    });

    test('classifies dd and force options as destructive', () {
      final dd = ConfigLoader.loadConfig('data/dd.yaml');
      final gitPush = ConfigLoader.loadConfig('data/git_push.yaml');

      expect(
        CommandRiskAssessor.assessConfig(dd, const {}).level,
        CommandRiskLevel.destructive,
      );
      expect(
        CommandRiskAssessor.assessConfig(gitPush, {'force': true}).level,
        CommandRiskLevel.destructive,
      );
    });

    test('marks raw batch commands and detects destructive syntax', () {
      final safe = CommandRiskAssessor.assessRawCommands(['pwd', 'date']);
      final destructive = CommandRiskAssessor.assessRawCommands([
        'echo start',
        'sudo rm -rf /tmp/example',
      ]);

      expect(safe.level, CommandRiskLevel.standard);
      expect(safe.containsRawConfiguration, isTrue);
      expect(destructive.level, CommandRiskLevel.destructive);
      expect(destructive.reasons, isNotEmpty);
    });

    test('detects qualified and wrapped destructive executables', () {
      const qualifiedConfig = CommandConfig(
        command: '/bin/rm',
        description: '',
        parameters: [],
      );

      expect(
        CommandRiskAssessor.assessConfig(qualifiedConfig, const {}).level,
        CommandRiskLevel.destructive,
      );
      expect(
        CommandRiskAssessor.assessRawCommands([
          'sudo -n /bin/rm -rf /tmp/x',
        ]).level,
        CommandRiskLevel.destructive,
      );
      expect(
        CommandRiskAssessor.assessRawCommands(["sh -c 'dd if=a of=b'"]).level,
        CommandRiskLevel.destructive,
      );
    });

    test('does not treat unrelated short f options as destructive', () {
      final assessment = CommandRiskAssessor.assessRawCommands([
        'curl -f https://example.com',
        "echo 'a > b'",
      ]);

      expect(assessment.level, CommandRiskLevel.standard);
    });

    test('detects destructive Windows and PowerShell commands', () {
      for (final command in [
        r'del /s /q C:\temp\*',
        r'rmdir /s /q C:\temp',
        'format D:',
        r'Remove-Item C:\temp -Recurse -Force',
        'Clear-Disk -Number 1 -RemoveData',
      ]) {
        expect(
          CommandRiskAssessor.assessRawCommands([command]).level,
          CommandRiskLevel.destructive,
          reason: command,
        );
      }
    });
  });
}
