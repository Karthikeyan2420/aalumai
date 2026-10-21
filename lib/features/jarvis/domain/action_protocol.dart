/// Strict, model-facing action protocol.
///
/// The local model has no native tool-calling support, so it communicates
/// intent through a single fenced JSON block:
///
/// ````
/// ```action
/// {"tool": "task.create", "args": {"title": "Buy milk"}}
/// ```
/// ````
///
/// Everything outside the fence is plain conversation. Parsing is
/// deliberately tolerant of surrounding prose but strict about the JSON
/// payload itself — the model never executes anything, it only *requests*
/// an action which is validated, policy-checked and executed by the app.
library;

import 'dart:convert';

/// A parsed action request produced by the model.
class ActionRequest {
  const ActionRequest({required this.tool, required this.args});

  final String tool;
  final Map<String, Object?> args;

  @override
  String toString() => 'ActionRequest($tool, $args)';
}

/// Result of parsing a raw model completion.
sealed class ActionParseResult {
  const ActionParseResult();

  /// No action fence in the text — treat it as plain conversation.
  const factory ActionParseResult.none(String text) = ActionParseText;

  /// A fence was found and parsed into a valid-looking request. This does
  /// NOT mean the tool/args are valid — see tool validation.
  const factory ActionParseResult.request(ActionRequest request) =
      ActionParseRequest;

  /// A fence was found but the payload is malformed.
  const factory ActionParseResult.invalid(String reason) =
      ActionParseInvalid;
}

class ActionParseText extends ActionParseResult {
  const ActionParseText(this.text);

  final String text;
}

class ActionParseRequest extends ActionParseResult {
  const ActionParseRequest(this.request);

  final ActionRequest request;
}

class ActionParseInvalid extends ActionParseResult {
  const ActionParseInvalid(this.reason);

  final String reason;
}

/// Matches a ```action ... ``` fenced block (``` tolerated inside the JSON
/// only as string content, which jsonDecode rejects anyway — the fence is
/// closed at the first terminating ``` on its own line).
final RegExp _actionFence = RegExp(
  r'```action\s*\n(.*?)\n?```',
  dotAll: true,
);

/// Extracts the action request (if any) from a raw model completion.
///
/// Multiple fences are rejected (the model must act one step at a time);
/// the first malformed fence wins so the caller can feed an error back.
ActionParseResult parseAction(String raw) {
  final matches = _actionFence.allMatches(raw).toList();
  if (matches.isEmpty) {
    if (raw.contains('```action')) {
      // Started but never closed — a truncated generation, not prose.
      return const ActionParseResult.invalid(
        'The action block was truncated before it was closed.',
      );
    }
    return ActionParseResult.none(raw.trim());
  }
  if (matches.length > 1) {
    return const ActionParseResult.invalid(
      'Expected a single action block per reply, found several.',
    );
  }

  final body = matches.single.group(1)!.trim();
  Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException catch (e) {
    return ActionParseResult.invalid('Malformed JSON: ${e.message}');
  }
  if (decoded is! Map<String, Object?>) {
    return const ActionParseResult.invalid(
      'Action payload must be a JSON object.',
    );
  }

  final tool = decoded['tool'];
  final args = decoded['args'] ?? const <String, Object?>{};
  if (tool is! String || tool.trim().isEmpty) {
    return const ActionParseResult.invalid('Missing "tool" name.');
  }
  if (args is! Map<String, Object?>) {
    return const ActionParseResult.invalid('"args" must be an object.');
  }

  return ActionParseResult.request(
    ActionRequest(tool: tool.trim(), args: Map<String, Object?>.from(args)),
  );
}

/// The text the model is told to emit for an action (used by tests and by
/// the system prompt's few-shot examples to keep them honest).
String renderAction(String tool, Map<String, Object?> args) {
  final payload = jsonEncode(<String, Object?>{'tool': tool, 'args': args});
  return '```action\n$payload\n```';
}
