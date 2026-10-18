import 'dart:convert';

import 'package:aalumai/core/backgrounds/background_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BackgroundConfig.isValid', () {
    test('valid solid needs a colour', () {
      expect(const BackgroundConfig.solid(0xFF0B1F3A).isValid, isTrue);
      expect(
        const BackgroundConfig(kind: BackgroundKind.solid).isValid,
        isFalse,
      );
    });

    test('valid gradient needs at least two stops', () {
      expect(
        const BackgroundConfig.gradient([0xFF000000, 0xFF111111]).isValid,
        isTrue,
      );
      expect(const BackgroundConfig.gradient([0xFF000000]).isValid, isFalse);
    });

    test('asset and file need a path', () {
      expect(const BackgroundConfig.asset('assets/x.jpg').isValid, isTrue);
      expect(
        const BackgroundConfig(kind: BackgroundKind.asset).isValid,
        isFalse,
      );
      expect(
        const BackgroundConfig(kind: BackgroundKind.file).isValid,
        isFalse,
      );
      expect(
        const BackgroundConfig(
          kind: BackgroundKind.file,
          filePath: '/a/b.jpg',
        ).isValid,
        isTrue,
      );
    });
  });

  group('BackgroundConfig JSON', () {
    test('round-trips every kind', () {
      const configs = <BackgroundConfig>[
        BackgroundConfig.solid(0xFF05070D, label: 'Near black'),
        BackgroundConfig.gradient([0xFF0B1F3A, 0xFF050A14], label: 'Night'),
        BackgroundConfig.asset('assets/images/a.jpg', label: 'A', dim: 0.4),
        BackgroundConfig(
          kind: BackgroundKind.file,
          filePath: '/docs/bg/custom.jpg',
          dim: 0.35,
          label: 'custom.jpg',
        ),
      ];
      for (final config in configs) {
        final parsed = BackgroundConfig.tryParse(
          jsonDecode(jsonEncode(config.toJson())),
        );
        expect(parsed, config, reason: 'round trip failed for ${config.kind}');
      }
    });

    test('rejects unknown kinds and malformed values', () {
      expect(BackgroundConfig.tryParse(null), isNull);
      expect(BackgroundConfig.tryParse('nonsense'), isNull);
      expect(BackgroundConfig.tryParse(<String, dynamic>{}), isNull);
      expect(
        BackgroundConfig.tryParse(<String, dynamic>{'kind': 'sparkle'}),
        isNull,
      );
      expect(
        BackgroundConfig.tryParse(<String, dynamic>{'kind': 'solid'}),
        isNull,
      );
      expect(
        BackgroundConfig.tryParse(<String, dynamic>{
          'kind': 'gradient',
          'gradient': <int>[1],
        }),
        isNull,
      );
    });

    test('clamps dim into 0..1', () {
      final parsed = BackgroundConfig.tryParse(<String, dynamic>{
        'kind': 'asset',
        'asset': 'assets/images/a.jpg',
        'dim': 99,
      });
      expect(parsed, isNotNull);
      expect(parsed!.dim, 1.0);
    });
  });

  group('BackgroundConfig equality', () {
    test('configs with different colour are not equal', () {
      expect(
        const BackgroundConfig.solid(0xFF000000),
        isNot(const BackgroundConfig.solid(0xFF111111)),
      );
      expect(
        const BackgroundConfig.solid(0xFF000000),
        const BackgroundConfig.solid(0xFF000000),
      );
    });

    test('gradient stop order matters', () {
      expect(
        const BackgroundConfig.gradient([0xFF000000, 0xFF111111]),
        isNot(const BackgroundConfig.gradient([0xFF111111, 0xFF000000])),
      );
    });
  });
}
