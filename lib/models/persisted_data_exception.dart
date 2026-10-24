/// Which piece of the app's own persisted data failed to deserialize.
///
/// These are corrupt-file conditions rather than user mistakes, but they still
/// reach dialogs, so they carry a code instead of a sentence and the UI renders
/// them in the active language.
enum PersistedDataProblem {
  invalidSavedCommand,
  invalidSavedPane,
  invalidSavedTab,
  invalidPaneTopology,
  invalidSshAuthentication,
  invalidSshProfile,
  invalidSshHostKey,
  invalidSshProfileList,
}

class PersistedDataException implements Exception {
  final PersistedDataProblem problem;

  const PersistedDataException(this.problem);

  /// Developer-facing English description; the UI renders the localized form.
  String get message => switch (problem) {
    PersistedDataProblem.invalidSavedCommand => 'Invalid saved command.',
    PersistedDataProblem.invalidSavedPane => 'Invalid saved terminal pane.',
    PersistedDataProblem.invalidSavedTab => 'Invalid saved terminal tab.',
    PersistedDataProblem.invalidPaneTopology => 'Invalid pane topology.',
    PersistedDataProblem.invalidSshAuthentication =>
      'Invalid SSH authentication.',
    PersistedDataProblem.invalidSshProfile => 'Invalid SSH connection profile.',
    PersistedDataProblem.invalidSshHostKey => 'Invalid SSH host key.',
    PersistedDataProblem.invalidSshProfileList => 'Invalid SSH profile list.',
  };

  @override
  String toString() => message;
}
