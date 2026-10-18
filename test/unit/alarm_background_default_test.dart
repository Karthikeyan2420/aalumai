import 'package:aalumai/core/backgrounds/background_config.dart';
import 'package:aalumai/core/backgrounds/background_presets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the alarm slot defaults to the bundled backdrop image', () {
    final def = BackgroundPresets.defaultFor(BackgroundSlot.alarm);
    expect(def.kind, BackgroundKind.asset);
    expect(def.assetPath, BackgroundAssets.alarmBackdrop);
    expect(def.dim, greaterThan(0), reason: 'the time must stay readable');
    expect(BackgroundAssets.all, contains(BackgroundAssets.alarmBackdrop));
  });

  test('the backdrop is offered as a selectable alarm image preset', () {
    final images = BackgroundPresets.imagePresets(BackgroundSlot.alarm);
    expect(
      images.any((p) => p.config.assetPath == BackgroundAssets.alarmBackdrop),
      isTrue,
    );
  });

  test('the alarm image row offers only bundled alarm assets', () {
    final images = BackgroundPresets.imagePresets(BackgroundSlot.alarm);
    expect(images, isNotEmpty);
    for (final preset in images) {
      expect(
        BackgroundAssets.all,
        contains(preset.config.assetPath),
        reason: '${preset.id} must be a bundled image',
      );
    }
  });
}
