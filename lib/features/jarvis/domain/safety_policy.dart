/// Confirmation policy: which requested actions may run without asking.
///
/// Single source of truth so the behaviour is unit-testable and the UI can
/// render an accurate confirmation dialog description from the same data.
library;

import 'tool_specs.dart';

enum Decision {
  /// Execute immediately; the result is shown right away.
  autoExecute,

  /// Show a confirmation sheet with a human-readable description before
  /// executing. Used for sensitive/destructive/external actions.
  confirm,

  /// The tool does not exist — the request could not be understood; report
  /// it back so the user can rephrase.
  unknownTool,
}

Decision decideAction(String toolName, {ToolSpec? spec}) {
  final tool = spec ?? kJarvisToolsByName[toolName];
  if (tool == null) return Decision.unknownTool;
  switch (tool.risk) {
    case ToolRisk.read:
    case ToolRisk.create:
    case ToolRisk.update:
      return Decision.autoExecute;
    case ToolRisk.sensitive:
    case ToolRisk.destructive:
    case ToolRisk.external:
      return Decision.confirm;
  }
}

/// A concise, user-facing sentence describing what an action will do —
/// used verbatim in confirmation dialogs.
String describeAction(String toolName, Map<String, Object?> args) {
  String arg(String name) {
    final value = args[name];
    if (value == null) return '';
    if (value is DateTime) {
      final local = value.toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(local.hour)}:${two(local.minute)} on '
          '${two(local.day)}.${local.month}.${local.year}';
    }
    if (value is List) return value.join(', ');
    return value.toString();
  }

  switch (toolName) {
    case 'alarm.toggle':
      return 'Turn ${args['enabled'] == true ? 'on' : 'off'} alarm '
          '"${arg('match')}".';
    case 'task.delete':
      return 'Delete the task "${arg('match')}" permanently.';
    case 'alarm.delete':
      return 'Delete the alarm "${arg('match')}".';
    case 'memory.forget':
      return 'Forget the memory "${arg('match')}".';
    case 'device.open_app':
      return 'Open the app ${arg('package')}.';
    case 'device.open_settings':
      return 'Open system settings: ${arg('page')}.';
    default:
      final spec = kJarvisToolsByName[toolName];
      final parts = <String>[
        for (final param in spec?.params ?? const <ArgSpec>[])
          if (args[param.name] != null)
            '${param.name}: ${arg(param.name)}',
      ];
      return 'Run $toolName${parts.isEmpty ? '' : ' (${parts.join(', ')})'}.';
  }
}
