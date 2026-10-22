/// Catalog of actions the assistant may perform, with strict argument
/// validation.
///
/// Specs are the single source of truth: the deterministic intent engine
/// fills them in, [validateToolArgs] coerces and range-checks every value
/// before anything touches a repository, and they drive the confirmation
/// policy. Values are never trusted — every arg is validated here.
library;

/// How risky an action is. Drives the confirmation policy.
enum ToolRisk {
  /// Read-only query — safe to run automatically.
  read,

  /// Creates a new record (reversible, immediately visible).
  create,

  /// Updates an existing record in a reversible way (complete, retitle,
  /// play/pause media).
  update,

  /// Changes time-sensitive state where a wrong interpretation is costly
  /// (alarms, toggling repeats).
  sensitive,

  /// Removes data or records.
  destructive,

  /// Leaves the assistant's data domain (opens another app / system UI).
  external,
}

enum ArgType { string, intNum, doubleNum, boolType, datetime, enumValue, intList }

class ArgSpec {
  const ArgSpec(
    this.name,
    this.type, {
    this.required = false,
    this.allowed = const [],
    this.min,
    this.max,
    this.maxLength,
  });

  final String name;
  final ArgType type;
  final bool required;

  /// Allowed values for [ArgType.enumValue] (lowercase).
  final List<String> allowed;
  final num? min;
  final num? max;
  final int? maxLength;
}

class ToolSpec {
  const ToolSpec({
    required this.name,
    required this.description,
    required this.risk,
    required this.params,
  });

  final String name;

  /// Short English description of what the action does.
  final String description;
  final ToolRisk risk;
  final List<ArgSpec> params;
}

/// Validation outcome: on success [args] contains only declared params with
/// coerced values; on failure [errors] lists every problem found (so the
/// caller gets one complete, actionable feedback message).
class ToolValidation {
  const ToolValidation.ok(Map<String, Object?> args)
    : this._(args, const []);

  const ToolValidation.fail(List<String> errors)
    : this._(const {}, errors);

  const ToolValidation._(this.args, this.errors);

  final Map<String, Object?> args;
  final List<String> errors;

  bool get isValid => errors.isEmpty;
}

final List<ToolSpec> kJarvisToolSpecs = List.unmodifiable(<ToolSpec>[
  // ---------------------------------------------------------------- reads
  ToolSpec(
    name: 'task.list',
    description:
        'List tasks. Args: filter (optional): "open" (default), "today", "all"; '
        'query (optional): substring match on the title.',
    risk: ToolRisk.read,
    params: [
      ArgSpec(
        'filter',
        ArgType.enumValue,
        allowed: ['open', 'today', 'all'],
      ),
      ArgSpec('query', ArgType.string, maxLength: 100),
    ],
  ),
  ToolSpec(
    name: 'event.list',
    description:
        'List calendar events. Args: when (optional): "today" (default), '
        '"tomorrow", "week".',
    risk: ToolRisk.read,
    params: [
      ArgSpec('when', ArgType.enumValue, allowed: [
        'today',
        'tomorrow',
        'week',
      ]),
    ],
  ),
  ToolSpec(
    name: 'alarm.list',
    description: 'List alarms with their id, time, label and enabled state.',
    risk: ToolRisk.read,
    params: const [],
  ),
  ToolSpec(
    name: 'habit.list',
    description: 'List habits and whether each is completed today.',
    risk: ToolRisk.read,
    params: const [],
  ),
  ToolSpec(
    name: 'workout.summary',
    description:
        'Summarise workouts. Args: period (optional): "today" (default), '
        '"week".',
    risk: ToolRisk.read,
    params: [
      ArgSpec('period', ArgType.enumValue, allowed: ['today', 'week']),
    ],
  ),
  ToolSpec(
    name: 'note.search',
    description: 'Search notes by text. Args: query (required).',
    risk: ToolRisk.read,
    params: [ArgSpec('query', ArgType.string, required: true, maxLength: 120)],
  ),
  ToolSpec(
    name: 'expense.summary',
    description:
        'Total balance and this month\'s spending/income. No args required.',
    risk: ToolRisk.read,
    params: const [],
  ),
  ToolSpec(
    name: 'music.list',
    description:
        'Search the music library. Args: query (optional): substring match '
        'on track or artist.',
    risk: ToolRisk.read,
    params: [ArgSpec('query', ArgType.string, maxLength: 100)],
  ),
  ToolSpec(
    name: 'memory.search',
    description:
        'Search saved memories (personal facts and preferences). '
        'Args: query (optional: empty returns the most recent).',
    risk: ToolRisk.read,
    params: [ArgSpec('query', ArgType.string, maxLength: 100)],
  ),
  ToolSpec(
    name: 'device.status',
    description: 'Battery level and charging state of the phone. No args.',
    risk: ToolRisk.read,
    params: const [],
  ),
  // -------------------------------------------------------------- creates
  ToolSpec(
    name: 'task.create',
    description:
        'Create a task. Args: title (required); due (optional ISO date/time '
        'like 2026-10-21 09:00); priority (optional): "low", "normal", "high".',
    risk: ToolRisk.create,
    params: [
      ArgSpec('title', ArgType.string, required: true, maxLength: 200),
      ArgSpec('due', ArgType.datetime),
      ArgSpec('priority', ArgType.enumValue, allowed: [
        'low',
        'normal',
        'high',
      ]),
    ],
  ),
  ToolSpec(
    name: 'event.create',
    description:
        'Create a calendar event. Args: title (required); start (required '
        'ISO date/time); end (optional ISO date/time, defaults to +1h); '
        'location (optional).',
    risk: ToolRisk.create,
    params: [
      ArgSpec('title', ArgType.string, required: true, maxLength: 200),
      ArgSpec('start', ArgType.datetime, required: true),
      ArgSpec('end', ArgType.datetime),
      ArgSpec('location', ArgType.string, maxLength: 200),
    ],
  ),
  ToolSpec(
    name: 'reminder.create',
    description:
        'Schedule a one-shot local reminder notification. Args: text '
        '(required); fire_at (required ISO date/time — use the current time '
        'given in the prompt to compute delays).',
    risk: ToolRisk.create,
    params: [
      ArgSpec('text', ArgType.string, required: true, maxLength: 200),
      ArgSpec('fire_at', ArgType.datetime, required: true),
    ],
  ),
  ToolSpec(
    name: 'alarm.set',
    description:
        'Create an alarm. Args: hour (0-23, required); minute (0-59, '
        'required); label (optional); days (optional list of weekday numbers '
        'Mo=0..Su=6; omit for a one-time alarm).',
    risk: ToolRisk.create,
    params: [
      ArgSpec('hour', ArgType.intNum, required: true, min: 0, max: 23),
      ArgSpec('minute', ArgType.intNum, required: true, min: 0, max: 59),
      ArgSpec('label', ArgType.string, maxLength: 100),
      ArgSpec('days', ArgType.intList),
    ],
  ),
  ToolSpec(
    name: 'habit.log',
    description:
        'Mark a habit as done today. Args: match (required): the habit name '
        'as the user knows it.',
    risk: ToolRisk.create,
    params: [ArgSpec('match', ArgType.string, required: true, maxLength: 100)],
  ),
  ToolSpec(
    name: 'note.create',
    description: 'Create a note. Args: body (required); title (optional).',
    risk: ToolRisk.create,
    params: [
      ArgSpec('body', ArgType.string, required: true, maxLength: 4000),
      ArgSpec('title', ArgType.string, maxLength: 200),
    ],
  ),
  ToolSpec(
    name: 'memory.save',
    description:
        'Remember a durable fact or preference the user told you. Args: '
        'content (required, one concise sentence); category (optional): '
        '"fact" (default), "preference", "goal", "person", "event", "summary".',
    risk: ToolRisk.create,
    params: [
      ArgSpec('content', ArgType.string, required: true, maxLength: 500),
      ArgSpec('category', ArgType.enumValue, allowed: [
        'fact',
        'preference',
        'goal',
        'person',
        'event',
        'summary',
      ]),
    ],
  ),
  ToolSpec(
    name: 'expense.create',
    description:
        'Record an expense or income. Args: amount (required, positive '
        'number); type (optional): "expense" (default) or "income"; note '
        '(optional); category (optional).',
    risk: ToolRisk.create,
    params: [
      ArgSpec('amount', ArgType.doubleNum, required: true, min: 0.01),
      ArgSpec('type', ArgType.enumValue, allowed: ['expense', 'income']),
      ArgSpec('note', ArgType.string, maxLength: 200),
      ArgSpec('category', ArgType.string, maxLength: 60),
    ],
  ),
  // -------------------------------------------------------------- updates
  ToolSpec(
    name: 'task.complete',
    description:
        'Mark a task as done. Args: match (required): task title fragment. '
        'If several tasks match, ask the user which one first.',
    risk: ToolRisk.update,
    params: [ArgSpec('match', ArgType.string, required: true, maxLength: 100)],
  ),
  ToolSpec(
    name: 'task.update',
    description:
        'Change an existing task. Args: match (required): task title '
        'fragment; plus at least one of new_title, due (ISO date/time), '
        'priority ("low"|"normal"|"high").',
    risk: ToolRisk.update,
    params: [
      ArgSpec('match', ArgType.string, required: true, maxLength: 100),
      ArgSpec('new_title', ArgType.string, maxLength: 200),
      ArgSpec('due', ArgType.datetime),
      ArgSpec('priority', ArgType.enumValue, allowed: [
        'low',
        'normal',
        'high',
      ]),
    ],
  ),
  ToolSpec(
    name: 'music.play',
    description:
        'Play a track from the library (or resume playback when no match is '
        'given). Args: match (optional): title or artist substring.',
    risk: ToolRisk.update,
    params: [ArgSpec('match', ArgType.string, maxLength: 100)],
  ),
  // ------------------------------------------------- sensitive / destructive
  ToolSpec(
    name: 'alarm.toggle',
    description:
        'Enable or disable an existing alarm. Args: match (required): alarm '
        'label or time (e.g. "07:00"); enabled (required): true/false.',
    risk: ToolRisk.sensitive,
    params: [
      ArgSpec('match', ArgType.string, required: true, maxLength: 100),
      ArgSpec('enabled', ArgType.boolType, required: true),
    ],
  ),
  ToolSpec(
    name: 'task.delete',
    description:
        'Delete a task permanently. Args: match (required): title fragment.',
    risk: ToolRisk.destructive,
    params: [ArgSpec('match', ArgType.string, required: true, maxLength: 100)],
  ),
  ToolSpec(
    name: 'alarm.delete',
    description: 'Delete an alarm. Args: match (required): label or time.',
    risk: ToolRisk.destructive,
    params: [ArgSpec('match', ArgType.string, required: true, maxLength: 100)],
  ),
  ToolSpec(
    name: 'memory.forget',
    description:
        'Forget a saved memory. Args: match (required): fragment of the '
        'remembered content.',
    risk: ToolRisk.destructive,
    params: [ArgSpec('match', ArgType.string, required: true, maxLength: 100)],
  ),
  // -------------------------------------------------------------- external
  ToolSpec(
    name: 'device.open_app',
    description:
        'Open another installed app by package name. Args: package '
        '(required): e.g. "com.whatsapp".',
    risk: ToolRisk.external,
    params: [
      ArgSpec('package', ArgType.string, required: true, maxLength: 120),
    ],
  ),
  ToolSpec(
    name: 'device.open_settings',
    description:
        'Open a system settings page. Args: page (required): one of '
        '"wifi", "bluetooth", "sound", "display", "battery", "apps", '
        '"storage", "notifications", "location", "security".',
    risk: ToolRisk.external,
    params: [
      ArgSpec('page', ArgType.enumValue, required: true, allowed: [
        'wifi',
        'bluetooth',
        'sound',
        'display',
        'battery',
        'apps',
        'storage',
        'notifications',
        'location',
        'security',
      ]),
    ],
  ),
]);

final Map<String, ToolSpec> kJarvisToolsByName = Map.unmodifiable(
  <String, ToolSpec>{for (final spec in kJarvisToolSpecs) spec.name: spec},
);

/// Coerces and validates [args] against [spec].
///
/// Deliberately strict about unknown parameters (they are reported as
/// errors) and lenient about JSON typing details (numbers quoted as
/// strings, etc.).
ToolValidation validateToolArgs(ToolSpec spec, Map<String, Object?> args) {
  final errors = <String>[];
  final out = <String, Object?>{};

  for (final key in args.keys) {
    if (!spec.params.any((p) => p.name == key)) {
      errors.add('Unknown argument "$key" for ${spec.name}.');
    }
  }

  for (final param in spec.params) {
    if (!args.containsKey(param.name)) {
      if (param.required) {
        errors.add('Missing required argument "${param.name}".');
      }
      continue;
    }
    final raw = args[param.name];
    if (raw == null) {
      if (param.required) {
        errors.add('Missing required argument "${param.name}".');
      }
      continue; // Optional + explicit null = treat as absent.
    }
    final coerced = _coerce(param, raw);
    if (coerced is _CoerceFailure) {
      errors.add(coerced.message);
      continue;
    }
    out[param.name] = coerced;
  }

  if (spec.name == 'task.update') {
    final touches = ['new_title', 'due', 'priority'].where(out.containsKey);
    if (touches.isEmpty) {
      errors.add(
        'task.update needs at least one of new_title, due or priority.',
      );
    }
  }

  return errors.isEmpty
      ? ToolValidation.ok(out)
      : ToolValidation.fail(errors);
}

class _CoerceFailure {
  const _CoerceFailure(this.message);

  final String message;
}

Object? _coerce(ArgSpec spec, Object raw) {
  final label = '"${spec.name}"';

  switch (spec.type) {
    case ArgType.string:
      String value;
      if (raw is String) {
        value = raw.trim();
      } else if (raw is num || raw is bool) {
        value = raw.toString();
      } else {
        return _CoerceFailure('$label must be text.');
      }
      if (value.isEmpty) return _CoerceFailure('$label must not be empty.');
      final maxLen = spec.maxLength;
      if (maxLen != null && value.length > maxLen) {
        return _CoerceFailure('$label is too long (max $maxLen characters).');
      }
      return value;

    case ArgType.intNum:
      int? value;
      if (raw is int) {
        value = raw;
      } else if (raw is double && raw == raw.roundToDouble()) {
        value = raw.toInt();
      } else if (raw is String) {
        value = int.tryParse(raw.trim());
      }
      if (value == null) return _CoerceFailure('$label must be a whole number.');
      if (!_withinRange(spec, value)) {
        return _CoerceFailure(_rangeText(spec));
      }
      return value;

    case ArgType.doubleNum:
      double? value;
      if (raw is num) {
        value = raw.toDouble();
      } else if (raw is String) {
        value = double.tryParse(raw.trim());
      }
      if (value == null) return _CoerceFailure('$label must be a number.');
      if (!_withinRange(spec, value)) {
        return _CoerceFailure(_rangeText(spec));
      }
      return value;

    case ArgType.boolType:
      if (raw is bool) return raw;
      if (raw is String) {
        final normalized = raw.trim().toLowerCase();
        if (normalized == 'true') return true;
        if (normalized == 'false') return false;
      }
      return _CoerceFailure('$label must be true or false.');

    case ArgType.datetime:
      if (raw is! String) {
        return _CoerceFailure(
          '$label must be an ISO date/time string like 2026-10-21 09:00.',
        );
      }
      final parsed = _parseDateTime(raw);
      if (parsed == null) {
        return _CoerceFailure(
          '$label is not a recognisable date/time ("$raw").',
        );
      }
      return parsed;

    case ArgType.enumValue:
      if (raw is! String) return _CoerceFailure('$label must be text.');
      final normalized = raw.trim().toLowerCase();
      if (!spec.allowed.contains(normalized)) {
        final allowed = spec.allowed.join(', ');
        return _CoerceFailure('$label must be one of: $allowed.');
      }
      return normalized;

    case ArgType.intList:
      final values = <int>[];
      final List<Object?> items;
      if (raw is List) {
        items = raw;
      } else if (raw is String) {
        items = raw
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      } else {
        return _CoerceFailure('$label must be a list of numbers.');
      }
      for (final item in items) {
        int? value;
        if (item is int) {
          value = item;
        } else if (item is num && item == item.roundToDouble()) {
          value = item.toInt();
        } else if (item is String) {
          value = int.tryParse(item.trim());
        }
        if (value == null || value < 0 || value > 6) {
          return _CoerceFailure(
            '$label entries must be weekday numbers 0-6 (Mo=0 .. Su=6).',
          );
        }
        values.add(value);
      }
      if (values.isEmpty) return _CoerceFailure('$label must not be empty.');
      return values;
  }
}

bool _withinRange(ArgSpec spec, num value) {
  if (spec.min != null && value < spec.min!) return false;
  if (spec.max != null && value > spec.max!) return false;
  return true;
}

String _rangeText(ArgSpec spec) {
  final name = '"${spec.name}"';
  if (spec.min != null && spec.max != null) {
    return '$name must be between ${spec.min} and ${spec.max}.';
  }
  if (spec.min != null) return '$name must be at least ${spec.min}.';
  return '$name must be at most ${spec.max}.';
}

final List<DateTime? Function(String)> _dateParsers = [
  (s) => DateTime.tryParse(s.trim()),
  (s) {
    final normalized = s.trim().replaceAll('/', '-');
    final match = RegExp(
      r'^(\d{4})-(\d{1,2})-(\d{1,2})(?:[ T](\d{1,2}):(\d{2})(?::(\d{2}))?)?$',
    ).firstMatch(normalized);
    if (match == null) return null;
    int at(int group) => int.tryParse(match.group(group) ?? '') ?? 0;
    final year = at(1);
    if (year < 2000 || year > 2100) return null;
    return DateTime(
      year,
      at(2),
      at(3),
      at(4),
      at(5),
      match.group(6) == null ? 0 : at(6),
    );
  },
];

DateTime? _parseDateTime(String raw) {
  for (final parse in _dateParsers) {
    final result = parse(raw);
    if (result != null && result.year >= 2000 && result.year <= 2100) {
      return result;
    }
  }
  return null;
}
