/// Result of one executed (or refused) tool call — the outcome the
/// assistant engine relays back to the user and uses to shape its reply.
library;

enum ToolOutcomeKind {
  /// The action ran to completion. Reads always land here; writes landed in
  /// the app's store.
  ok,

  /// Several records matched the request. The assistant must ask the user
  /// which one before doing anything — each [ToolChoice] carries the id the
  /// user can pick.
  ambiguous,

  /// Nothing matched — the assistant should say so plainly, never guess.
  notFound,

  /// The action could not be performed (bad arguments, missing capability,
  /// repository failure). [ToolOutcome.message] explains why.
  error,
}

class ToolChoice {
  const ToolChoice(this.id, this.label);

  final int id;
  final String label;

  @override
  String toString() => '$id: $label';
}

class ToolOutcome {
  const ToolOutcome.ok(this.message)
    : kind = ToolOutcomeKind.ok,
      choices = const [];

  const ToolOutcome.ambiguous(this.message, this.choices)
    : kind = ToolOutcomeKind.ambiguous;

  const ToolOutcome.notFound(this.message)
    : kind = ToolOutcomeKind.notFound,
      choices = const [];

  const ToolOutcome.error(this.message)
    : kind = ToolOutcomeKind.error,
      choices = const [];

  final ToolOutcomeKind kind;

  /// User-facing English text describing what happened. Kept plain so it can
  /// be shown directly or spoken aloud.
  final String message;

  final List<ToolChoice> choices;

  bool get isOk => kind == ToolOutcomeKind.ok;
  bool get requiresUserChoice => kind == ToolOutcomeKind.ambiguous;
}
