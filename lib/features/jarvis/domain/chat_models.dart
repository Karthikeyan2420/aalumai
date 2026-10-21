/// Pure chat models shared by the Jarvis assistant layers.
///
/// Deliberately free of any plugin/platform imports so the assistant
/// orchestration can be unit-tested on the Dart VM.
library;

enum ChatRole { system, user, assistant }

class ChatTurn {
  const ChatTurn(this.role, this.content);

  const ChatTurn.system(String content)
    : this(ChatRole.system, content);

  const ChatTurn.user(String content) : this(ChatRole.user, content);

  const ChatTurn.assistant(String content)
    : this(ChatRole.assistant, content);

  final ChatRole role;
  final String content;

  ChatTurn copyWith({String? content}) =>
      ChatTurn(role, content ?? this.content);

  @override
  bool operator ==(Object other) =>
      other is ChatTurn && other.role == role && other.content == content;

  @override
  int get hashCode => Object.hash(role, content);

  @override
  String toString() => 'ChatTurn(${role.name}, ${content.length} chars)';
}
