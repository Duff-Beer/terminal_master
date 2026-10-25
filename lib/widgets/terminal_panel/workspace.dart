part of '../terminal_panel.dart';

class _SavedTabMenuAction {
  final String snapshotId;
  final bool delete;

  const _SavedTabMenuAction.open(this.snapshotId) : delete = false;
  const _SavedTabMenuAction.delete(this.snapshotId) : delete = true;
}

class TerminalPanelScope extends InheritedNotifier<TerminalPanelController> {
  const TerminalPanelScope({
    super.key,
    required TerminalPanelController controller,
    required super.child,
  }) : super(notifier: controller);

  static TerminalPanelController of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'TerminalPanelScope fehlt im Widget-Baum.');
    return scope!;
  }

  static TerminalPanelController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<TerminalPanelScope>()
        ?.notifier;
  }
}

enum WorkspaceTool { configurations, sshConnections, settings }

class ConfigurationPanelController extends ChangeNotifier {
  bool _isOpen = false;
  WorkspaceTool _activeTool = WorkspaceTool.configurations;

  bool get isOpen => _isOpen;
  WorkspaceTool get activeTool => _activeTool;

  void open([WorkspaceTool tool = WorkspaceTool.configurations]) {
    if (_isOpen && _activeTool == tool) return;
    _activeTool = tool;
    _isOpen = true;
    notifyListeners();
  }

  void close() {
    if (!_isOpen) return;
    _isOpen = false;
    notifyListeners();
  }

  void toggle([WorkspaceTool tool = WorkspaceTool.configurations]) {
    if (_isOpen && _activeTool == tool) {
      close();
    } else {
      open(tool);
    }
  }
}

class ConfigurationPanelScope
    extends InheritedNotifier<ConfigurationPanelController> {
  const ConfigurationPanelScope({
    super.key,
    required ConfigurationPanelController controller,
    required super.child,
  }) : super(notifier: controller);

  static ConfigurationPanelController of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'ConfigurationPanelScope fehlt im Widget-Baum.');
    return scope!;
  }

  static ConfigurationPanelController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ConfigurationPanelScope>()
        ?.notifier;
  }
}

class TerminalWorkspace extends StatefulWidget {
  final TerminalBackendFactory backendFactory;
  final GlobalKey<NavigatorState> navigatorKey;
  final List<ShellProfile>? profiles;
  final SavedTerminalTabStore? savedTabStore;
  final bool commandBarPinned;
  final Future<void> Function(bool pinned)? saveCommandBarPinned;
  final String terminalFontFamily;
  final Future<void> Function(String fontFamily)? saveTerminalFontFamily;
  final Widget? sshPanel;
  final Widget? settingsPanel;
  final Widget child;

  const TerminalWorkspace({
    super.key,
    required this.backendFactory,
    required this.navigatorKey,
    this.profiles,
    this.savedTabStore,
    this.commandBarPinned = false,
    this.saveCommandBarPinned,
    this.terminalFontFamily = 'monospace',
    this.saveTerminalFontFamily,
    this.sshPanel,
    this.settingsPanel,
    required this.child,
  });

  @override
  State<TerminalWorkspace> createState() => _TerminalWorkspaceState();
}

class _TerminalWorkspaceState extends State<TerminalWorkspace> {
  late final TerminalPanelController _controller;
  late final ConfigurationPanelController _configurationController;
  final _configurationFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TerminalPanelController(
      backendFactory: widget.backendFactory,
      navigatorKey: widget.navigatorKey,
      profiles: widget.profiles,
      savedTabStore: widget.savedTabStore ?? MemorySavedTerminalTabStore(),
      commandBarPinned: widget.commandBarPinned,
      saveCommandBarPinned: widget.saveCommandBarPinned,
      terminalFontFamily: widget.terminalFontFamily,
      saveTerminalFontFamily: widget.saveTerminalFontFamily,
    );
    _configurationController = ConfigurationPanelController()
      ..addListener(_handleConfigurationVisibility);
    unawaited(_controller.attach());
  }

  void _handleConfigurationVisibility() {
    if (!_configurationController.isOpen) return;
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _configurationController.isOpen) {
        _configurationFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _configurationController
      ..removeListener(_handleConfigurationVisibility)
      ..dispose();
    _configurationFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TerminalPanelScope(
      controller: _controller,
      child: ConfigurationPanelScope(
        controller: _configurationController,
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyB, control: true):
                _configurationController.toggle,
            const SingleActivator(LogicalKeyboardKey.keyB, meta: true):
                _configurationController.toggle,
            const SingleActivator(LogicalKeyboardKey.escape): () {
              if (_configurationController.isOpen) {
                _configurationController.close();
              }
            },
          },
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _controller,
              _configurationController,
            ]),
            builder: (context, child) => Row(
              children: [
                _ConfigurationToolRail(
                  controller: _configurationController,
                  hasSshPanel: widget.sshPanel != null,
                  hasSettingsPanel: widget.settingsPanel != null,
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final drawerWidth = constraints.maxWidth < 640
                          ? constraints.maxWidth
                          : 420.0;
                      return Stack(
                        children: [
                          Positioned.fill(
                            child: SizedBox(
                              key: const Key('terminal-workspace'),
                              child: Material(
                                color: TerminalMasterColors.background,
                                child: TerminalPanel(controller: _controller),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              ignoring: !_configurationController.isOpen,
                              child: GestureDetector(
                                key: const Key('configuration-panel-barrier'),
                                behavior: HitTestBehavior.opaque,
                                onTap: _configurationController.close,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            bottom: 0,
                            left: 0,
                            width: drawerWidth,
                            child: ClipRect(
                              child: AnimatedSlide(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOutCubic,
                                offset: _configurationController.isOpen
                                    ? Offset.zero
                                    : const Offset(-1, 0),
                                child: IgnorePointer(
                                  ignoring: !_configurationController.isOpen,
                                  child: Focus(
                                    focusNode: _configurationFocusNode,
                                    child: Material(
                                      key: const Key('configuration-panel'),
                                      color: TerminalMasterColors.surface,
                                      elevation: 16,
                                      shadowColor: Colors.black87,
                                      child: IndexedStack(
                                        index: switch (_configurationController
                                            .activeTool) {
                                          WorkspaceTool.configurations => 0,
                                          WorkspaceTool.sshConnections => 1,
                                          WorkspaceTool.settings => 2,
                                        },
                                        children: [
                                          KeyedSubtree(
                                            key: const Key(
                                              'configuration-tool-content',
                                            ),
                                            child: widget.child,
                                          ),
                                          KeyedSubtree(
                                            key: const Key('ssh-tool-content'),
                                            child:
                                                widget.sshPanel ??
                                                const SizedBox.shrink(),
                                          ),
                                          KeyedSubtree(
                                            key: const Key(
                                              'settings-tool-content',
                                            ),
                                            child:
                                                widget.settingsPanel ??
                                                const SizedBox.shrink(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfigurationToolRail extends StatelessWidget {
  final ConfigurationPanelController controller;
  final bool hasSshPanel;
  final bool hasSettingsPanel;

  const _ConfigurationToolRail({
    required this.controller,
    required this.hasSshPanel,
    required this.hasSettingsPanel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      key: const Key('workspace-tool-rail'),
      width: 48,
      child: ColoredBox(
        color: TerminalMasterColors.surfaceRaised,
        child: Column(
          children: [
            _buildButton(
              key: const Key('configuration-panel-toggle'),
              tool: WorkspaceTool.configurations,
              icon: Icons.tune,
              tooltip: l10n.mainTitle,
              l10n: l10n,
            ),
            if (hasSshPanel)
              _buildButton(
                key: const Key('ssh-panel-toggle'),
                tool: WorkspaceTool.sshConnections,
                icon: Icons.dns_outlined,
                tooltip: l10n.sshPageTitle,
                l10n: l10n,
              ),
            if (hasSettingsPanel) const Spacer(),
            if (hasSettingsPanel)
              _buildButton(
                key: const Key('settings-panel-toggle'),
                tool: WorkspaceTool.settings,
                icon: Icons.settings_outlined,
                tooltip: l10n.settingsTitle,
                l10n: l10n,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton({
    required Key key,
    required WorkspaceTool tool,
    required IconData icon,
    required String tooltip,
    required AppLocalizations l10n,
  }) {
    final isActive = controller.isOpen && controller.activeTool == tool;
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        children: [
          if (isActive)
            Positioned(
              left: 0,
              top: 8,
              bottom: 8,
              child: Container(
                key: ValueKey('workspace-tool-indicator-${tool.name}'),
                width: 3,
                color: TerminalMasterColors.green,
              ),
            ),
          Positioned.fill(
            child: IconButton(
              key: key,
              tooltip: isActive ? l10n.railClose(tooltip) : tooltip,
              onPressed: () => controller.toggle(tool),
              icon: Icon(
                icon,
                color: isActive ? TerminalMasterColors.green : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TerminalPanel extends StatefulWidget {
  final TerminalPanelController controller;

  const TerminalPanel({super.key, required this.controller});

  @override
  State<TerminalPanel> createState() => _TerminalPanelState();
}

class _TerminalPanelState extends State<TerminalPanel> {
  final _commandFocusNode = FocusNode();
  TextEditingController? _observedCommandController;

  TerminalPanelController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _commandFocusNode.addListener(_handleCommandFocusChange);
    _syncCommandController();
  }

  @override
  void didUpdateWidget(covariant TerminalPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) _syncCommandController();
  }

  @override
  void dispose() {
    _observedCommandController?.removeListener(_handleCommandTextChange);
    _commandFocusNode
      ..removeListener(_handleCommandFocusChange)
      ..dispose();
    super.dispose();
  }

  void _syncCommandController() {
    final commandController = controller.commandController;
    if (identical(commandController, _observedCommandController)) return;
    _observedCommandController?.removeListener(_handleCommandTextChange);
    _observedCommandController = commandController
      ..addListener(_handleCommandTextChange);
  }

  void _handleCommandTextChange() {
    if (mounted) setState(() {});
  }

  void _handleCommandFocusChange() {
    if (mounted) setState(() {});
  }

  bool get _shouldShowCommandBar =>
      controller.commandBarPinned ||
      controller.commandController.text.trim().isNotEmpty ||
      _commandFocusNode.hasFocus;

  void _toggleCommandBarPinned() {
    final shouldPin = !controller.commandBarPinned;
    unawaited(
      controller.setCommandBarPinned(shouldPin).catchError((Object error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.toString())));
        }
      }),
    );
    if (shouldPin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && controller.commandBarPinned) {
          _commandFocusNode.requestFocus();
        }
      });
    } else {
      _commandFocusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    _syncCommandController();
    final l10n = AppLocalizations.of(context);
    final pane = controller.activePane;
    return Column(
      children: [
        _buildTabBar(context),
        Expanded(child: _buildPanes()),
        AnimatedSize(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.bottomCenter,
          child: _shouldShowCommandBar
              ? Container(
                  key: const Key('terminal-bottom-toolbar'),
                  padding: const EdgeInsets.fromLTRB(10, 8, 6, 10),
                  decoration: const BoxDecoration(
                    color: TerminalMasterColors.surface,
                    border: Border(
                      top: BorderSide(color: TerminalMasterColors.border),
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) => Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('terminal-command-input'),
                            controller: controller.commandController,
                            focusNode: _commandFocusNode,
                            minLines: 1,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: l10n.terminalCommandHint(
                                controller.activeProfile.name,
                              ),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton.filled(
                          key: const Key('send-terminal-input'),
                          tooltip: l10n.terminalSendToTerminal,
                          style: IconButton.styleFrom(
                            backgroundColor: TerminalMasterColors.green,
                            foregroundColor: TerminalMasterColors.background,
                          ),
                          onPressed: controller.sendPending,
                          icon: const Icon(Icons.send_rounded),
                        ),
                        if (constraints.maxWidth < 560) ...[
                          const SizedBox(width: 6),
                          _buildCompactActions(context, pane),
                        ],
                      ],
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _buildCompactActions(BuildContext context, TerminalPaneData pane) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      key: const Key('terminal-more-actions'),
      tooltip: l10n.terminalMoreActions,
      onSelected: (action) {
        switch (action) {
          case 'restart':
            _confirmRestart(context, pane);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'restart',
          child: ListTile(
            leading: const Icon(Icons.restart_alt),
            title: Text(l10n.terminalRestartSession),
          ),
        ),
      ],
      icon: const Icon(Icons.more_vert),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      key: const Key('terminal-tab-bar'),
      height: 40,
      decoration: const BoxDecoration(
        color: TerminalMasterColors.surface,
        border: Border(bottom: BorderSide(color: TerminalMasterColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ...controller.tabs.map((tab) {
                  final selected = controller.activeTab.id == tab.id;
                  final pane = tab.activePane;
                  return Padding(
                    padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
                    child: Material(
                      color: selected
                          ? TerminalMasterColors.surfaceRaised
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      child: InkWell(
                        key: Key('terminal-tab-${tab.id}'),
                        onTap: () => controller.selectTab(tab.id),
                        onSecondaryTapDown: (details) => _showTabContextMenu(
                          context,
                          tab,
                          details.globalPosition,
                        ),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _tabStatusIcon(pane.session.status),
                                size: 11,
                                color: _tabStatusColor(pane.session.status),
                              ),
                              const SizedBox(width: 5),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 120,
                                ),
                                child: Tooltip(
                                  message: tab.displayName,
                                  child: Text(
                                    tab.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: selected
                                          ? TerminalMasterColors.yellow
                                          : TerminalMasterColors.foreground,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: l10n.terminalCloseTabHint,
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints.tightFor(
                                  width: 28,
                                  height: 28,
                                ),
                                padding: EdgeInsets.zero,
                                onPressed: controller.tabs.length == 1
                                    ? null
                                    : () => _confirmClose(context, tab),
                                icon: const Icon(Icons.close, size: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                IconButton(
                  key: const Key('new-terminal-tab'),
                  tooltip: l10n.terminalNewTab,
                  icon: const Icon(Icons.add, size: 19),
                  onPressed: controller.createDefaultTab,
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('toggle-command-bar-pinned'),
            tooltip: controller.commandBarPinned
                ? l10n.terminalUseAutomaticCommandBar
                : l10n.terminalPinCommandBar,
            onPressed: _toggleCommandBarPinned,
            icon: Icon(
              controller.commandBarPinned
                  ? Icons.keyboard_hide_outlined
                  : Icons.keyboard_alt_outlined,
            ),
          ),
          IconButton(
            key: const Key('terminal-search-toggle'),
            tooltip: controller.isSearchOpen
                ? l10n.terminalCloseSearch
                : l10n.terminalSearch,
            onPressed: controller.toggleSearch,
            icon: Icon(
              controller.isSearchOpen ? Icons.search_off : Icons.search,
            ),
          ),
          PopupMenuButton<_SavedTabMenuAction>(
            key: const Key('open-saved-terminal-tab'),
            tooltip: l10n.terminalOpenSavedTab,
            enabled: !controller.isLoadingSavedTabs,
            icon: Icon(
              Icons.folder_open_outlined,
              size: 19,
              color: controller.savedTabsError == null
                  ? null
                  : Theme.of(context).colorScheme.error,
            ),
            onSelected: (action) {
              if (action.delete) {
                unawaited(_confirmDeleteSavedTab(context, action.snapshotId));
              } else {
                _openSavedTab(context, action.snapshotId);
              }
            },
            itemBuilder: (context) {
              if (controller.savedTabsError case final error?) {
                return [
                  PopupMenuItem<_SavedTabMenuAction>(
                    enabled: false,
                    child: Text(localizeError(l10n, error)),
                  ),
                ];
              }
              if (controller.savedTabs.isEmpty) {
                return [
                  PopupMenuItem<_SavedTabMenuAction>(
                    enabled: false,
                    child: Text(l10n.terminalNoSavedTabs),
                  ),
                ];
              }
              return [
                for (final snapshot in controller.savedTabs) ...[
                  PopupMenuItem<_SavedTabMenuAction>(
                    value: _SavedTabMenuAction.open(snapshot.id),
                    child: Text(snapshot.name),
                  ),
                  PopupMenuItem<_SavedTabMenuAction>(
                    key: Key('delete-saved-terminal-tab-${snapshot.id}'),
                    value: _SavedTabMenuAction.delete(snapshot.id),
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.terminalDeleteSavedTab,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ];
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPanes() {
    return Stack(
      children: [
        for (final tab in controller.tabs)
          Positioned.fill(
            child: Offstage(
              offstage: tab.id != controller.activeTab.id,
              child: _buildLayoutNode(
                tab,
                tab.maximizedPaneId == null
                    ? tab.layout
                    : TerminalLayoutPane(tab.maximizedPaneId!),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLayoutNode(TerminalTab tab, TerminalLayoutNode node) {
    if (node case TerminalLayoutPane(:final paneId)) {
      final pane = tab.panes.firstWhere((candidate) => candidate.id == paneId);
      final isMaximized =
          tab.maximizedPaneId == null || tab.maximizedPaneId == pane.id;
      return Offstage(
        offstage: !isMaximized,
        child: IgnorePointer(
          ignoring: !isMaximized,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => controller.focusPane(pane.id),
            child: DecoratedBox(
              key: Key('terminal-pane-position-${pane.id}'),
              decoration: BoxDecoration(
                border: Border.all(
                  color: controller.activePane.id == pane.id
                      ? TerminalMasterColors.green
                      : Colors.transparent,
                ),
              ),
              child: TerminalPane(
                key: ValueKey(pane.session),
                pane: pane,
                panelController: controller,
                navigatorKey: controller.navigatorKey,
              ),
            ),
          ),
        ),
      );
    }
    final split = node as TerminalLayoutSplit;
    final isVertical = split.orientation == TerminalSplitOrientation.vertical;
    return LayoutBuilder(
      builder: (context, constraints) {
        final extent = isVertical
            ? constraints.maxWidth
            : constraints.maxHeight;
        final firstPaneId = split.first.paneIds.first;
        final secondPaneId = split.second.paneIds.first;
        return Flex(
          direction: isVertical ? Axis.horizontal : Axis.vertical,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: (split.ratio * 1000).round().clamp(1, 999),
              child: _buildLayoutNode(tab, split.first),
            ),
            MouseRegion(
              key: Key(
                'terminal-split-divider-cursor-$firstPaneId-$secondPaneId',
              ),
              cursor: isVertical
                  ? SystemMouseCursors.resizeLeftRight
                  : SystemMouseCursors.resizeUpDown,
              child: GestureDetector(
                key: Key('terminal-split-divider-$firstPaneId-$secondPaneId'),
                behavior: HitTestBehavior.opaque,
                onPanUpdate: extent.isFinite && extent > 0
                    ? (details) => controller.resizeSplit(
                        firstPaneId,
                        secondPaneId,
                        (isVertical ? details.delta.dx : details.delta.dy) /
                            extent,
                      )
                    : null,
                child: SizedBox(
                  width: isVertical ? 8 : null,
                  height: isVertical ? null : 8,
                  child: const ColoredBox(color: TerminalMasterColors.border),
                ),
              ),
            ),
            Expanded(
              flex: ((1 - split.ratio) * 1000).round().clamp(1, 999),
              child: _buildLayoutNode(tab, split.second),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveTab(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    var enteredName =
        controller.activeTab.customName ??
        controller.activeTab.snapshotName ??
        controller.activePane.session.title ??
        controller.activeProfile.name;
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          controller.activeTab.snapshotId == null
              ? l10n.terminalSaveTabTitle
              : l10n.terminalUpdateSavedTab,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              key: const Key('saved-terminal-tab-name'),
              initialValue: enteredName,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.commonName),
              onChanged: (value) => enteredName = value,
              onFieldSubmitted: (value) {
                if (value.trim().isNotEmpty) Navigator.pop(context, value);
              },
            ),
            const SizedBox(height: 12),
            Text(
              l10n.terminalSaveTabNote,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            key: const Key('confirm-save-terminal-tab'),
            onPressed: () {
              final value = enteredName.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    if (name == null || !context.mounted) return;
    try {
      await controller.saveActiveTab(name);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.terminalTabSaved(name))));
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.terminalSaveFailed(localizeError(l10n, error))),
        ),
      );
    }
  }

  Future<void> _confirmDeleteSavedTab(
    BuildContext context,
    String snapshotId,
  ) async {
    final l10n = AppLocalizations.of(context);
    final snapshot = controller.savedTabs
        .where((candidate) => candidate.id == snapshotId)
        .firstOrNull;
    if (snapshot == null) return;
    final dialogContext = controller.navigatorKey.currentContext ?? context;
    final confirmed = await showDialog<bool>(
      context: dialogContext,
      builder: (context) => AlertDialog(
        title: Text(l10n.terminalDeleteSavedTabTitle),
        content: Text(l10n.terminalDeleteSavedTabMessage(snapshot.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            key: const Key('confirm-delete-saved-terminal-tab'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await controller.deleteSavedTab(snapshotId);
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(localizeError(l10n, error))));
    }
  }

  Future<void> _openSavedTab(BuildContext context, String snapshotId) async {
    final l10n = AppLocalizations.of(context);
    final snapshot = controller.savedTabs.firstWhere(
      (snapshot) => snapshot.id == snapshotId,
    );
    final commands = snapshot.panes
        .expand((pane) => pane.commands)
        .map((command) => command.command)
        .toList();
    var executeCommands = false;
    final dialogContext = controller.navigatorKey.currentContext ?? context;
    final openWithCommands = await showDialog<bool>(
      context: dialogContext,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.terminalOpenSnapshotTitle(snapshot.name)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.terminalSnapshotSummary(
                  snapshot.panes.length,
                  commands.length,
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                key: const Key('execute-saved-commands-on-open'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(l10n.terminalRunSavedCommands),
                subtitle: Text(l10n.terminalRunSavedCommandsNote),
                value: executeCommands,
                onChanged: commands.isEmpty
                    ? null
                    : (value) => setDialogState(
                        () => executeCommands = value ?? false,
                      ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              key: const Key('confirm-open-saved-terminal-tab'),
              onPressed: () => Navigator.pop(context, executeCommands),
              child: Text(l10n.commonOpen),
            ),
          ],
        ),
      ),
    );
    if (openWithCommands == null || !context.mounted) return;
    if (openWithCommands) {
      final approved = await showCommandConfirmationDialog(
        dialogContext,
        commands: commands,
        assessment: CommandRiskAssessor.assessRawCommands(
          commands,
          containsRawConfiguration: false,
        ),
      );
      if (!approved || !context.mounted) return;
    }
    try {
      final tab = await controller.openSavedTab(snapshotId);
      if (!context.mounted) return;
      if (openWithCommands) {
        unawaited(_executeOpenedSavedTab(context, tab.id));
      }
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.terminalOpenFailed(localizeError(l10n, error))),
        ),
      );
    }
  }

  Future<void> _executeOpenedSavedTab(
    BuildContext context,
    String tabId,
  ) async {
    try {
      await controller.executeSavedTabCommands(tabId);
    } on Object catch (error) {
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.terminalAutoRunFailed(localizeError(l10n, error))),
        ),
      );
    }
  }

  Future<void> _confirmRestart(
    BuildContext context,
    TerminalPaneData pane, {
    TerminalTab? tab,
  }) async {
    final l10n = AppLocalizations.of(context);
    var approved = true;
    if (pane.session.isRunning) {
      final dialogContext = controller.navigatorKey.currentContext;
      if (dialogContext == null) return;
      approved =
          await showDialog<bool>(
            context: dialogContext,
            builder: (context) => AlertDialog(
              title: Text(l10n.terminalRestartTitle),
              content: Text(l10n.terminalRestartMessage),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.commonCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l10n.terminalRestart),
                ),
              ],
            ),
          ) ??
          false;
    }
    if (!approved || !context.mounted) return;
    try {
      if (tab != null) await controller.selectTab(tab.id);
      await controller.restartPane(pane.id);
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.terminalRestartFailed(localizeError(l10n, error))),
        ),
      );
    }
  }

  Future<void> _showTabContextMenu(
    BuildContext context,
    TerminalTab tab,
    Offset position,
  ) async {
    final l10n = AppLocalizations.of(context);
    final overlay = Overlay.of(context).context.findRenderObject();
    if (overlay is! RenderBox) return;
    final pane = tab.activePane;
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          value: 'rename',
          child: ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(l10n.terminalRenameTab),
          ),
        ),
        PopupMenuItem(
          value: 'save',
          enabled: !tab.panes.any((pane) => pane.profile.isSsh),
          child: ListTile(
            leading: const Icon(Icons.bookmark_add_outlined),
            title: Text(
              tab.snapshotId == null
                  ? l10n.terminalSaveTab
                  : l10n.terminalUpdateSavedTab,
            ),
          ),
        ),
        PopupMenuItem(
          value: 'restart',
          child: ListTile(
            leading: const Icon(Icons.restart_alt),
            title: Text(l10n.terminalRestartSession),
          ),
        ),
      ],
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case 'rename':
        await _renameTab(context, tab);
      case 'save':
        await controller.selectTab(tab.id);
        if (context.mounted) await _saveTab(context);
      case 'restart':
        await _confirmRestart(context, pane, tab: tab);
    }
  }

  Future<void> _renameTab(BuildContext context, TerminalTab tab) async {
    final l10n = AppLocalizations.of(context);
    final dialogContext = controller.navigatorKey.currentContext;
    if (dialogContext == null) return;
    var enteredName = tab.displayName;
    final name = await showDialog<String>(
      context: dialogContext,
      builder: (context) => AlertDialog(
        title: Text(l10n.terminalRenameTabTitle),
        content: TextFormField(
          key: const Key('terminal-tab-name'),
          initialValue: enteredName,
          autofocus: true,
          maxLength: TerminalPanelController.maxTabNameLength,
          decoration: InputDecoration(labelText: l10n.terminalFieldTabName),
          onChanged: (value) => enteredName = value,
          onFieldSubmitted: (value) {
            if (value.trim().isNotEmpty) Navigator.pop(context, value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            key: const Key('confirm-rename-terminal-tab'),
            onPressed: () {
              final value = enteredName.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: Text(l10n.terminalRename),
          ),
        ],
      ),
    );
    if (name == null || !context.mounted) return;
    controller.renameTab(tab.id, name);
  }

  Future<void> _confirmClose(BuildContext context, TerminalTab tab) async {
    final l10n = AppLocalizations.of(context);
    if (!tab.panes.any((pane) => pane.session.isRunning)) {
      await _closeTab(context, tab.id);
      return;
    }
    final dialogContext = controller.navigatorKey.currentContext;
    if (dialogContext == null) return;
    final approved =
        await showDialog<bool>(
          context: dialogContext,
          builder: (context) => AlertDialog(
            title: Text(l10n.terminalCloseTabTitle),
            content: Text(l10n.terminalCloseTabMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.terminalCloseTab),
              ),
            ],
          ),
        ) ??
        false;
    if (approved && context.mounted) await _closeTab(context, tab.id);
  }

  Future<void> _closeTab(BuildContext context, String tabId) async {
    try {
      await controller.closeTab(tabId);
    } on Object catch (error) {
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.terminalCloseTabFailed(localizeError(l10n, error)),
          ),
        ),
      );
    }
  }

  IconData _tabStatusIcon(TerminalSessionStatus status) {
    return switch (status) {
      TerminalSessionStatus.idle => Icons.circle_outlined,
      TerminalSessionStatus.starting => Icons.pending,
      TerminalSessionStatus.running => Icons.circle,
      TerminalSessionStatus.exited => Icons.stop_circle_outlined,
      TerminalSessionStatus.failed => Icons.error_outline,
    };
  }

  Color _tabStatusColor(TerminalSessionStatus status) {
    return switch (status) {
      TerminalSessionStatus.idle => TerminalMasterColors.muted,
      TerminalSessionStatus.starting => TerminalMasterColors.yellow,
      TerminalSessionStatus.running => TerminalMasterColors.green,
      TerminalSessionStatus.exited => TerminalMasterColors.muted,
      TerminalSessionStatus.failed => TerminalMasterColors.red,
    };
  }
}
