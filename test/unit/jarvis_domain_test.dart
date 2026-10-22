import 'package:aalumai/features/jarvis/domain/action_protocol.dart';
import 'package:aalumai/features/jarvis/domain/chat_models.dart';
import 'package:aalumai/features/jarvis/domain/prompt_builder.dart';
import 'package:aalumai/features/jarvis/domain/safety_policy.dart';
import 'package:aalumai/features/jarvis/domain/tool_specs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('action protocol parsing', () {
    test('plain conversation yields no action', () {
      final result = parseAction('Sure — your next alarm is at 07:00.');
      expect(result, isA<ActionParseText>());
      expect(
        (result as ActionParseText).text,
        'Sure — your next alarm is at 07:00.',
      );
    });

    test('a single valid fence parses the request', () {
      final result = parseAction(
        'Creating that now.\n'
        '```action\n'
        '{"tool": "task.create", "args": {"title": "Buy milk"}}\n'
        '```',
      );
      final request = (result as ActionParseRequest).request;
      expect(request.tool, 'task.create');
      expect(request.args['title'], 'Buy milk');
    });

    test('prose around the fence is ignored', () {
      final result = parseAction(
        '```action\n{"tool": "alarm.list", "args": {}}\n```\n'
        'one more line',
      );
      expect(result, isA<ActionParseRequest>());
      expect(
        (result as ActionParseRequest).request.tool,
        'alarm.list',
      );
    });

    test('args defaults to an empty object', () {
      final result = parseAction(
        '```action\n{"tool": "habit.list"}\n```',
      );
      expect((result as ActionParseRequest).request.args, isEmpty);
    });

    test('malformed JSON is invalid', () {
      final result = parseAction('```action\n{"tool": }\n```');
      expect(result, isA<ActionParseInvalid>());
      expect((result as ActionParseInvalid).reason, contains('Malformed'));
    });

    test('missing tool name is invalid', () {
      final result = parseAction('```action\n{"args": {}}\n```');
      expect(result, isA<ActionParseInvalid>());
    });

    test('non-object payload is invalid', () {
      final result = parseAction('```action\n["task.create"]\n```');
      expect(result, isA<ActionParseInvalid>());
    });

    test('args must be an object when present', () {
      final result = parseAction(
        '```action\n{"tool": "task.list", "args": 3}\n```',
      );
      expect(result, isA<ActionParseInvalid>());
    });

    test('several fences in one reply are rejected', () {
      final result = parseAction(
        '```action\n{"tool": "task.list", "args": {}}\n```\n'
        'and\n'
        '```action\n{"tool": "alarm.list", "args": {}}\n```',
      );
      expect(result, isA<ActionParseInvalid>());
      expect((result as ActionParseInvalid).reason, contains('single'));
    });

    test('truncated (unclosed) block is invalid, not prose', () {
      final result = parseAction('```action\n{"tool": "task.cre');
      expect(result, isA<ActionParseInvalid>());
    });

    test('renderAction round-trips through parseAction', () {
      final rendered = renderAction('task.create', {'title': 'Call mom'});
      final parsed = parseAction(rendered);
      final request = (parsed as ActionParseRequest).request;
      expect(request.tool, 'task.create');
      expect(request.args, {'title': 'Call mom'});
    });
  });

  group('decision policy', () {
    test('unknown tools are flagged', () {
      expect(decideAction('shell.exec'), Decision.unknownTool);
    });

    test('read/create/update execute automatically', () {
      expect(decideAction('task.list'), Decision.autoExecute);
      expect(decideAction('task.create'), Decision.autoExecute);
      expect(decideAction('task.complete'), Decision.autoExecute);
      expect(decideAction('music.play'), Decision.autoExecute);
      expect(decideAction('memory.save'), Decision.autoExecute);
    });

    test('sensitive/destructive/external need confirmation', () {
      expect(decideAction('alarm.toggle'), Decision.confirm);
      expect(decideAction('task.delete'), Decision.confirm);
      expect(decideAction('alarm.delete'), Decision.confirm);
      expect(decideAction('memory.forget'), Decision.confirm);
      expect(decideAction('device.open_app'), Decision.confirm);
      expect(decideAction('device.open_settings'), Decision.confirm);
    });

    test('every catalogued tool has a policy decision', () {
      for (final spec in kJarvisToolSpecs) {
        expect(
          decideAction(spec.name),
          anyOf(Decision.autoExecute, Decision.confirm),
          reason: '${spec.name} must be classifiable',
        );
      }
    });

    test('descriptions are human readable', () {
      expect(
        describeAction('task.delete', {'match': 'Buy milk'}),
        contains('Buy milk'),
      );
      expect(describeAction('alarm.toggle', {'match': '07:00', 'enabled': false}), contains('Turn off'));
      expect(
        describeAction(
          'device.open_settings',
          {'page': 'wifi'},
        ),
        contains('wifi'),
      );
    });
  });

  group('tool argument validation', () {
    ToolSpec spec(String name) => kJarvisToolsByName[name]!;

    test('valid task.create coerces numbers-as-strings and drops nothing', () {
      final result = validateToolArgs(spec('task.create'), {
        'title': '  Buy milk ',
        'priority': 'HIGH',
      });
      expect(result.isValid, isTrue);
      expect(result.args['title'], 'Buy milk');
      expect(result.args['priority'], 'high');
    });

    test('missing required argument fails', () {
      final result = validateToolArgs(spec('task.create'), const {});
      expect(result.isValid, isFalse);
      expect(result.errors.single, contains('title'));
    });

    test('unknown arguments are rejected', () {
      final result = validateToolArgs(spec('task.create'), {
        'title': 'x',
        'evil': 'payload',
      });
      expect(result.isValid, isFalse);
      expect(result.errors.single, contains('evil'));
    });

    test('hour and minute range checks', () {
      final bad = validateToolArgs(spec('alarm.set'), {
        'hour': 24,
        'minute': 60,
      });
      expect(bad.isValid, isFalse);
      expect(bad.errors, hasLength(2));

      final good = validateToolArgs(spec('alarm.set'), {
        'hour': '7',
        'minute': 5,
      });
      expect(good.isValid, isTrue);
      expect(good.args['hour'], 7);
      expect(good.args['minute'], 5);
    });

    test('bool accepts strings, rejects anything else', () {
      expect(
        validateToolArgs(spec('alarm.toggle'), {
          'match': '07:00',
          'enabled': 'false',
        }).args['enabled'],
        isFalse,
      );
      expect(
        validateToolArgs(spec('alarm.toggle'), {
          'match': '07:00',
          'enabled': 'maybe',
        }).isValid,
        isFalse,
      );
    });

    test('enum values are case-normalised', () {
      final result = validateToolArgs(spec('event.list'), {'when': 'Week'});
      expect(result.args['when'], 'week');
      expect(
        validateToolArgs(spec('event.list'), {'when': 'decade'}).isValid,
        isFalse,
      );
    });

    test('datetime accepts ISO and space-separated forms, rejects junk', () {
      final iso = validateToolArgs(spec('reminder.create'), {
        'text': 'Stand up',
        'fire_at': '2026-10-21T09:00:00',
      });
      expect(iso.isValid, isTrue);
      expect(iso.args['fire_at'], isA<DateTime>());

      final spaced = validateToolArgs(spec('reminder.create'), {
        'text': 'Stand up',
        'fire_at': '2026-10-21 09:00',
      });
      expect(spaced.isValid, isTrue);
      expect((spaced.args['fire_at'] as DateTime).hour, 9);

      expect(
        validateToolArgs(spec('reminder.create'), {
          'text': 'Stand up',
          'fire_at': 'tomorrowish',
        }).isValid,
        isFalse,
      );
    });

    test('days list accepts arrays and comma strings, rejects 7', () {
      final asList = validateToolArgs(spec('alarm.set'), {
        'hour': 7,
        'minute': 0,
        'days': [0, 2, 4],
      });
      expect(asList.args['days'], [0, 2, 4]);

      final asText = validateToolArgs(spec('alarm.set'), {
        'hour': 7,
        'minute': 0,
        'days': '1, 3',
      });
      expect(asText.args['days'], [1, 3]);

      expect(
        validateToolArgs(spec('alarm.set'), {
          'hour': 7,
          'minute': 0,
          'days': [7],
        }).isValid,
        isFalse,
      );
    });

    test('task.update requires at least one change', () {
      expect(
        validateToolArgs(spec('task.update'), {'match': 'milk'}).isValid,
        isFalse,
      );
      expect(
        validateToolArgs(spec('task.update'), {
          'match': 'milk',
          'priority': 'high',
        }).isValid,
        isTrue,
      );
    });

    test('optional null args are treated as absent', () {
      final result = validateToolArgs(spec('note.create'), {
        'body': 'hello',
        'title': null,
      });
      expect(result.isValid, isTrue);
      expect(result.args.containsKey('title'), isFalse);
    });

    test('empty required strings fail', () {
      expect(
        validateToolArgs(spec('task.create'), {'title': '   '}).isValid,
        isFalse,
      );
    });

    test('amount bounds for expense.create', () {
      expect(
        validateToolArgs(spec('expense.create'), {'amount': 0}).isValid,
        isFalse,
      );
      expect(
        validateToolArgs(spec('expense.create'), {
          'amount': '12.5',
        }).args['amount'],
        12.5,
      );
    });
  });

  group('prompt assembly', () {
    final now = DateTime(2026, 10, 19, 17, 5);

    test('system prompt carries clock, locale, context and protocol', () {
      final prompt = buildSystemPrompt(
        PromptContext(
          now: now,
          uiLocale: 'kn',
          timeZoneLabel: 'IST',
          memories: ['User prefers metric units.'],
          workspaceFacts: ['3 open tasks.', 'Next alarm 07:00.'],
        ),
      );
      expect(prompt, contains('Monday, 19 October 2026, 17:05 (IST)'));
      expect(prompt, contains('kn'));
      expect(prompt, contains('User prefers metric units.'));
      expect(prompt, contains('Next alarm 07:00.'));
      expect(prompt, contains('```action'));
      expect(prompt, contains('TOOL RESULT'));
      for (final spec in kJarvisToolSpecs) {
        expect(prompt, contains(spec.name), reason: spec.name);
      }
    });

    test('empty context blocks stay honest', () {
      final prompt = buildSystemPrompt(PromptContext(now: now, uiLocale: 'en'));
      expect(prompt, contains('(none saved yet)'));
      expect(prompt, contains('(not loaded)'));
    });

    test('formatNow without timezone label', () {
      expect(formatNow(now), 'Monday, 19 October 2026, 17:05');
    });

    test('estimateTokens', () {
      expect(estimateTokens(''), 0);
      expect(estimateTokens('   '), 0);
      expect(estimateTokens('hello world'), greaterThan(0));
    });

    test('toolResultTurn starts with the marker', () {
      final turn = toolResultTurn('task.list', '- Buy milk');
      expect(turn.role, ChatRole.user);
      expect(turn.content, startsWith('TOOL RESULT [task.list]'));
      expect(turn.content, contains('- Buy milk'));
    });

    test('system prompt tells the model not to show reasoning', () {
      final prompt = buildSystemPrompt(PromptContext(now: now, uiLocale: 'en'));
      expect(prompt, contains('Do not show your reasoning'));
    });

    test('tool catalogue is compact (signature, no verbose Args prose)', () {
      final prompt = buildSystemPrompt(PromptContext(now: now, uiLocale: 'en'));
      // Signature form derived from the spec, with required/optional marks.
      expect(prompt, contains('task.create(title!, due?=ISO'));
      expect(prompt, contains('alarm.set(hour!=int0-23'));
      // The old verbose "Args:" prose must be gone (it dominated prefill).
      expect(prompt, isNot(contains('Args:')));
      // Still compact enough to keep prefill cheap on-device.
      expect(estimateTokens(prompt), lessThan(1100));
    });
  });

  group('thinking suppression', () {
    test('withNoThinkDirective appends the switch to a user turn', () {
      final turn = withNoThinkDirective(ChatTurn.user('what time is it?'));
      expect(turn.content, endsWith(kNoThinkDirective));
      expect(turn.content, startsWith('what time is it?'));
    });

    test('withNoThinkDirective never doubles up or touches non-user turns', () {
      final already = withNoThinkDirective(
        ChatTurn.user('hi /no_think'),
      );
      expect(already.content, 'hi /no_think');
      expect(
        withNoThinkDirective(ChatTurn.assistant('hello')).content,
        'hello',
      );
    });

    test('withNoThinkDirective leaves an explicit /think alone', () {
      final turn = withNoThinkDirective(ChatTurn.user('think hard /think'));
      expect(turn.content, 'think hard /think');
    });

    test('stripThinking removes a Thinking Process block', () {
      const raw = 'Thinking Process:\n'
          '1. Look up the current time.\n'
          '2. The clock says 4:36.\n\n'
          'It is 4:36 PM right now.';
      expect(stripThinking(raw), 'It is 4:36 PM right now.');
    });

    test('stripThinking removes a fenced think block', () {
      final raw = '$kThinkStart\n'
          'The user asked the time. The system prompt says 16:36.\n'
          '$kThinkEnd\n'
          'The time is 4:36 PM.';
      expect(stripThinking(raw), 'The time is 4:36 PM.');
    });

    test('stripThinking drops a mid-stream open think fence', () {
      final raw = '$kThinkStart\nThe user asked the time. The clock says';
      expect(stripThinking(raw), 'The user asked the time. The clock says');
    });

    test('stripThinking passes clean text through untouched', () {
      const raw = 'Your next alarm is at 07:00.';
      expect(stripThinking(raw), raw);
    });

    test('stripThinking strips a leaked think fence', () {
      const raw = 'think\nDone — task created.';
      expect(stripThinking(raw), 'Done — task created.');
    });
  });

  group('history windowing', () {
    final system = List.filled(10, 'SYSTEM PROMPT ').join().trim();

    test('keeps system first and drops oldest turns to fit', () {
      final padding = List.filled(120, 'x').join();
      final history = <ChatTurn>[
        for (var i = 0; i < 40; i++) ChatTurn.user('message number $i $padding'),
      ];
      final window = buildConversation(
        systemPrompt: system,
        history: history,
        tokenBudget: 800,
      );

      expect(window.first.role, ChatRole.system);
      expect(window.first.content, system);
      expect(window.length, lessThan(history.length + 1));
      // The newest turn survives, the oldest do not.
      expect(window.last.content, history.last.content);
      expect(
        window.any((t) => t.content == history.first.content),
        isFalse,
      );
      // Everything sent (plus reserved reply room) stays inside budget.
      final sent = window.fold<int>(
        0,
        (sum, t) => sum + estimateTokens(t.content) + 8,
      );
      expect(sent + 512, lessThanOrEqualTo(800 + 64));
    });

    test('short conversations are sent whole', () {
      final history = [
        ChatTurn.user('hi'),
        ChatTurn.assistant('hello!'),
        ChatTurn.user('what time is it?'),
      ];
      final window = buildConversation(
        systemPrompt: system,
        history: history,
        tokenBudget: 4000,
      );
      expect(window, hasLength(4));
      expect(window.first.content, system);
      expect(
        window.sublist(1).map((t) => t.content),
        history.map((t) => t.content),
      );
    });

    test('an oversized single turn keeps its tail', () {
      final huge = ChatTurn.user('A' * 4000);
      final window = buildConversation(
        systemPrompt: 'sys',
        history: [huge],
        tokenBudget: 400,
      );
      final last = window.last;
      expect(last.content.length, lessThan(huge.content.length));
      expect(last.content, endsWith('A'));
      expect(last.content, startsWith('…'));
    });
  });
}
