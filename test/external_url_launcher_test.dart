import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/services/external_url_launcher.dart';

void main() {
  test('accepts browser links and rejects unsupported schemes', () async {
    expect(
      ExternalUrlLauncher.isSupported(Uri.parse('https://example.com')),
      isTrue,
    );
    expect(
      ExternalUrlLauncher.isSupported(Uri.parse('mailto:test@example.com')),
      isTrue,
    );
    expect(
      ExternalUrlLauncher.isSupported(Uri.parse('file:///tmp/private')),
      isFalse,
    );
    await expectLater(
      ExternalUrlLauncher.open(Uri.parse('javascript:alert(1)')),
      throwsUnsupportedError,
    );
  });
}
