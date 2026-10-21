/// Result of one executed (or refused) tool call — the model-facing outcome
/// that the chat loop feeds back as a `TOOL RESULT [tool]` turn.
library;

enum ToolOutcomeKind {
  /// The action ran to completion. Reads always land here; writes landed in
  /// the app's store.
  ok,

  /// Several records matched the request. The assistant must ask the user
  /// which one before doing anything — each [ToolChoice] carries the id the
  /// model can pass back as `match`.
  ambiguous,

  /// Nothing matched — the assistant should say so plainly, never guess.
  notFound,

  /// The action could not be performed (bad arguments, missing capability,
  /// repository failure). [ToolOutcome.message] explains why in language the
  /// model can relay or retry from.
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

  /// Model-facing English text. Never localized — it is protocol, not UI.
  final String message;

  final List<ToolChoice> choices;

  bool get isOk => kind == ToolOutcomeKind.ok;
  bool get requiresUserChoice => kind == ToolOutcomeKind.ambiguous;
}
