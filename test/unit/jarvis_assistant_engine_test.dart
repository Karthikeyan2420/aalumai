import 'package:aalumai/features/jarvis/assistant_engine/calculator.dart'
    as calc;
import 'package:aalumai/features/jarvis/assistant_engine/intent.dart';
import 'package:aalumai/features/jarvis/assistant_engine/intent_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calculator', () {
    test('evaluates arithmetic with precedence', () {
      expect(calc.evaluate('2 + 3 * 4'), 14);
      expect(calc.evaluate('(2 + 3) * 4'), 20);
      expect(calc.evaluate('10 / 4'), 2.5);
      expect(calc.evaluate('2 ^ 3'), 8);
    });

    test('rejects division by zero', () {
      expect(
        () => calc.evaluate('1 / 0'),
        throwsA(isA<calc.CalculatorException>()),
      );
    });

    test('tryEvaluate understands spoken operators', () {
      expect(calc.tryEvaluate('what is 6 times 7'), 42);
      expect(calc.tryEvaluate('calculate 20 divided by 5'), 4);
      expect(calc.tryEvaluate('9 minus 4'), 5);
    });

    test('tryEvaluate ignores non-expressions', () {
      expect(calc.tryEvaluate('hello there'), isNull);
      expect(calc.tryEvaluate('open whatsapp'), isNull);
    });

    test('formatNumber drops trailing zeros', () {
      expect(calc.formatNumber(14.0), '14');
      expect(calc.formatNumber(2.5), '2.5');
    });
  });

  group('unit conversion', () {
    test('length conversion', () {
      final c = calc.tryParseConversion('convert 5 km to miles');
      expect(c, isNotNull);
      expect(c!.result(), closeTo(3.10686, 0.0001));
    });

    test('temperature conversion', () {
      final c = calc.tryParseConversion('100 celsius to fahrenheit');
      expect(c, isNotNull);
      expect(c!.result(), closeTo(212, 0.001));
    });

    test('rejects incompatible units', () {
      expect(calc.tryParseConversion('5 kg to miles'), isNull);
    });
  });

  group('intent matcher', () {
    final matcher = IntentMatcher(clock: () => DateTime(2026, 10, 22, 14, 30));

    test('greetings', () {
      expect(matcher.match('hello').kind, IntentKind.greeting);
      expect(matcher.match('good morning').kind, IntentKind.greeting);
    });

    test('time and date', () {
      expect(matcher.match('what is the time').kind, IntentKind.time);
      expect(matcher.match('what is the date').kind, IntentKind.date);
      expect(matcher.match('what day is it').kind, IntentKind.dayOfWeek);
    });

    test('arithmetic', () {
      final intent = matcher.match('calculate 12 * 12');
      expect(intent.kind, IntentKind.calculate);
      expect(intent.slot<num>('value'), 144);
    });

    test('alarm.set extracts time', () {
      final intent = matcher.match('set an alarm for 7:30 am');
      expect(intent.kind, IntentKind.alarmSet);
      expect(intent.slot<int>('hour'), 7);
      expect(intent.slot<int>('minute'), 30);
    });

    test('alarm.set with weekday repeat', () {
      final intent = matcher.match('wake me at 6 am every weekday');
      expect(intent.kind, IntentKind.alarmSet);
      expect(intent.slot<int>('hour'), 6);
      expect(intent.slot<List<int>>('days'), [0, 1, 2, 3, 4]);
    });

    test('reminder with duration', () {
      final intent = matcher.match('remind me to call mom in 10 minutes');
      expect(intent.kind, IntentKind.setReminder);
      expect(intent.slot<int>('duration_seconds'), 600);
      expect(intent.slot<String>('text'), contains('call mom'));
    });

    test('timer with duration', () {
      final intent = matcher.match('set a timer for 90 seconds');
      expect(intent.kind, IntentKind.setTimer);
      expect(intent.slot<int>('duration_seconds'), 90);
    });

    test('task creation', () {
      final intent = matcher.match('add a task to buy milk');
      expect(intent.kind, IntentKind.taskCreate);
      expect(intent.slot<String>('title'), 'buy milk');
    });

    test('battery', () {
      expect(matcher.match('how is my battery').kind, IntentKind.battery);
    });

    test('open app maps to package', () {
      final intent = matcher.match('open whatsapp');
      expect(intent.kind, IntentKind.openApp);
      expect(intent.slot<String>('package'), 'com.whatsapp');
    });

    test('open settings maps the page', () {
      final intent = matcher.match('open wifi settings');
      expect(intent.kind, IntentKind.openSettings);
      expect(intent.slot<String>('page'), 'wifi');
    });

    test('expense creation extracts amount', () {
      final intent = matcher.match('i spent 250 on groceries');
      expect(intent.kind, IntentKind.expenseCreate);
      expect(intent.slot<num>('amount'), 250);
      expect(intent.slot<String>('type'), 'expense');
    });

    test('weather', () {
      expect(matcher.match('what is the weather').kind, IntentKind.weather);
    });

    test('unknown questions become questions', () {
      expect(
        matcher.match('what is the capital of india').kind,
        IntentKind.question,
      );
    });

    test('empty input is unknown', () {
      expect(matcher.match('   ').kind, IntentKind.unknown);
    });
  });
}
