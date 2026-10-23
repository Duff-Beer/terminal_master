/// Operations the app cannot carry out, reported as a code.
///
/// Covers the small service-level refusals that do not warrant a dedicated
/// exception type. Like the other failure codes in this layer, these exist so
/// the UI — which owns the locale — can phrase them in the active language.
enum ServiceFailure {
  unsupportedLink,
  linksNotOpenableOnPlatform,
  terminalDetectionUnsupported,
  sshProfileNotFound,
}

class ServiceException implements Exception {
  final ServiceFailure failure;

  /// The offending value the failure refers to, when it has one.
  final String? detail;

  const ServiceException(this.failure, [this.detail]);

  /// Developer-facing English description; the UI renders the localized form.
  String get message => switch (failure) {
    ServiceFailure.unsupportedLink => 'Unsupported link: $detail',
    ServiceFailure.linksNotOpenableOnPlatform =>
      'Links are not opened on this platform.',
    ServiceFailure.terminalDetectionUnsupported =>
      'Terminal detection is not supported on this platform.',
    ServiceFailure.sshProfileNotFound =>
      'The SSH connection profile was not found.',
  };

  @override
  String toString() => message;
}
