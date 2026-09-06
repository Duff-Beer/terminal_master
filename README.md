# Terminal Master

Terminal Master is a Flutter desktop application for building validated terminal
commands from reusable YAML definitions. It keeps command options discoverable,
checks conditional input requirements, and asks for explicit confirmation before
returning commands marked as risky.

Commands run in a persistent `xterm` workspace backed by a native pseudo
terminal (`flutter_pty`). The terminal is the primary view; a slim tool rail
opens the Command Builder or managed SSH connections in an overlay without
resizing running terminal applications. The configured external terminal
remains available as a fallback. The workspace provides font zoom, highlighted
scrollback search, a visible scrollbar, and a shortcut back to the latest
output.

Generated commands are collected in the panel's editable command field without
an execution confirmation. This allows commands from multiple YAML definitions
to be reviewed or combined before explicitly sending them to the focused
terminal pane. Search is available from the responsive bottom command bar.
Restarting a session is available from the tab context menu and, on narrow
windows, from the command bar's overflow menu. A running process is shut down
gracefully before its pane restarts. Closing a tab uses the same controlled
shutdown. Tabs can be renamed from their context menu; saving a tab persists
its custom name and restores it when the snapshot is opened. Each tab owns an
independent terminal workspace with its own PTY,
scrollback, search state, and pending command draft. A tab can be split into
side-by-side columns, stacked rows, or a combined 2x2 grid with up to four
independent PTYs. An individual split pane can temporarily fill the complete
terminal workspace while the other sessions continue running in the
background; sessions in other tabs remain active as well.

Terminal keyboard shortcuts use `Cmd` on macOS and `Ctrl` on Windows/Linux:

- `Cmd/Ctrl+F`: search the scrollback
- `Cmd/Ctrl+B`: open or close the Command Builder
- `Cmd/Ctrl++`, `Cmd/Ctrl+-`, `Cmd/Ctrl+0`: adjust or reset the font size

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

## SSH Connections

The SSH connections page stores reusable server profiles with a display name,
host, port, username, and either password or private-key authentication.
Passwords and optional private-key passphrases are kept separately in the
operating system's secure credential store: Keychain on macOS, Credential
Manager on Windows, and Secret Service on Linux. Private keys remain in their
selected files. Secrets are never written to YAML, profile metadata, terminal
snapshots, or application logs.

Private-key profiles are currently available on desktop platforms. Mobile file
pickers expose temporary cache paths rather than durable references, so Terminal
Master deliberately disables private-key selection on Android and iOS.

Connections use an interactive `xterm-256color` remote PTY. The first connection
shows the server's SHA-256 host-key fingerprint and requires explicit trust for
one connection or permanent storage. A changed trusted host key is always
blocked. Profiles can be added, edited, tested, connected in a new terminal tab,
and deleted together with their stored credential. Supported private-key input
includes OpenSSH RSA, Ed25519, and ECDSA keys plus legacy RSA keys accepted by
`dartssh2`; unsupported PKCS#8 keys must first be converted with `ssh-keygen`.
Linux systems need a running
Secret Service provider such as GNOME Keyring or KWallet; without one, secure
password storage reports an error instead of falling back to plaintext.

Complete connection lists, including passwords, key passphrases, private-key
paths, and pinned host keys, can be exported as `.tmsshbackup` files. Private
key contents are deliberately excluded. Backup passwords must contain at least 12
characters. Argon2id derives a 256-bit key with a 64 MiB memory cost, and
AES-256-GCM encrypts and authenticates the complete payload; no profile or
password data is written outside the ciphertext. Import verifies the format and
authentication tag before showing a preview. Endpoint conflicts default to
skip and can explicitly be replaced or imported as a copy. Host-key differences
are highlighted, and a compare-and-swap update prevents the import from
overwriting profiles changed while the preview was open. Backup passwords cannot
be recovered by Terminal Master.

## SSH Command Generator

The bundled `ssh.yaml` provides an SSH command form with a required host
dropdown. Its initial entries are `localhost` and reserved staging/production
example domains. Replace these entries in the installed `ssh.yaml` with real
hostnames, IP addresses, or aliases from `~/.ssh/config`. The form also supports
username, port, identity file, ProxyJump host, IPv4/IPv6, compression, agent and
X11 forwarding, batch mode, host-key policy, verbosity, and an optional remote
command.

Every YAML `options` field uses the same searchable selection dialog. It filters
case-insensitively across both the configured value and description, supports
arrow-key/Enter/Escape navigation, and keeps `Nicht verwenden` available for
optional fields. `Eintrag hinzufügen` stores a new value and description
directly in the current YAML options list, creates a `.bak` backup, validates the
updated file, and selects the new entry immediately. Concurrent external changes
and duplicate values are rejected instead of being overwritten. Individual
entries can be permanently removed with the delete action after confirmation;
the last remaining option and entries referenced by defaults or conditions are
protected from deletion.

Batch command views also support persistent editing. The add action stores a
title, optional description, and command in the current batch YAML file. Each
row provides a delete action with confirmation. Both operations validate the
updated YAML and preserve the previous source in a `.bak` file.

## Command Blocks

Commands sent through a tab's Terminal Master input field are tracked as
Command Blocks. Each block records its command, start time, duration, exit code,
success/failure/interruption state, and up to 500,000 characters of plain-text
output. Tracking markers are removed from the visible terminal output. Blocks
can copy their command or output and export a Markdown report through the
history button in the terminal status bar. Commands typed directly into the
terminal remain untracked and behave like a normal shell session.

## Saved Terminal Tabs

The save action in a tab's right-click menu saves or updates a named tab
snapshot. Snapshots preserve the one-to-four-pane layout, shell profile and
last working directory of every pane, the focused pane, pending command drafts,
and the latest 20 completed Command Block commands per pane. Terminal output
and commands typed directly into the PTY are not persisted.

The folder action opens a snapshot as a new tab with fresh PTY processes. Saved
commands are listed separately in Command Blocks and can be copied, loaded into
the editable command field, executed individually, or executed sequentially for
their pane. Standard commands run from the explicit play action; elevated and
destructive commands require the existing risk acknowledgement. Opening does
not execute commands by default. An optional switch in the open dialog previews
all saved commands and, after explicit confirmation, replays them sequentially
per pane while separate panes may run in parallel. Snapshots are stored in
`saved_terminal_tabs.json` in Terminal Master's application-support directory.

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
- Linux package manifests: Arch `PKGBUILD` and a native Nix `flake.nix`

The Nix package installs and patches the release tarball directly instead of
running the AppImage through an FHS sandbox. This keeps host facilities such as
NixOS's `/run/wrappers/bin/sudo` available to the integrated terminal.

Push a tag matching the semantic version in `pubspec.yaml`, for example `v1.0.0`,
or run the Release workflow manually. The workflow creates a draft GitHub release
so its artifacts can be checked before publication.
