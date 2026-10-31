# Changelog

All notable changes to Terminal Master are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - Unreleased

### Added

- Dropping files or folders onto a local terminal inserts their paths, quoted
  for the profile's shell dialect.
- Dropping files or folders onto an SSH session uploads them via SFTP. By
  default they go to the shell's current directory, and the target can be
  edited or browsed on the server. Folders are uploaded recursively, and
  existing entries can be overwritten, renamed or skipped. Afterwards the
  remote path can be inserted, and `ls -la` lists the target directory.
- A middle click pastes the clipboard into the terminal, like `Cmd/Ctrl+V`.

### Changed

- The build number is derived from the number of commits.

### Fixed

- TUIs such as Claude Code render correctly. The terminal fonts and symbol,
  math and emoji fallbacks are bundled. Local shells without a UTF-8 locale
  get a UTF-8 character type. Escape sequences such as XTMODKEYS no longer
  turn on underline and faint, and colon separated colors are parsed
  correctly.
- Copying text from the terminal keeps the spaces of cells skipped by tabs or
  cursor movement.
- A middle click no longer opens the context menu.
- Only one scrollbar is shown while scrolling the terminal on desktop.
- The Linux build works with both newer and older Clang versions.

## [1.0.0] - 2026-10-25

First release for macOS, Windows and Linux.

### Added

- Command builder with reusable YAML definitions, searchable options,
  dependencies, conditional fields and multilingual definitions. Definitions,
  options and batch commands can be edited in the app.
- Generated commands are staged for review before they run. Elevated and
  destructive commands require explicit confirmation.
- Integrated terminal with native pseudo-terminals, tabs, up to four split
  panes, scrollback search, zoom, true color, mouse reporting and hyperlinks.
- Shell profiles for the platform shell, Bash, Zsh, Fish, PowerShell and
  custom programs, configurable in `settings.yaml`.
- Managed SSH connections with host-key verification, passwords and key
  passphrases in the operating system's credential store, and encrypted
  connection backups.
- Command Blocks that record the command, duration, exit code and output of
  commands sent through the command field.
- Saved terminal tabs that restore the pane layout, shell profiles, working
  directories and recent commands.
- English and German interface.
- Release artifacts: DMG and ZIP for macOS, installer and ZIP for Windows,
  DEB, AppImage, tarball, Arch `PKGBUILD` and Nix flake for Linux.

[1.0.1]: https://github.com/Duff-Beer/terminal_master/compare/1.0.0...HEAD
[1.0.0]: https://github.com/Duff-Beer/terminal_master/tree/1.0.0
