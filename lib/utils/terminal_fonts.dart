/// Fonts bundled in `assets/fonts` (registered in `pubspec.yaml`) so the
/// integrated terminal does not depend on the fonts of the operating system.
abstract final class TerminalFonts {
  static const String defaultFamily = 'JetBrains Mono';

  /// Primary fonts the user can choose from in the settings.
  static const List<String> families = ['JetBrains Mono', 'DejaVu Sans Mono'];

  /// Covers what TUIs such as Claude Code, htop or mc draw beyond the primary
  /// font: Braille spinners, technical symbols (⏺ ⎿ ⏵), math symbols and emoji.
  /// Only bundled fonts are listed — a system fallback like `sans-serif` is
  /// proportional and breaks the cell grid.
  static const List<String> fallback = [
    'DejaVu Sans Mono',
    'Noto Sans Symbols',
    'Noto Sans Symbols 2',
    'Noto Sans Math',
    'Noto Emoji',
  ];
}
