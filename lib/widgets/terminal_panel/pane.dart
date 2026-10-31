part of '../terminal_panel.dart';

class TerminalPane extends StatefulWidget {
  final TerminalPaneData pane;
  final TerminalPanelController panelController;
  final GlobalKey<NavigatorState> navigatorKey;

  const TerminalPane({
    super.key,
    required this.pane,
    required this.panelController,
    required this.navigatorKey,
  });

  @override
  State<TerminalPane> createState() => _TerminalPaneState();
}

class _TerminalPaneState extends State<TerminalPane> {
  final _terminalController = TerminalController();
  final _terminalViewKey = GlobalKey<TerminalViewState>();
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final List<TerminalHighlight> _searchHighlights = [];
  List<_TerminalSearchMatch> _searchMatches = [];
  int _activeSearchMatch = -1;
  bool _isAtBottom = true;
  bool _wasSearchOpen = false;
  bool _searchRefreshScheduled = false;
  bool _showCommandHistory = false;
  bool _isDropHovering = false;

  TerminalSession get session => widget.pane.session;

  static const _terminalTheme = TerminalTheme(
    cursor: TerminalMasterColors.green,
    selection: Color(0x663b82f6),
    foreground: TerminalMasterColors.green,
    background: TerminalMasterColors.background,
    black: TerminalMasterColors.background,
    red: Color(0xffff6b6b),
    green: TerminalMasterColors.green,
    yellow: TerminalMasterColors.yellow,
    blue: TerminalMasterColors.blue,
    magenta: Color(0xffc792ea),
    cyan: TerminalMasterColors.cyan,
    white: TerminalMasterColors.foreground,
    brightBlack: TerminalMasterColors.muted,
    brightRed: Color(0xffff8b8b),
    brightGreen: Color(0xff7ff6c9),
    brightYellow: Color(0xffffd978),
    brightBlue: Color(0xff8dbdff),
    brightMagenta: Color(0xffd9a8f1),
    brightCyan: Color(0xff8ce4f0),
    brightWhite: Color(0xffffffff),
    searchHitBackground: TerminalMasterColors.yellow,
    searchHitBackgroundCurrent: Color(0xffff8b3d),
    searchHitForeground: TerminalMasterColors.background,
  );

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    session.addListener(_handleSessionUpdate);
    session.terminal.addListener(_scheduleSearchRefresh);
  }

  @override
  void dispose() {
    session.removeListener(_handleSessionUpdate);
    session.terminal.removeListener(_scheduleSearchRefresh);
    _clearSearchHighlights();
    _searchFocusNode.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _terminalController.dispose();
    super.dispose();
  }

  void _handleSessionUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isSearchOpen = widget.pane.isSearchOpen;
    if (isSearchOpen && !_wasSearchOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocusNode.requestFocus();
      });
    }
    _wasSearchOpen = isSearchOpen;

    return Column(
      children: [
        AnimatedBuilder(
          animation: session,
          builder: (context, child) => Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: TerminalMasterColors.surface,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final showSessionStatus = constraints.maxWidth >= 220;
                final showIndicators = constraints.maxWidth >= 360;
                final showZoomControls = constraints.maxWidth >= 600;
                final compactActionSize = constraints.maxWidth < 160
                    ? 28.0
                    : 32.0;
                return Row(
                  children: [
                    if (showSessionStatus) ...[
                      Icon(
                        _statusIcon(session.status),
                        size: 13,
                        color: _statusColor(session.status),
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: Tooltip(
                          message: _statusTooltip(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _statusTitle(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: session.title == null
                                      ? TerminalMasterColors.cyan
                                      : TerminalMasterColors.yellow,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                _sessionDetails(),
                                key: _paneKey('terminal-session-details'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: TerminalMasterColors.muted,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else
                      const Spacer(),
                    _compactIconButton(
                      key: _paneKey('split-terminal-vertical'),
                      tooltip: l10n.terminalSplitLeftRight,
                      icon: Icons.view_column_outlined,
                      size: compactActionSize,
                      onPressed: () => widget.panelController.toggleSplit(
                        TerminalSplitOrientation.vertical,
                        widget.pane.id,
                      ),
                    ),
                    _compactIconButton(
                      key: _paneKey('split-terminal-horizontal'),
                      tooltip: l10n.terminalSplitTopBottom,
                      icon: Icons.view_agenda_outlined,
                      size: compactActionSize,
                      onPressed: () => widget.panelController.toggleSplit(
                        TerminalSplitOrientation.horizontal,
                        widget.pane.id,
                      ),
                    ),
                    const Spacer(),
                    if (showIndicators)
                      Tooltip(
                        message: l10n.terminalTrueColorTooltip,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.palette_outlined,
                            key: _paneKey('terminal-true-color-indicator'),
                            size: 14,
                            color: TerminalMasterColors.cyan,
                          ),
                        ),
                      ),
                    if (showIndicators && session.terminal.isUsingAltBuffer)
                      Tooltip(
                        message: l10n.terminalAlternateScreenActive,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.layers_outlined,
                            key: _paneKey('terminal-alt-screen-indicator'),
                            size: 14,
                            color: TerminalMasterColors.yellow,
                          ),
                        ),
                      ),
                    if (showIndicators &&
                        session.terminal.mouseMode != MouseMode.none)
                      Tooltip(
                        message: l10n.terminalMouseControlActive,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.mouse_outlined,
                            key: _paneKey('terminal-mouse-mode-indicator'),
                            size: 14,
                            color: TerminalMasterColors.green,
                          ),
                        ),
                      ),
                    _compactIconButton(
                      key: _paneKey('terminal-command-history-toggle'),
                      tooltip: l10n.terminalCommandBlocksCount(
                        session.commandBlocks.length,
                      ),
                      icon: _showCommandHistory
                          ? Icons.receipt_long
                          : Icons.receipt_long_outlined,
                      size: compactActionSize,
                      onPressed: () {
                        setState(
                          () => _showCommandHistory = !_showCommandHistory,
                        );
                      },
                    ),
                    if (widget.panelController.isSplit)
                      _compactIconButton(
                        key: _paneKey('maximize-terminal-pane'),
                        tooltip:
                            widget.panelController.isPaneMaximized(
                              widget.pane.id,
                            )
                            ? l10n.terminalRestoreSplitView
                            : l10n.terminalMaximizePane,
                        icon:
                            widget.panelController.isPaneMaximized(
                              widget.pane.id,
                            )
                            ? Icons.close_fullscreen
                            : Icons.open_in_full,
                        color:
                            widget.panelController.isPaneMaximized(
                              widget.pane.id,
                            )
                            ? TerminalMasterColors.yellow
                            : null,
                        size: compactActionSize,
                        onPressed: () => widget.panelController
                            .togglePaneMaximized(widget.pane.id),
                      ),
                    if (showZoomControls) ...[
                      _compactIconButton(
                        key: _paneKey('terminal-zoom-out'),
                        tooltip: l10n.terminalDecreaseFontSize,
                        icon: Icons.remove,
                        onPressed: widget.panelController.zoomOut,
                      ),
                      TextButton(
                        key: _paneKey('terminal-zoom-reset'),
                        onPressed: widget.panelController.resetZoom,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(42, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        child: Text(
                          '${widget.panelController.fontSize.round()} px',
                        ),
                      ),
                      _compactIconButton(
                        key: _paneKey('terminal-zoom-in'),
                        tooltip: l10n.terminalIncreaseFontSize,
                        icon: Icons.add,
                        onPressed: widget.panelController.zoomIn,
                      ),
                    ],
                    _compactIconButton(
                      key: _paneKey('close-terminal-pane'),
                      tooltip: l10n.terminalClosePane,
                      icon: Icons.close,
                      size: compactActionSize,
                      color: TerminalMasterColors.red,
                      onPressed: () async {
                        if (session.isRunning) {
                          final shouldClose = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: Text(l10n.terminalCloseRunningPaneTitle),
                              content: Text(
                                l10n.terminalCloseRunningPaneMessage,
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, false),
                                  child: Text(l10n.terminalCancel),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, true),
                                  child: Text(l10n.terminalClosePane),
                                ),
                              ],
                            ),
                          );
                          if (shouldClose != true) return;
                        }
                        await widget.panelController.closePane(widget.pane.id);
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        if (isSearchOpen) _buildSearchBar(),
        if (_showCommandHistory) _buildCommandHistory(),
        Expanded(
          child: DropTarget(
            onDragEntered: (_) => setState(() => _isDropHovering = true),
            onDragExited: (_) => setState(() => _isDropHovering = false),
            onDragDone: _handleDrop,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    child: TerminalView(
                      session.terminal,
                      key: _terminalViewKey,
                      controller: _terminalController,
                      scrollController: _scrollController,
                      theme: _terminalTheme,
                      textStyle: TerminalStyle(
                        fontSize: widget.panelController.fontSize,
                        fontFamily: widget.panelController.terminalFontFamily,
                        fontFamilyFallback: TerminalFonts.fallback,
                      ),
                      padding: const EdgeInsets.all(10),
                      autofocus: false,
                      alwaysShowCursor: true,
                      onTapUp: _handleTerminalTap,
                      onSecondaryTapDown: _handleSecondaryTap,
                      onKeyEvent: _handleTerminalKey,
                    ),
                  ),
                ),
                if (session.terminal.mouseMode != MouseMode.none)
                  Positioned.fill(
                    child: TerminalMouseOverlay(
                      overlayKey: _paneKey('terminal-mouse-overlay'),
                      terminal: session.terminal,
                      terminalViewKey: _terminalViewKey,
                      scrollController: _scrollController,
                      sendInput: session.sendInput,
                    ),
                  ),
                if (!_isAtBottom)
                  Positioned(
                    right: 18,
                    bottom: 12,
                    child: FloatingActionButton.small(
                      key: _paneKey('terminal-scroll-to-bottom'),
                      tooltip: l10n.terminalJumpToOutput,
                      onPressed: _scrollToBottom,
                      child: const Icon(Icons.keyboard_arrow_down),
                    ),
                  ),
                if (_isDropHovering) _buildDropOverlay(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          key: _paneKey('terminal-drop-overlay'),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: TerminalMasterColors.background.withValues(alpha: 0.7),
            border: Border.all(color: TerminalMasterColors.green, width: 2),
          ),
          child: Text(
            AppLocalizations.of(context).terminalDropHint,
            style: const TextStyle(
              color: TerminalMasterColors.green,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleDrop(DropDoneDetails details) async {
    setState(() => _isDropHovering = false);
    final localPaths = details.files.map((file) => file.path).toList();
    if (droppedPathsInput(localPaths, widget.pane.profile.dialect).isEmpty) {
      return;
    }
    widget.panelController.focusPane(widget.pane.id);

    final transfer = session.remoteFileTransfer;
    final dialogContext = widget.navigatorKey.currentContext;
    if (!widget.pane.profile.isSsh ||
        transfer == null ||
        dialogContext == null) {
      _insertDroppedPaths(
        localPaths,
        isLocalOnRemote: widget.pane.profile.isSsh,
      );
      return;
    }

    RemoteFileSystem? fileSystem;
    try {
      fileSystem = await transfer.openFileSystem();
      final shellDirectory = await session.resolveRemoteWorkingDirectory();
      final initialDirectory =
          shellDirectory ?? await fileSystem.homeDirectory();
      if (!mounted || !dialogContext.mounted) return;
      final choice = await showSshDropDialog(
        dialogContext,
        localPaths: localPaths,
        fileSystem: fileSystem,
        initialDirectory: initialDirectory,
      );
      if (!mounted || choice == null) return;
      final remoteDirectory = choice.remoteDirectory;
      if (remoteDirectory == null) {
        _insertDroppedPaths(localPaths, isLocalOnRemote: true);
        return;
      }

      final uploadContext = widget.navigatorKey.currentContext;
      if (uploadContext == null || !uploadContext.mounted) return;
      final result = await showRemoteUploadDialog(
        uploadContext,
        fileSystem: fileSystem,
        localPaths: localPaths,
        remoteDirectory: remoteDirectory,
      );
      if (!mounted) return;
      if (result.error case final error?) {
        _showUploadError(error);
      } else if (result.remotePaths.isNotEmpty) {
        _showUploadDone(result.remotePaths, remoteDirectory);
        _listUploadDirectory(
          remoteDirectory,
          isShellDirectory: remoteDirectory == shellDirectory,
        );
      }
    } on Object catch (error) {
      if (mounted) _showUploadError(error);
    } finally {
      await fileSystem?.close().catchError((_) {});
    }
  }

  void _showUploadError(Object error) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.terminalUploadFailed(localizeError(l10n, error))),
      ),
    );
  }

  /// Runs `ls` in the shell so the uploaded files show up right away. Skipped
  /// while a full-screen program such as vim owns the terminal, where the
  /// keystrokes would end up as input to that program.
  void _listUploadDirectory(
    String remoteDirectory, {
    required bool isShellDirectory,
  }) {
    if (!session.isRunning ||
        session.terminal.isUsingAltBuffer ||
        RegExp(r'[\r\n\u0000]').hasMatch(remoteDirectory)) {
      return;
    }
    session.sendCommand(
      isShellDirectory
          ? 'ls -la'
          : 'ls -la ${quoteForShell(remoteDirectory, widget.pane.profile.dialect)}',
    );
    _terminalViewKey.currentState?.requestKeyboard();
  }

  void _showUploadDone(List<String> remotePaths, String remoteDirectory) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.terminalUploadDone(remotePaths.length, remoteDirectory),
        ),
        action: SnackBarAction(
          label: l10n.terminalUploadInsertPath,
          onPressed: () {
            if (mounted) {
              _insertDroppedPaths(remotePaths, isLocalOnRemote: false);
            }
          },
        ),
      ),
    );
  }

  void _insertDroppedPaths(
    List<String> paths, {
    required bool isLocalOnRemote,
  }) {
    final input = droppedPathsInput(paths, widget.pane.profile.dialect);
    if (input.isEmpty) return;
    session.terminal.paste(input);
    _terminalViewKey.currentState?.requestKeyboard();
    if (isLocalOnRemote) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).terminalDropSshLocalPath),
        ),
      );
    }
  }

  Widget _compactIconButton({
    required Key key,
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
    Color? color,
    double size = 32,
  }) {
    return IconButton(
      key: key,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: BoxConstraints.tightFor(width: size, height: size),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      icon: Icon(icon, size: size < 32 ? 16 : 18, color: color),
    );
  }

  Widget _buildSearchBar() {
    final l10n = AppLocalizations.of(context);
    final resultText = _searchMatches.isEmpty
        ? l10n.terminalNoMatches
        : '${_activeSearchMatch + 1}/${_searchMatches.length}';
    return Container(
      key: _paneKey('terminal-search-bar'),
      color: TerminalMasterColors.surfaceRaised,
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: _paneKey('terminal-search-input'),
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: l10n.terminalSearchScrollback,
                isDense: true,
              ),
              onChanged: (_) => _runSearch(),
              onSubmitted: (_) => _nextSearchMatch(),
            ),
          ),
          const SizedBox(width: 8),
          Text(resultText, style: const TextStyle(fontSize: 11)),
          _compactIconButton(
            key: _paneKey('terminal-search-previous'),
            tooltip: l10n.terminalPreviousMatch,
            icon: Icons.keyboard_arrow_up,
            onPressed: _previousSearchMatch,
          ),
          _compactIconButton(
            key: _paneKey('terminal-search-next'),
            tooltip: l10n.terminalNextMatch,
            icon: Icons.keyboard_arrow_down,
            onPressed: _nextSearchMatch,
          ),
          _compactIconButton(
            key: _paneKey('terminal-search-close'),
            tooltip: l10n.terminalCloseSearch,
            icon: Icons.close,
            onPressed: () => widget.panelController.closeSearch(widget.pane.id),
          ),
        ],
      ),
    );
  }

  Widget _buildCommandHistory() {
    final l10n = AppLocalizations.of(context);
    final blocks = session.commandBlocks.reversed.toList();
    final savedCommands = widget.pane.savedCommands.reversed.toList();
    return Container(
      key: _paneKey('terminal-command-history'),
      height: 190,
      decoration: const BoxDecoration(
        color: TerminalMasterColors.surface,
        border: Border(bottom: BorderSide(color: TerminalMasterColors.border)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 34,
            child: Row(
              children: [
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.terminalCommandBlocks,
                    style: const TextStyle(
                      color: TerminalMasterColors.yellow,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${blocks.length + savedCommands.length}',
                  style: const TextStyle(fontSize: 10),
                ),
                _compactIconButton(
                  key: _paneKey('clear-command-history'),
                  tooltip: session.hasActiveCommand
                      ? l10n.terminalNotWhileRunning
                      : l10n.terminalClearCommandBlocks,
                  icon: Icons.delete_sweep_outlined,
                  onPressed: session.hasActiveCommand
                      ? null
                      : session.clearCommandBlocks,
                ),
              ],
            ),
          ),
          Expanded(
            child: blocks.isEmpty && savedCommands.isEmpty
                ? Center(
                    child: Text(
                      l10n.terminalNoCommandsYet,
                      style: const TextStyle(fontSize: 10),
                    ),
                  )
                : ListView(
                    children: [
                      if (savedCommands.isNotEmpty) ...[
                        _commandHistorySection(
                          title: l10n.terminalSavedCommands,
                          trailing: TextButton.icon(
                            key: _paneKey('run-all-saved-commands'),
                            onPressed: session.hasActiveCommand
                                ? null
                                : () => _executeAllSavedCommands(savedCommands),
                            icon: const Icon(Icons.playlist_play, size: 15),
                            label: Text(l10n.terminalFilterAll),
                          ),
                        ),
                        for (final command in savedCommands)
                          _buildSavedCommand(command),
                      ],
                      if (blocks.isNotEmpty) ...[
                        if (savedCommands.isNotEmpty)
                          _commandHistorySection(
                            title: l10n.terminalFilterCurrentSession,
                          ),
                        for (final block in blocks) _buildCommandBlock(block),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _commandHistorySection({required String title, Widget? trailing}) {
    return SizedBox(
      height: 30,
      child: Row(
        children: [
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: TerminalMasterColors.cyan,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildSavedCommand(SavedTerminalCommand command) {
    final l10n = AppLocalizations.of(context);
    final keySuffix =
        '${command.executedAt.microsecondsSinceEpoch}-'
        '${command.command.hashCode}';
    return ListTile(
      key: Key('saved-terminal-command-$keySuffix'),
      dense: true,
      contentPadding: const EdgeInsets.only(left: 8, right: 2),
      minLeadingWidth: 0,
      horizontalTitleGap: 0,
      title: Text(
        command.command,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 10),
      ),
      subtitle: Text(
        l10n.terminalSavedCommandSubtitle(
          _formatTimestamp(command.executedAt),
          '${command.exitCode ?? '?'}',
        ),
        style: const TextStyle(fontSize: 9),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: Key('run-saved-terminal-command-$keySuffix'),
            tooltip: l10n.terminalRunNow,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
            padding: EdgeInsets.zero,
            onPressed: session.hasActiveCommand
                ? null
                : () => _executeSavedCommand(command),
            icon: const Icon(Icons.play_arrow, size: 17),
          ),
          PopupMenuButton<String>(
            key: Key('saved-terminal-command-menu-$keySuffix'),
            tooltip: l10n.terminalMoreActionsShort,
            padding: EdgeInsets.zero,
            iconSize: 17,
            onSelected: (action) {
              switch (action) {
                case 'edit':
                  widget.panelController.stageSavedCommand(
                    widget.pane.id,
                    command.command,
                  );
                case 'copy':
                  Clipboard.setData(ClipboardData(text: command.command));
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'edit', child: Text(l10n.commonEdit)),
              PopupMenuItem(value: 'copy', child: Text(l10n.commonCopy)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _executeSavedCommand(SavedTerminalCommand command) async {
    final assessment = CommandRiskAssessor.assessRawCommands([
      command.command,
    ], containsRawConfiguration: false);
    if (assessment.requiresAcknowledgement) {
      final dialogContext = widget.navigatorKey.currentContext;
      if (dialogContext == null) return;
      final approved = await showCommandConfirmationDialog(
        dialogContext,
        commands: [command.command],
        assessment: assessment,
      );
      if (!approved) return;
    }
    try {
      await widget.panelController.executeSavedCommand(
        widget.pane.id,
        command.command,
      );
    } on Object catch (error) {
      _showCommandError(error);
    }
  }

  Future<void> _executeAllSavedCommands(
    List<SavedTerminalCommand> commands,
  ) async {
    final values = commands.reversed.map((command) => command.command).toList();
    final dialogContext = widget.navigatorKey.currentContext;
    if (dialogContext == null) return;
    final approved = await showCommandConfirmationDialog(
      dialogContext,
      commands: values,
      assessment: CommandRiskAssessor.assessRawCommands(
        values,
        containsRawConfiguration: false,
      ),
    );
    if (!approved) return;
    try {
      await widget.panelController.executeSavedCommands(widget.pane.id, values);
    } on Object catch (error) {
      _showCommandError(error);
    }
  }

  void _showCommandError(Object error) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.terminalRunFailed(localizeError(l10n, error))),
      ),
    );
  }

  String _formatTimestamp(DateTime value) {
    // Date order and the 12/24-hour choice are locale-dependent, so let intl
    // pick the pattern instead of hardcoding the German one.
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.Md(locale).add_jm().format(value.toLocal());
  }

  Widget _buildCommandBlock(TerminalCommandBlock block) {
    final l10n = AppLocalizations.of(context);
    final output = block.output;
    final displayedOutput = output.length > 10000
        ? '…\n${output.substring(output.length - 10000)}'
        : output;
    return Material(
      color: TerminalMasterColors.surface,
      child: ExpansionTile(
        key: Key('terminal-command-block-${block.id}'),
        dense: true,
        leading: Icon(
          _commandStatusIcon(block.status),
          size: 15,
          color: _commandStatusColor(block.status),
        ),
        title: Text(
          block.command,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10),
        ),
        subtitle: Text(
          '${_commandStatusText(block)} · ${_formatDuration(block.duration)}',
          style: const TextStyle(fontSize: 9),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 8, 8),
        children: [
          if (displayedOutput.isNotEmpty)
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 110),
              padding: const EdgeInsets.all(8),
              color: TerminalMasterColors.background,
              child: SingleChildScrollView(
                child: SelectableText(
                  displayedOutput,
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
          if (block.outputTruncated)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.terminalOutputTruncated(
                  TerminalCommandBlock.maxOutputLength,
                ),
                style: const TextStyle(
                  color: TerminalMasterColors.yellow,
                  fontSize: 9,
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: block.command)),
                icon: const Icon(Icons.copy, size: 13),
                label: Text(l10n.terminalLabelCommand),
              ),
              TextButton.icon(
                onPressed: output.isEmpty
                    ? null
                    : () => Clipboard.setData(ClipboardData(text: output)),
                icon: const Icon(Icons.content_copy, size: 13),
                label: Text(l10n.terminalLabelOutput),
              ),
              TextButton.icon(
                onPressed: () => _exportCommandBlock(block),
                icon: const Icon(Icons.save_alt, size: 13),
                label: Text(l10n.terminalExport),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _exportCommandBlock(TerminalCommandBlock block) async {
    final l10n = AppLocalizations.of(context);
    final path = await FilePicker.platform.saveFile(
      dialogTitle: l10n.terminalExportCommandBlock,
      fileName: 'terminal-command-${block.id}.md',
    );
    if (path == null) return;
    try {
      await File(path).writeAsString(block.toMarkdown());
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.terminalExportFailed(localizeError(l10n, error))),
        ),
      );
    }
  }

  String _commandStatusText(TerminalCommandBlock block) {
    final l10n = AppLocalizations.of(context);
    return switch (block.status) {
      TerminalCommandBlockStatus.running => l10n.terminalStatusRunningBlock,
      TerminalCommandBlockStatus.succeeded => l10n.terminalStatusSucceeded,
      TerminalCommandBlockStatus.failed => l10n.terminalStatusFailed(
        '${block.exitCode ?? '?'}',
      ),
      TerminalCommandBlockStatus.interrupted => l10n.terminalStatusInterrupted,
    };
  }

  IconData _commandStatusIcon(TerminalCommandBlockStatus status) {
    return switch (status) {
      TerminalCommandBlockStatus.running => Icons.pending,
      TerminalCommandBlockStatus.succeeded => Icons.check_circle_outline,
      TerminalCommandBlockStatus.failed => Icons.error_outline,
      TerminalCommandBlockStatus.interrupted => Icons.cancel_outlined,
    };
  }

  Color _commandStatusColor(TerminalCommandBlockStatus status) {
    return switch (status) {
      TerminalCommandBlockStatus.running => TerminalMasterColors.yellow,
      TerminalCommandBlockStatus.succeeded => TerminalMasterColors.green,
      TerminalCommandBlockStatus.failed => TerminalMasterColors.red,
      TerminalCommandBlockStatus.interrupted => TerminalMasterColors.muted,
    };
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds >= 60) {
      final minutes = duration.inMinutes;
      final seconds = duration.inSeconds.remainder(60);
      return '${minutes}m ${seconds}s';
    }
    if (duration.inMilliseconds >= 1000) {
      return '${(duration.inMilliseconds / 1000).toStringAsFixed(1)}s';
    }
    return '${duration.inMilliseconds}ms';
  }

  Future<void> _handleSecondaryTap(
    TapDownDetails details,
    CellOffset offset,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final localPosition = overlay.globalToLocal(details.globalPosition);
    final l10n = AppLocalizations.of(context);
    final selectionText = _selectedText();
    final link = _linkAt(offset);
    final action = await showMenu<_TerminalMenuAction>(
      context: context,
      position: RelativeRect.fromRect(
        localPosition & Size.zero,
        Offset.zero & overlay.size,
      ),
      items: [
        if (link != null)
          PopupMenuItem(
            value: _TerminalMenuAction.openLink,
            child: ListTile(
              leading: const Icon(Icons.open_in_new),
              title: Text(l10n.terminalOpenLink),
            ),
          ),
        PopupMenuItem(
          value: _TerminalMenuAction.copy,
          enabled: selectionText != null,
          child: ListTile(
            leading: const Icon(Icons.copy_outlined),
            title: Text(l10n.commonCopy),
          ),
        ),
        PopupMenuItem(
          value: _TerminalMenuAction.paste,
          child: ListTile(
            leading: const Icon(Icons.paste_outlined),
            title: Text(l10n.commonPaste),
          ),
        ),
        PopupMenuItem(
          value: _TerminalMenuAction.selectAll,
          child: ListTile(
            leading: const Icon(Icons.select_all),
            title: Text(l10n.terminalSelectAll),
          ),
        ),
        PopupMenuItem(
          value: _TerminalMenuAction.searchSelection,
          enabled: selectionText != null,
          child: ListTile(
            leading: const Icon(Icons.search),
            title: Text(l10n.terminalSearchSelection),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _TerminalMenuAction.clearOutput,
          child: ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: Text(l10n.terminalClearOutput),
          ),
        ),
      ],
    );
    if (!mounted || action == null) return;

    switch (action) {
      case _TerminalMenuAction.openLink:
        if (link != null) await _openLink(link);
        break;
      case _TerminalMenuAction.copy:
        if (selectionText != null) {
          await Clipboard.setData(ClipboardData(text: selectionText));
        }
        break;
      case _TerminalMenuAction.paste:
        final data = await Clipboard.getData('text/plain');
        if (data?.text case final text?) await _paste(text);
        break;
      case _TerminalMenuAction.selectAll:
        _selectAll();
        break;
      case _TerminalMenuAction.searchSelection:
        if (selectionText != null) _searchForSelection(selectionText);
        break;
      case _TerminalMenuAction.clearOutput:
        _clearOutput();
        break;
    }
  }

  void _handleTerminalTap(TapUpDetails details, CellOffset offset) {
    final isShortcut =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (!isShortcut) return;
    final link = _linkAt(offset);
    if (link != null) _openLink(link);
  }

  String? _selectedText() {
    final selection = _terminalController.selection;
    if (selection == null) return null;
    final text = session.terminal.buffer.getText(selection);
    return text.isEmpty ? null : text;
  }

  Uri? _linkAt(CellOffset offset) {
    final oscLink = session.hyperlinkAt(offset);
    if (oscLink != null && ExternalUrlLauncher.isSupported(oscLink)) {
      return oscLink;
    }
    if (offset.y < 0 || offset.y >= session.terminal.buffer.height) return null;

    final line = _readLine(session.terminal.buffer.lines[offset.y]);
    final pattern = RegExp(r'''(?:https?://|mailto:)[^\s<>"']+''');
    for (final match in pattern.allMatches(line.text)) {
      var value = match.group(0)!;
      while (value.isNotEmpty && '.,;:)]}'.contains(value[value.length - 1])) {
        value = value.substring(0, value.length - 1);
      }
      final begin = line.columns[match.start];
      final end = line.columns[match.start + value.length];
      if (begin != null && end != null && offset.x >= begin && offset.x < end) {
        final uri = Uri.tryParse(value);
        if (uri != null && ExternalUrlLauncher.isSupported(uri)) return uri;
      }
    }
    return null;
  }

  Future<void> _openLink(Uri uri) async {
    try {
      await ExternalUrlLauncher.open(uri);
    } on Object catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.terminalOpenLinkFailed(localizeError(l10n, error)),
          ),
        ),
      );
    }
  }

  void _selectAll() {
    final buffer = session.terminal.buffer;
    if (buffer.height == 0) return;
    final lastLine = buffer.lines[buffer.height - 1];
    _terminalController.setSelection(
      buffer.createAnchor(0, 0),
      buffer.createAnchor(lastLine.getTrimmedLength(), buffer.height - 1),
    );
  }

  void _searchForSelection(String selection) {
    final query = selection.trim().split(RegExp(r'[\r\n]')).first;
    if (query.isEmpty) return;
    _searchController.text = query;
    widget.panelController.openSearch(widget.pane.id);
    _runSearch();
  }

  void _clearOutput() {
    _terminalController.clearSelection();
    _clearSearchHighlights();
    session.terminal.write('\x1b[2J\x1b[3J\x1b[H');
    if (_searchController.text.isNotEmpty) _runSearch();
  }

  KeyEventResult _handleTerminalKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final isShortcut =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    if (isShortcut && key == LogicalKeyboardKey.keyF) {
      widget.panelController.openSearch(widget.pane.id);
      return KeyEventResult.handled;
    }
    if (isShortcut &&
        (key == LogicalKeyboardKey.equal || key == LogicalKeyboardKey.add)) {
      widget.panelController.zoomIn();
      return KeyEventResult.handled;
    }
    if (isShortcut &&
        (key == LogicalKeyboardKey.minus ||
            key == LogicalKeyboardKey.numpadSubtract)) {
      widget.panelController.zoomOut();
      return KeyEventResult.handled;
    }
    if (isShortcut &&
        (key == LogicalKeyboardKey.digit0 ||
            key == LogicalKeyboardKey.numpad0)) {
      widget.panelController.resetZoom();
      return KeyEventResult.handled;
    }
    if (isShortcut && key == LogicalKeyboardKey.keyV) {
      Clipboard.getData('text/plain').then((data) {
        if (data?.text case final text?) _paste(text);
      });
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final isAtBottom = _scrollController.position.extentAfter <= 1;
    if (_isAtBottom != isAtBottom && mounted) {
      setState(() => _isAtBottom = isAtBottom);
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  void _scheduleSearchRefresh() {
    if (_searchController.text.isEmpty || _searchRefreshScheduled) return;
    _searchRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchRefreshScheduled = false;
      if (mounted) _runSearch(preserveActiveMatch: true);
    });
  }

  void _runSearch({bool preserveActiveMatch = false}) {
    final previousMatch =
        preserveActiveMatch &&
            _activeSearchMatch >= 0 &&
            _activeSearchMatch < _searchMatches.length
        ? _searchMatches[_activeSearchMatch]
        : null;
    _clearSearchHighlights();
    final query = _searchController.text;
    final matches = query.isEmpty ? <_TerminalSearchMatch>[] : _find(query);
    var activeMatch = matches.isEmpty ? -1 : 0;
    if (previousMatch != null) {
      final previousIndex = matches.indexOf(previousMatch);
      if (previousIndex >= 0) activeMatch = previousIndex;
    }
    for (var index = 0; index < matches.length; index++) {
      final match = matches[index];
      _searchHighlights.add(
        _terminalController.highlight(
          p1: session.terminal.buffer.createAnchorFromOffset(match.begin),
          p2: session.terminal.buffer.createAnchorFromOffset(match.end),
          color: index == activeMatch
              ? const Color(0xaaff8b3d)
              : const Color(0x77ffc857),
        ),
      );
    }
    if (!mounted) return;
    setState(() {
      _searchMatches = matches;
      _activeSearchMatch = activeMatch;
    });
    if (activeMatch >= 0) _scrollToSearchMatch(matches[activeMatch]);
  }

  List<_TerminalSearchMatch> _find(String query) {
    final matches = <_TerminalSearchMatch>[];
    final normalizedQuery = query.toLowerCase();
    final buffer = session.terminal.buffer;
    for (var y = 0; y < buffer.height; y++) {
      final line = _readLine(buffer.lines[y]);
      final value = line.text;
      final normalizedValue = value.toLowerCase();
      if (normalizedValue.length != value.length) continue;
      var start = 0;
      while (start <= normalizedValue.length - normalizedQuery.length) {
        final index = normalizedValue.indexOf(normalizedQuery, start);
        if (index < 0) break;
        final beginColumn = line.columns[index];
        final endColumn = line.columns[index + normalizedQuery.length];
        if (beginColumn != null && endColumn != null) {
          matches.add(
            _TerminalSearchMatch(
              CellOffset(beginColumn, y),
              CellOffset(endColumn, y),
            ),
          );
        }
        start = index + normalizedQuery.length;
      }
    }
    return matches;
  }

  _TerminalLineText _readLine(BufferLine line) {
    final text = StringBuffer();
    final columns = <int, int>{0: 0};
    for (var x = 0; x < line.length; x++) {
      final codePoint = line.getCodePoint(x);
      if (codePoint == 0) continue;
      columns[text.length] = x;
      text.writeCharCode(codePoint);
      columns[text.length] = x + line.getWidth(x).clamp(1, 2);
    }
    return _TerminalLineText(text.toString(), columns);
  }

  void _nextSearchMatch() => _activateSearchMatch(1);

  void _previousSearchMatch() => _activateSearchMatch(-1);

  void _activateSearchMatch(int direction) {
    if (_searchMatches.isEmpty) return;
    final next = (_activeSearchMatch + direction) % _searchMatches.length;
    _activeSearchMatch = next < 0 ? next + _searchMatches.length : next;
    _runSearch(preserveActiveMatch: true);
  }

  void _scrollToSearchMatch(_TerminalSearchMatch match) {
    if (!_scrollController.hasClients) return;
    final lineHeight =
        _terminalViewKey.currentState?.renderTerminal.lineHeight ??
        widget.panelController.fontSize * 1.2;
    final viewportHeight = _scrollController.position.viewportDimension;
    final target = match.begin.y * lineHeight - viewportHeight / 2;
    _scrollController.jumpTo(
      target.clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      ),
    );
  }

  void _clearSearchHighlights() {
    for (final highlight in _searchHighlights) {
      highlight.dispose();
    }
    _searchHighlights.clear();
  }

  Future<void> _paste(String text) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    if (text.contains('\n') || text.contains('\r')) {
      final dialogContext = widget.navigatorKey.currentContext;
      if (dialogContext == null) return;
      final approved =
          await showDialog<bool>(
            context: dialogContext,
            builder: (context) => AlertDialog(
              icon: const Icon(Icons.warning_amber_rounded),
              title: Text(l10n.terminalPasteMultilineTitle),
              content: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 640,
                  maxHeight: 360,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.terminalPasteMultilineMessage),
                    const SizedBox(height: 12),
                    Flexible(
                      child: SingleChildScrollView(child: SelectableText(text)),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.commonCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l10n.commonPaste),
                ),
              ],
            ),
          ) ??
          false;
      if (!approved || !mounted) return;
    }
    session.terminal.paste(text);
  }

  String _statusText(TerminalSession session) {
    final l10n = AppLocalizations.of(context);
    return switch (session.status) {
      TerminalSessionStatus.idle => l10n.terminalStatusReady,
      TerminalSessionStatus.starting => l10n.terminalStatusStarting,
      TerminalSessionStatus.running => l10n.terminalStatusActive,
      TerminalSessionStatus.exited => l10n.terminalStatusExited(
        '${session.exitCode ?? l10n.terminalExitCodeUnknown}',
      ),
      TerminalSessionStatus.failed => l10n.terminalStatusStartFailed(
        '${session.error}',
      ),
    };
  }

  String _statusTitle() {
    if (session.status == TerminalSessionStatus.exited ||
        session.status == TerminalSessionStatus.failed) {
      return _statusText(session);
    }
    return session.title ?? _statusText(session);
  }

  String _sessionDetails() {
    final directory = session.workingDirectory;
    return directory == null
        ? session.shellName
        : '${session.shellName} · $directory';
  }

  String _statusTooltip() {
    final l10n = AppLocalizations.of(context);
    final details = <String>[
      _statusTitle(),
      l10n.terminalInfoShell(session.shellName),
      if (session.workingDirectory case final directory?)
        l10n.terminalInfoDirectory(directory),
      l10n.terminalInfoStatus(_statusText(session)),
    ];
    return details.join('\n');
  }

  Key _paneKey(String value) =>
      widget.panelController.activePane.id == widget.pane.id
      ? Key(value)
      : Key('$value-${widget.pane.id}');

  IconData _statusIcon(TerminalSessionStatus status) {
    return switch (status) {
      TerminalSessionStatus.idle => Icons.circle_outlined,
      TerminalSessionStatus.starting => Icons.pending,
      TerminalSessionStatus.running => Icons.circle,
      TerminalSessionStatus.exited => Icons.stop_circle_outlined,
      TerminalSessionStatus.failed => Icons.error_outline,
    };
  }

  Color _statusColor(TerminalSessionStatus status) {
    return switch (status) {
      TerminalSessionStatus.idle => Colors.blueGrey,
      TerminalSessionStatus.starting => Colors.amber,
      TerminalSessionStatus.running => TerminalMasterColors.green,
      TerminalSessionStatus.exited => Colors.blueGrey,
      TerminalSessionStatus.failed => Colors.redAccent,
    };
  }
}

class _TerminalSearchMatch {
  final CellOffset begin;
  final CellOffset end;

  const _TerminalSearchMatch(this.begin, this.end);

  @override
  bool operator ==(Object other) =>
      other is _TerminalSearchMatch && begin == other.begin && end == other.end;

  @override
  int get hashCode => Object.hash(begin, end);
}

class _TerminalLineText {
  final String text;
  final Map<int, int> columns;

  const _TerminalLineText(this.text, this.columns);
}

enum _TerminalMenuAction {
  openLink,
  copy,
  paste,
  selectAll,
  searchSelection,
  clearOutput,
}
