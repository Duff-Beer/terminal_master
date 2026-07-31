enum CommandParameterType { boolean, text, options, filepath, button }

enum FilePickerMode { file, directory, any }

enum CommandParameterPlacement { automatic, beforeCommand, argument, pipeline }

enum CommandValueJoin { automatic, separated, attached }

class CommandOption {
  final String value;
  final String description;

  const CommandOption({required this.value, required this.description});
}

class CommandParameter {
  final String name;
  final String description;
  final CommandParameterType type;
  final String? flag;
  final String? prefix;
  final String? suffix;
  final List<String> dependsOn;
  final List<String> conflictsWith;
  final bool mustDiffer;
  final bool required;
  final int order;
  final int sourceIndex;
  final List<CommandOption> options;
  final Object? defaultValue;
  final FilePickerMode mode;
  final CommandParameterPlacement placement;
  final CommandValueJoin join;
  final String? example;
  final String? note;
  final String? label;
  final String? executable;
  final List<String> args;

  const CommandParameter({
    required this.name,
    required this.description,
    required this.type,
    required this.sourceIndex,
    this.flag,
    this.prefix,
    this.suffix,
    this.dependsOn = const [],
    this.conflictsWith = const [],
    this.mustDiffer = false,
    this.required = false,
    this.order = 1000,
    this.options = const [],
    this.defaultValue,
    this.mode = FilePickerMode.file,
    this.placement = CommandParameterPlacement.automatic,
    this.join = CommandValueJoin.automatic,
    this.example,
    this.note,
    this.label,
    this.executable,
    this.args = const [],
  });
}

class CommandConfig {
  final String command;
  final String description;
  final String? helpText;
  final List<CommandParameter> parameters;

  const CommandConfig({
    required this.command,
    required this.description,
    this.helpText,
    required this.parameters,
  });

  Map<String, Object?> get defaultValues => {
        for (final parameter in parameters)
          if (parameter.defaultValue != null)
            parameter.name: parameter.defaultValue,
      };
}
