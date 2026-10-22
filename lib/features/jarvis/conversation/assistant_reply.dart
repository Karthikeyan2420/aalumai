import 'package:aalumai/features/jarvis/domain/tool_outcome.dart';
import 'package:aalumai/features/jarvis/web_search/search_result.dart';

/// The kind of answer the engine produced, so the UI can style it (bubble
/// icon, source links, "offline" badge) and the voice layer can decide
/// whether the text is worth speaking.
enum ReplyKind {
  /// A direct conversational answer (greeting, time, arithmetic, …).
  answer,

  /// A local knowledge-base answer.
  knowledge,

  /// An answer researched online — [AssistantReply.sources] is non-empty.
  online,

  /// The result of a tool/action the user asked for.
  action,

  /// The assistant could not help (offline, no results, unsupported).
  unknown,

  /// The engine needs the user to confirm a sensitive action before it runs.
  confirm,

  /// The engine needs the user to disambiguate between several matches.
  clarify,
}

/// A complete assistant turn: displayable text plus optional sources and an
/// optional pending action awaiting confirmation.
class AssistantReply {
  const AssistantReply({
    required this.text,
    required this.kind,
    this.sources = const [],
    this.pendingTool,
    this.pendingArgs = const {},
    this.choices = const [],
    this.spokenText,
  });

  final String text;
  final ReplyKind kind;

  /// Attribution for online answers; each must be rendered as a link.
  final List<SearchResult> sources;

  /// For [ReplyKind.confirm]: the tool the user is being asked about.
  final String? pendingTool;
  final Map<String, Object?> pendingArgs;

  /// For [ReplyKind.clarify]: optional id/label options the user can pick.
  final List<ReplyChoice> choices;

  /// Override for text-to-speech; falls back to [text] when null. Used to
  /// avoid reading URLs or long lists aloud.
  final String? spokenText;

  String get speech => (spokenText ?? text).trim();

  bool get hasSources => sources.isNotEmpty;

  AssistantReply copyWith({
    String? text,
    ReplyKind? kind,
    List<SearchResult>? sources,
    String? pendingTool,
    Map<String, Object?>? pendingArgs,
    List<ReplyChoice>? choices,
    String? spokenText,
  }) {
    return AssistantReply(
      text: text ?? this.text,
      kind: kind ?? this.kind,
      sources: sources ?? this.sources,
      pendingTool: pendingTool ?? this.pendingTool,
      pendingArgs: pendingArgs ?? this.pendingArgs,
      choices: choices ?? this.choices,
      spokenText: spokenText ?? this.spokenText,
    );
  }

  /// Convenience for building a plain answer.
  factory AssistantReply.answer(String text, {String? spokenText}) =>
      AssistantReply(
        text: text,
        kind: ReplyKind.answer,
        spokenText: spokenText,
      );

  /// Convenience for turning a tool outcome into a reply.
  factory AssistantReply.fromOutcome(String tool, ToolOutcome outcome) {
    switch (outcome.kind) {
      case ToolOutcomeKind.ok:
        return AssistantReply(
          text: outcome.message,
          kind: ReplyKind.action,
          spokenText: _speakable(outcome.message),
        );
      case ToolOutcomeKind.ambiguous:
        return AssistantReply(
          text: outcome.message,
          kind: ReplyKind.clarify,
          choices: [
            for (final choice in outcome.choices)
              ReplyChoice(id: choice.id, label: choice.label),
          ],
        );
      case ToolOutcomeKind.notFound:
      case ToolOutcomeKind.error:
        return AssistantReply(text: outcome.message, kind: ReplyKind.unknown);
    }
  }

  /// Trims list/formatting noise so TTS does not read markup aloud.
  static String _speakable(String message) {
    var out = message.replaceAll(RegExp(r'\[[ x]\]'), '');
    out = out.replaceAll(RegExp(r'#\d+\s*'), '');
    out = out.replaceAll(RegExp(r'\n\(.*?more\)'), '');
    out = out.replaceAll(RegExp(r'\n'), ', ');
    return out.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

/// One disambiguation option offered to the user.
class ReplyChoice {
  const ReplyChoice({required this.id, required this.label});

  final int id;
  final String label;
}
