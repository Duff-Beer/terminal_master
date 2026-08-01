import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

class TerminalMouseOverlay extends StatefulWidget {
  final Terminal terminal;
  final GlobalKey<TerminalViewState> terminalViewKey;
  final ScrollController scrollController;
  final ValueChanged<String> sendInput;

  const TerminalMouseOverlay({
    super.key,
    required this.terminal,
    required this.terminalViewKey,
    required this.scrollController,
    required this.sendInput,
  });

  @override
  State<TerminalMouseOverlay> createState() => _TerminalMouseOverlayState();
}

class _TerminalMouseOverlayState extends State<TerminalMouseOverlay> {
  TerminalMouseButton? _pressedButton;
  CellOffset? _lastPosition;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      child: Listener(
        key: const Key('terminal-mouse-overlay'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: _handlePointerDown,
        onPointerUp: _handlePointerUp,
        onPointerCancel: _handlePointerCancel,
        onPointerMove: _handlePointerMove,
        onPointerSignal: _handlePointerSignal,
        child: const SizedBox.expand(),
      ),
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    final button = _buttonFor(event.buttons);
    final position = _cellAt(event.localPosition);
    if (button == null || position == null) return;
    _pressedButton = button;
    _lastPosition = position;
    widget.terminalViewKey.currentState?.requestKeyboard();
    widget.terminal.mouseInput(button, TerminalMouseButtonState.down, position);
  }

  void _handlePointerUp(PointerUpEvent event) {
    final button = _pressedButton;
    final position = _cellAt(event.localPosition);
    if (button != null && position != null) {
      widget.terminal.mouseInput(button, TerminalMouseButtonState.up, position);
    }
    _pressedButton = null;
    _lastPosition = null;
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _pressedButton = null;
    _lastPosition = null;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final mode = widget.terminal.mouseMode;
    final reportsDrag = mode == MouseMode.upDownScrollDrag;
    final reportsMove = mode == MouseMode.upDownScrollMove;
    if (!reportsMove && !(reportsDrag && _pressedButton != null)) return;

    final position = _cellAt(event.localPosition);
    if (position == null || position == _lastPosition) return;
    _lastPosition = position;
    widget.sendInput(_encodeMotion(_pressedButton, position));
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (!widget.terminal.mouseMode.reportScroll) {
      if (!widget.scrollController.hasClients) return;
      final position = widget.scrollController.position;
      widget.scrollController.jumpTo(
        (position.pixels + event.scrollDelta.dy).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
      return;
    }
    final position = _cellAt(event.localPosition);
    if (position == null || event.scrollDelta.dy == 0) return;
    widget.terminal.mouseInput(
      event.scrollDelta.dy < 0
          ? TerminalMouseButton.wheelUp
          : TerminalMouseButton.wheelDown,
      TerminalMouseButtonState.down,
      position,
    );
  }

  CellOffset? _cellAt(Offset localPosition) {
    final state = widget.terminalViewKey.currentState;
    if (state == null) return null;
    return state.renderTerminal.getCellOffset(localPosition);
  }

  TerminalMouseButton? _buttonFor(int buttons) {
    if (buttons & kPrimaryMouseButton != 0) return TerminalMouseButton.left;
    if (buttons & kSecondaryMouseButton != 0) return TerminalMouseButton.right;
    if (buttons & kMiddleMouseButton != 0) return TerminalMouseButton.middle;
    return null;
  }

  String _encodeMotion(TerminalMouseButton? button, CellOffset position) {
    final buttonId = (button?.id ?? 3) + 32;
    final column = position.x + 1;
    final row = position.y + 1;
    return switch (widget.terminal.mouseReportMode) {
      MouseReportMode.normal =>
        '\x1b[M${String.fromCharCode(32 + buttonId)}'
            '${_legacyCoordinate(column, 223)}${_legacyCoordinate(row, 223)}',
      MouseReportMode.utf =>
        '\x1b[M${String.fromCharCode(32 + buttonId)}'
            '${_legacyCoordinate(column, 2015)}'
            '${_legacyCoordinate(row, 2015)}',
      MouseReportMode.sgr => '\x1b[<$buttonId;$column;${row}M',
      MouseReportMode.urxvt => '\x1b[${32 + buttonId};$column;${row}M',
    };
  }

  String _legacyCoordinate(int value, int maximum) {
    return value > maximum ? '\x00' : String.fromCharCode(32 + value);
  }
}
