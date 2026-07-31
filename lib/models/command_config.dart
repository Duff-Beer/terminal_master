enum CommandParameterType { boolean, text, textList, options, filepath, button }

enum FilePickerMode { file, directory, any }

enum CommandParameterPlacement { automatic, beforeCommand, argument, pipeline }

enum CommandValueJoin { automatic, separated, attached }

class CommandOption {
  final String value;
  final String description;

  const CommandOption({required this.value, required this.description});
}

bool isCommandValueActive(Object? value) {
  if (value is bool) return value;
  if (value is String) return value.trim().isNotEmpty;
  if (value is Iterable) return value.any(isCommandValueActive);
  return value != null;
}

class CommandCondition {
  final String parameter;
  final List<Object> expectedValues;
  final bool? active;

  const CommandCondition({
    required this.parameter,
    this.expectedValues = const [],
    this.active,
  });

  bool matches(Map<String, Object?> values) {
    return matchesValue((parameter) => values[parameter]);
  }

  bool matchesValue(Object? Function(String parameter) valueFor) {
    final value = valueFor(parameter);
    if (expectedValues.isEmpty) {
      return isCommandValueActive(value) == (active ?? true);
    }
    if (value is Iterable) {
      return value.any(expectedValues.contains);
    }
    return expectedValues.contains(value);
  }
}

class CommandConditionGroup {
  final List<CommandCondition> conditions;
  final bool matchAny;

  const CommandConditionGroup({
    required this.conditions,
    this.matchAny = false,
  });

  bool matches(Map<String, Object?> values) => matchAny
      ? conditions.any((condition) => condition.matches(values))
      : conditions.every((condition) => condition.matches(values));

  bool matchesValue(Object? Function(String parameter) valueFor) => matchAny
      ? conditions.any((condition) => condition.matchesValue(valueFor))
      : conditions.every((condition) => condition.matchesValue(valueFor));
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
  final CommandConditionGroup? visibleWhen;
  final CommandConditionGroup? requiredWhen;

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
    this.visibleWhen,
    this.requiredWhen,
  });
}

class CommandConfig {
  final String command;
  final String displayName;
  final String description;
  final String? helpText;
  final List<CommandParameter> parameters;

  const CommandConfig({
    required this.command,
    String? displayName,
    required this.description,
    this.helpText,
    required this.parameters,
  }) : displayName = displayName ?? command;

  Map<String, Object?> get defaultValues => {
    for (final parameter in parameters)
      if (parameter.defaultValue != null)
        parameter.name: parameter.defaultValue,
  };

  bool isParameterVisible(
    CommandParameter parameter,
    Map<String, Object?> values,
  ) {
    final byName = {
      for (final candidate in parameters) candidate.name: candidate,
    };
    final cache = <String, bool>{};
    final visiting = <String>{};

    bool resolve(CommandParameter candidate) {
      final cached = cache[candidate.name];
      if (cached != null) return cached;
      if (!visiting.add(candidate.name)) return false;
      final visible =
          candidate.visibleWhen?.matchesValue((name) {
            final dependency = byName[name];
            return dependency != null && resolve(dependency)
                ? values[name]
                : null;
          }) ??
          true;
      visiting.remove(candidate.name);
      cache[candidate.name] = visible;
      return visible;
    }

    return resolve(parameter);
  }

  bool isParameterRequired(
    CommandParameter parameter,
    Map<String, Object?> values,
  ) {
    if (parameter.required) return true;
    return parameter.requiredWhen?.matchesValue((name) {
          final dependency = parameters.where(
            (candidate) => candidate.name == name,
          );
          if (dependency.isEmpty ||
              !isParameterVisible(dependency.single, values)) {
            return null;
          }
          return values[name];
        }) ??
        false;
  }
}
