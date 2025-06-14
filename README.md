# terminal_master

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Configuration

Beim ersten Start legt die Anwendung eine Datei `settings.yaml` im
Anwendungsverzeichnis an. Darin kann der verwendete Terminal-Befehl
angepasst werden. Unter Linux wird standardmäßig `terminator` verwendet,
sofern dieser installiert ist, ansonsten `gnome-terminal`.

Um Terminator explizit zu nutzen, ändern Sie den Eintrag in der Datei wie
folgt (die Anwendung führt dann automatisch `terminator -x` aus):

```yaml
terminal: terminator
file_manager: xdg-open
```
