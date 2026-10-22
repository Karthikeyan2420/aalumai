/// System prompt assembly and context-window management (pure, testable).
///
/// The local model gets everything through one system prompt plus the
/// message history — there is no native tool-calling channel — so this
/// file owns: persona, clock, memory/workspace context blocks, the action
/// catalogue rendered from [ToolSpec]s, the protocol instructions, and
/// history windowing under a token budget.
library;

import 'dart:math' as math;

import 'chat_models.dart';
import 'tool_specs.dart';

/// Rough token estimate (~3.7 chars/token for English; deliberately the
/// same heuristic the native runtime uses for its context accounting).
int estimateTokens(String text) {
  if (text.trim().isEmpty) return 0;
  return math.max(1, (text.length / 3.7).ceil());
}

class PromptContext {
  const PromptContext({
    required this.now,
    required this.uiLocale,
    this.timeZoneLabel = '',
    this.memories = const [],
    this.workspaceFacts = const [],
  });

  /// Local wall clock — lets the model compute relative times
  /// ("in 10 minutes") without a separate tool.
  final DateTime now;

  /// BCP-47 app locale (e.g. `en`, `kn`, `ml`), used only as a hint.
  final String uiLocale;

  /// Human label of the device timezone (e.g. `IST`), if known.
  final String timeZoneLabel;

  /// Pre-retrieved memory lines ("User prefers X") — already ranked.
  final List<String> memories;

  /// Pre-rendered, pre-translated-in-English facts about the user's data
  /// ("3 open tasks, next alarm 07:00 …") produced by the controller from
  /// the existing repositories. Empty = no workspace context yet.
  final List<String> workspaceFacts;
}

/// Appended to the newest user turn to force Qwen3's non-thinking mode.
///
/// Qwen3 is a hybrid-reasoning model: unless told otherwise it emits a
/// `Thinking Process:` / fenced think block before the answer, which is slow
/// and noisy for an on-device assistant. The plugin's bundled ChatML template
/// emits a bare `im_start` assistant generation prompt (no empty think pair),
/// so the model defaults to thinking. The documented soft switch `/no_think`
/// in the *user message* is the reliable way to turn it off when
/// `enable_thinking` cannot be passed through the plugin.
const String kNoThinkDirective = '/no_think';

/// Open fence of a Qwen3 reasoning block (`<` + `think` + `>`).
final String kThinkStart = '${String.fromCharCode(60)}think${String.fromCharCode(62)}';

/// Close fence of a Qwen3 reasoning block (`<` + `/think` + `>`).
final String kThinkEnd =
    '${String.fromCharCode(60)}/think${String.fromCharCode(62)}';

/// Returns [turn] with [kNoThinkDirective] appended when it is the newest
/// user message and does not already carry a `/think` switch.
///
/// Only touched at send time; the stored history keeps the user's original
/// text so the transcript stays clean.
ChatTurn withNoThinkDirective(ChatTurn turn) {
  if (turn.role != ChatRole.user) return turn;
  final body = turn.content.trimRight();
  if (body.contains('/no_think') || body.contains('/think')) return turn;
  return turn.copyWith(content: '$body $kNoThinkDirective');
}

String _two(int n) => n.toString().padLeft(2, '0');

String formatNow(DateTime now, {String timeZoneLabel = ''}) {
  final local = now.toLocal();
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final stamp = '${weekdays[local.weekday - 1]}, '
      '${local.day} ${months[local.month - 1]} ${local.year}, '
      '${_two(local.hour)}:${_two(local.minute)}';
  return timeZoneLabel.isEmpty ? stamp : '$stamp ($timeZoneLabel)';
}

/// Builds the system prompt: identity, clock, personal/workspace context,
/// action catalogue and the strict output protocol.
String buildSystemPrompt(
  PromptContext context, {
  List<ToolSpec>? tools,
}) {
  final catalog = tools ?? kJarvisToolSpecs;
  final buffer = StringBuffer()
    ..writeln('You are Jarvis, the private on-device assistant built into '
        'the AALUMAI app. Everything runs locally on this phone — no cloud, '
        'no accounts. You help with tasks, calendar, alarms, reminders, '
        'habits, workouts, notes, expenses, music and the phone\'s settings.')
    ..writeln()
    ..writeln('Current date and time: '
        '${formatNow(context.now, timeZoneLabel: context.timeZoneLabel)}.')
    ..writeln('App interface language code: ${context.uiLocale}. '
        'Always reply in the language the user writes in.')
    ..writeln()
    ..writeln('Personal context (facts you have remembered):');
  if (context.memories.isEmpty) {
    buffer.writeln('- (none saved yet)');
  } else {
    for (final memory in context.memories) {
      buffer.writeln('- $memory');
    }
  }

  buffer
    ..writeln()
    ..writeln('Current data overview (from the app\'s local database):');
  if (context.workspaceFacts.isEmpty) {
    buffer.writeln('- (not loaded)');
  } else {
    for (final fact in context.workspaceFacts) {
      buffer.writeln('- $fact');
    }
  }

  buffer
    ..writeln()
    ..writeln('AVAILABLE ACTIONS')
    ..writeln(
      'When a reply requires acting on the app, output EXACTLY one fenced '
      'block and nothing else in that reply:',
    )
    ..writeln('```action')
    ..writeln('{"tool": "<name>", "args": {<arguments>}}')
    ..writeln('```')
    ..writeln('Rules:')
    ..writeln('- One action per reply. After it runs you receive a message '
        'starting with "TOOL RESULT" — continue from there.')
    ..writeln('- Never claim an action succeeded before its TOOL RESULT '
        'arrives. If a lookup finds several matching records, do not '
        'guess: ask the user which one they mean.')
    ..writeln('- Plain conversational replies must NOT contain an action '
        'block.')
    ..writeln('- Do not invent data about the user; only what the tools '
        'return or what the context blocks above state.')
    ..writeln()
    ..writeln('Action list (name(signature): intent; "!" required, "?" '
        'optional):');

  for (final tool in catalog) {
    buffer.writeln('- ${_compactToolLine(tool)}');
  }

  buffer
    ..writeln()
    ..writeln('STYLE')
    ..writeln('- Answer directly. Do not show your reasoning or write '
        'down a "Thinking Process" — the user only sees your final answer.')
    ..writeln('- Keep replies short and speakable: 1-4 sentences, plain '
        'text, no markdown headings, no bullet walls.')
    ..writeln('- Mention concrete values (times, titles, amounts) exactly '
        'as the TOOL RESULT reports them.');

  return buffer.toString().trimRight();
}

/// One compact catalogue line: `name(signature): intent`.
///
/// The full prose in [ToolSpec.description] spends most of its length
/// spelling out arguments in "Args: …" form. The native prefill is the
/// dominant cost on-device (~20 tok/s measured), so we keep the intent
/// sentence and move the argument detail into a terser, machine-parsable
/// signature rendered from [ToolSpec.params].
String _compactToolLine(ToolSpec tool) {
  final gloss = tool.description.split('Args:').first.trim();
  final signature = tool.params.map(_compactParam).join(', ');
  return '${tool.name}($signature): $gloss';
}

String _compactParam(ArgSpec p) {
  final req = p.required ? '!' : '?';
  switch (p.type) {
    case ArgType.enumValue:
      return '${p.name}$req=${p.allowed.join('|')}';
    case ArgType.datetime:
      return '${p.name}$req=ISO';
    case ArgType.intNum:
      final range = (p.min != null && p.max != null)
          ? '${p.min}-${p.max}'
          : '';
      return '${p.name}$req=int$range';
    case ArgType.doubleNum:
      return '${p.name}$req=number';
    case ArgType.boolType:
      return '${p.name}$req=true|false';
    case ArgType.intList:
      return '${p.name}$req=int-list';
    case ArgType.string:
      return '${p.name}$req';
  }
}

/// Wraps a tool result the way the model is told to expect it (a user
/// message starting with the fixed marker).
ChatTurn toolResultTurn(String toolName, String result) {
  final body = result.trim();
  return ChatTurn.user('TOOL RESULT [$toolName]\n$body');
}

/// Removes a leaked Qwen3 reasoning block from generated [text].
///
/// The `/no_think` soft switch is only a strong hint; small models still
/// occasionally prefix the answer with a fenced think block or a
/// "Thinking Process:" preamble. This defensively returns just the final
/// answer so the UI never shows the scratchpad. Text with no reasoning
/// block is returned unchanged (trimmed).
String stripThinking(String text) {
  var body = text;

  // 1. Fenced think pair(s): keep only what follows the last close tag.
  //    This also covers the empty think pair Qwen3 emits in non-thinking
  //    mode.
  if (body.contains(kThinkEnd)) {
    body = body.split(kThinkEnd).last;
  } else if (body.trimLeft().startsWith(kThinkStart)) {
    // Opening tag with no close yet (mid-stream): drop the leading run of
    // think tags / blank lines so suppression keeps improving as tokens
    // arrive.
    body = body.replaceFirst(RegExp('^\\s*(?:${RegExp.escape(kThinkStart)}\\s*)+'), '');
  }

  // 2. Explicit prose reasoning prefix.
  const markers = [
    'Thinking Process:',
    'thinking process:',
    'Thinking:',
    'Reasoning:',
  ];
  for (final marker in markers) {
    if (body.contains(marker)) {
      final after = body.substring(body.indexOf(marker) + marker.length);
      final split = after.split(RegExp(r'\n\s*\n'));
      body = split.length > 1 ? split.last : after;
    }
  }

  // 3. Bare `think` fence the model sometimes emits.
  body = body.replaceAll(RegExp(r'^\s*think\s*\n', multiLine: true), '');

  return body.trim();
}

/// The context window actually sent to the model: one system turn plus the
/// longest suffix of [history] that fits the budget.
///
/// Keeping the *suffix* (not the prefix) matters for chat: the most recent
/// turns carry the pending question. The system prompt is never dropped —
/// if it alone exceeds the budget it is still sent (a truncated system
/// prompt would lose the protocol), because callers size it accordingly.
List<ChatTurn> buildConversation({
  required String systemPrompt,
  required List<ChatTurn> history,
  required int tokenBudget,
  int reservedForReply = 512,
}) {
  final system = ChatTurn.system(systemPrompt);
  final systemTokens = estimateTokens(systemPrompt);
  var budget = tokenBudget - reservedForReply - systemTokens;
  if (budget < 64) budget = 64;
  final maxTailChars = math.max(120, budget * 4);

  final kept = <ChatTurn>[];
  for (var i = history.length - 1; i >= 0; i--) {
    final turn = history[i];
    final cost = estimateTokens(turn.content) + 8; // role/template overhead.
    if (cost > budget && kept.isNotEmpty) break;
    if (cost > budget && kept.isEmpty) {
      // A single oversized turn: keep its tail so the newest user request
      // (or the tail of it) always survives.
      final trimmed = turn.copyWith(
        content:
            turn.content.length <= maxTailChars
                ? turn.content
                : '…${turn.content.substring(turn.content.length - maxTailChars)}',
      );
      kept.add(trimmed);
      budget -= estimateTokens(trimmed.content) + 8;
      break;
    }
    kept.add(turn);
    budget -= cost;
  }

  return [system, ...kept.reversed];
}
