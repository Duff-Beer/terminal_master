import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:xterm/xterm.dart';

import '../l10n/app_localizations.dart';
import '../l10n/error_presenter.dart';
import '../models/shell_profile.dart';
import '../models/saved_terminal_tab.dart';
import '../models/ssh_connection_profile.dart';
import '../models/terminal_command_block.dart';
import '../services/command_risk_assessor.dart';
import '../services/terminal_backend.dart';
import '../services/external_url_launcher.dart';
import '../services/saved_terminal_tab_store.dart';
import '../services/terminal_session.dart';
import '../theme.dart';
import '../utils/shell_quoting.dart';
import '../utils/terminal_fonts.dart';
import 'command_confirmation_dialog.dart';
import 'terminal_mouse_overlay.dart';

part 'terminal_panel/controller.dart';
part 'terminal_panel/workspace.dart';
part 'terminal_panel/pane.dart';
