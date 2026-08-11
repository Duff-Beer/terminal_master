# Terminal Master

Terminal Master is a Flutter desktop application for building validated terminal
commands from reusable YAML definitions. It keeps command options discoverable,
checks conditional input requirements, and asks for explicit confirmation before
returning commands marked as risky.

Commands can run in a persistent, resizable `xterm` side panel backed by a
native pseudo terminal (`flutter_pty`). The panel stays active while navigating
between YAML definitions, and the configured external terminal remains
available as a fallback. It can be maximized inside the app and provides font
zoom, highlighted scrollback search, a visible scrollbar, and a shortcut back
to the latest output.

Generated commands are collected in the panel's editable command field without
an execution confirmation. This allows commands from multiple YAML definitions
to be reviewed or combined before explicitly sending them to the focused
terminal pane. Each tab owns an independent terminal workspace with its own PTY,
scrollback, search state, and pending command draft. A tab can be split into
side-by-side columns, stacked rows, or a combined 2x2 grid with up to four
independent PTYs. An individual split pane can temporarily fill the complete
terminal workspace while the other sessions continue running in the
background; sessions in other tabs remain active as well.

Terminal keyboard shortcuts use `Cmd` on macOS and `Ctrl` on Windows/Linux:

- `Cmd/Ctrl+F`: search the scrollback
- `Cmd/Ctrl++`, `Cmd/Ctrl+-`, `Cmd/Ctrl+0`: adjust or reset the font size
- `F11`: maximize or restore the terminal panel

The PTY advertises `xterm-256color` and `COLORTERM=truecolor`. The renderer
supports ANSI styles, 16/256/24-bit colors, wide Unicode characters, and system
monospace/emoji font fallbacks. Alternate-screen and mouse-reporting modes are
shown in the terminal status bar. Interactive terminal applications receive
click, wheel, drag, and pointer-move events while mouse reporting is active;
normal scrollback behavior remains available when an application does not
request wheel events.

Visible HTTP(S), mail, and OSC-8 hyperlinks can be opened with `Cmd/Ctrl+Click`
or from the context menu. The context menu also provides copy, paste, select
all, search selection, and clear-output actions. The status bar tracks the
shell, OSC-7 working directory, dynamic OSC title, process state, and exit code.

## Integrated Shell Profiles

Without configuration, Terminal Master offers the platform shell and installed
Bash, Zsh, or Fish executables it can detect. Custom local shells, SSH sessions,
containers, and other interactive programs can be defined in `settings.yaml`:

```yaml
integrated_terminal:
  default_profile: local-zsh
  profiles:
    - id: local-zsh
      name: Local Zsh
      executable: /bin/zsh
      arguments: [-l]
      working_directory: ~/projects
      dialect: posix
    - id: production-ssh
      name: Production SSH
      executable: /usr/bin/ssh
      arguments: [example.com]
      environment:
        LANG: en_US.UTF-8
      dialect: posix
    - id: powershell
      name: PowerShell 7
      executable: /usr/bin/pwsh
      arguments: [-NoLogo]
      dialect: powershell
```

Profile IDs must be unique. Supported command dialects are `posix`,
`windows_cmd`, and `powershell`; the selected dialect controls command quoting,
line endings, and Command Block exit-code tracking. Windows PowerShell is the
default Windows profile when PowerShell 7 is unavailable; installed PowerShell
7 executables are detected across supported desktop platforms.
Terminal Master variables such as `TERM=xterm-256color` and
`COLORTERM=truecolor` remain authoritative.

## Command Blocks

Commands sent through a tab's Terminal Master input field are tracked as
Command Blocks. Each block records its command, start time, duration, exit code,
success/failure/interruption state, and up to 500,000 characters of plain-text
output. Tracking markers are removed from the visible terminal output. Blocks
can copy their command or output and export a Markdown report through the
history button in the terminal status bar. Commands typed directly into the
terminal remain untracked and behave like a normal shell session.

<img src="assets/branding/terminal_master.png" alt="Terminal Master icon" width="180">

## Development

Terminal Master requires the Flutter stable channel.

```sh
flutter pub get
flutter analyze
flutter test
flutter run -d macos
```

Replace `macos` with `windows` or `linux` when developing on those platforms.

The native PTY smoke test can be run on a desktop target with:

```sh
flutter test integration_test/terminal_pty_test.dart -d macos
```

## Command Definitions

YAML definitions are stored in `data/`. The application copies its bundled
definitions to the platform application-support directory, where they can be
extended or replaced without rebuilding the application.

## Desktop Releases

The release workflow creates these unsigned artifacts:

- macOS: DMG and ZIP
- Windows: Inno Setup installer and ZIP
- Linux: DEB, AppImage, and tarball
- Linux package manifests: Arch `PKGBUILD` and Nix `flake.nix`

Push a tag matching the semantic version in `pubspec.yaml`, for example `v1.0.0`,
or run the Release workflow manually. The workflow creates a draft GitHub release
so its artifacts can be checked before publication.
