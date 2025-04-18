class CommandParameter {
  final String name;
  final String description;
  final String type;
  final String? flag;
  final String? prefix;
  final String? suffix;
  final List<String>? dependsOn;
  final List<String>? conflictsWith;
  final bool mustDiffer;
  final bool required;
  final int order;
  final List<Map<String, String>>? options;

  CommandParameter({
    required this.name,
    required this.description,
    required this.type,
    this.flag,
    this.prefix,
    this.suffix,
    this.dependsOn,
    this.conflictsWith,
    this.mustDiffer = false,
    this.required = false,
    this.order = 1000,
    this.options,
  });
}

class CommandConfig {
  final String command;
  final String description;
  final String? helpText;
  final List<CommandParameter> parameters;

  CommandConfig({
    required this.command,
    required this.description,
    this.helpText,
    required this.parameters,
  });
}
