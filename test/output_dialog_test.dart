import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/widgets/output_dialog.dart';

void main() {
  testWidgets('closes after the caller context is disposed', (tester) async {
    final harnessKey = GlobalKey<_DialogHarnessState>();
    await tester.pumpWidget(MaterialApp(home: _DialogHarness(key: harnessKey)));

    await tester.tap(find.text('Fehler anzeigen'));
    await tester.pumpAndSettle();
    expect(find.text('Beispiel-Fehler'), findsOneWidget);

    harnessKey.currentState!.removeLauncher();
    await tester.pump();
    await tester.tap(find.text('Schließen'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Beispiel-Fehler'), findsNothing);
  });
}

class _DialogHarness extends StatefulWidget {
  const _DialogHarness({super.key});

  @override
  State<_DialogHarness> createState() => _DialogHarnessState();
}

class _DialogHarnessState extends State<_DialogHarness> {
  var _showLauncher = true;

  void removeLauncher() => setState(() => _showLauncher = false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _showLauncher ? const _DialogLauncher() : const SizedBox(),
    );
  }
}

class _DialogLauncher extends StatelessWidget {
  const _DialogLauncher();

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => showOutputDialog(context, 'Beispiel-Fehler'),
      child: const Text('Fehler anzeigen'),
    );
  }
}
