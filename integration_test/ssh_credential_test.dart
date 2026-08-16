import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:terminal_master/services/ssh_credential_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('stores SSH credentials in the platform credential store', (
    tester,
  ) async {
    const store = SecureSshCredentialStore();
    final id = 'integration-${DateTime.now().microsecondsSinceEpoch}';
    addTearDown(() => store.deletePassword(id));

    await store.writePassword(id, 'integration-secret');

    expect(await store.readPassword(id), 'integration-secret');
    await store.deletePassword(id);
    expect(await store.readPassword(id), isNull);
  });
}
