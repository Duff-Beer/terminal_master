import 'dart:io';

abstract final class ExternalUrlLauncher {
  static bool isSupported(Uri uri) =>
      uri.hasScheme && const {'http', 'https', 'mailto'}.contains(uri.scheme);

  static Future<void> open(Uri uri) async {
    if (!isSupported(uri)) {
      throw UnsupportedError('Nicht unterstützter Link: $uri');
    }

    if (Platform.isMacOS) {
      await Process.start('open', [
        uri.toString(),
      ], mode: ProcessStartMode.detached);
      return;
    }
    if (Platform.isWindows) {
      await Process.start('rundll32.exe', [
        'url.dll,FileProtocolHandler',
        uri.toString(),
      ], mode: ProcessStartMode.detached);
      return;
    }
    if (Platform.isLinux) {
      await Process.start('xdg-open', [
        uri.toString(),
      ], mode: ProcessStartMode.detached);
      return;
    }
    throw UnsupportedError('Links werden auf dieser Plattform nicht geöffnet.');
  }
}
