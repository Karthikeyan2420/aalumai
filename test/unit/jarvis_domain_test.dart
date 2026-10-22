import 'package:aalumai/features/jarvis/domain/safety_policy.dart';
import 'package:aalumai/features/jarvis/domain/tool_specs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
      expect(
        describeAction('alarm.toggle', {'match': '07:00', 'enabled': false}),
        contains('Turn off'),
      );
      expect(
        describeAction('device.open_settings', {'page': 'wifi'}),
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
}
