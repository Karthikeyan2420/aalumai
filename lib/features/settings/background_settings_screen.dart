import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/backgrounds/background_config.dart';
import '../../core/backgrounds/background_presets.dart';
import '../../core/backgrounds/background_providers.dart';
import '../../core/widgets/background_view.dart';

/// Lets the user customise the Home or Alarm background independently.
///
/// Offers bundled image presets, solid colours, gradients and a custom image
/// picked from the device, plus a live preview and a reset-to-default action.
/// All choices are persisted locally through [BackgroundController]; nothing
/// leaves the device.
class BackgroundSettingsScreen extends ConsumerWidget {
  const BackgroundSettingsScreen({super.key, required this.slot});

  final BackgroundSlot slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(backgroundProviderFor(slot));
    final controller = ref.read(backgroundProviderFor(slot).notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          slot == BackgroundSlot.home ? 'Home background' : 'Alarm background',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _Preview(slot: slot, config: config),
          ListTile(
            key: const ValueKey('bg_reset'),
            leading: const Icon(Icons.restart_alt),
            title: const Text('Reset to default'),
            subtitle: const Text('Restore the built-in appearance'),
            trailing: const Icon(Icons.chevron_right),
            onTap: controller.reset,
          ),
          const Divider(),
          const _SectionHeader('Images'),
          _ImagePresetRow(slot: slot, current: config),
          _CustomImageTile(slot: slot, current: config),
          if (config.isImage) ...[
            const _SectionHeader('Readability'),
            _DimSlider(value: config.dim, onChanged: controller.setDim),
          ],
          const Divider(),
          const _SectionHeader('Solid colours'),
          _SwatchGrid(
            swatches: [
              for (final preset in BackgroundPresets.solidPresets(slot))
                _Swatch(
                  config: preset,
                  selected: config == preset,
                  onTap: () => controller.apply(preset),
                ),
            ],
          ),
          const Divider(),
          const _SectionHeader('Gradients'),
          _SwatchGrid(
            swatches: [
              for (final preset in BackgroundPresets.gradientPresets(slot))
                _Swatch(
                  config: preset,
                  selected: config == preset,
                  onTap: () => controller.apply(preset),
                  showLabel: true,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.slot, required this.config});

  final BackgroundSlot slot;
  final BackgroundConfig config;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAlarm = slot == BackgroundSlot.alarm;
    final textColor = isAlarm ? Colors.white : theme.colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 200,
          child: BackgroundView(
            config: config,
            fallback: BackgroundPresets.defaultFor(slot),
            overlayColor: isAlarm ? Colors.black : theme.colorScheme.surface,
            minOverlay: isAlarm ? 0.45 : 0.35,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isAlarm ? '07:30' : 'Preview',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isAlarm ? 'Solve to dismiss' : 'Today is a good day',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImagePresetRow extends StatelessWidget {
  const _ImagePresetRow({required this.slot, required this.current});

  final BackgroundSlot slot;
  final BackgroundConfig current;

  @override
  Widget build(BuildContext context) {
    final presets = BackgroundPresets.imagePresets(slot);
    return SizedBox(
      height: 156,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: presets.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final preset = presets[index];
          final selected = current == preset.config;
          return _ImagePresetTile(
            slot: slot,
            preset: preset,
            selected: selected,
          );
        },
      ),
    );
  }
}

class _ImagePresetTile extends ConsumerWidget {
  const _ImagePresetTile({
    required this.slot,
    required this.preset,
    required this.selected,
  });

  final BackgroundSlot slot;
  final BackgroundPreset preset;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return InkWell(
      key: ValueKey('bg_image_${preset.id}'),
      borderRadius: BorderRadius.circular(16),
      onTap:
          () => ref
              .read(backgroundProviderFor(slot).notifier)
              .apply(preset.config),
      child: SizedBox(
        width: 104,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 104,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                  width: selected ? 3 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      preset.config.assetPath!,
                      fit: BoxFit.cover,
                      cacheWidth: 240,
                    ),
                    if (selected)
                      Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.check_circle,
                            color: theme.colorScheme.primary,
                            size: 22,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              preset.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomImageTile extends ConsumerStatefulWidget {
  const _CustomImageTile({required this.slot, required this.current});

  final BackgroundSlot slot;
  final BackgroundConfig current;

  @override
  ConsumerState<_CustomImageTile> createState() => _CustomImageTileState();
}

class _CustomImageTileState extends ConsumerState<_CustomImageTile> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final isCustom = widget.current.kind == BackgroundKind.file;
    return ListTile(
      key: const ValueKey('bg_custom_image'),
      leading: const Icon(Icons.photo_library_outlined),
      title: const Text('Choose image from device'),
      subtitle: Text(
        isCustom
            ? (widget.current.label ?? 'Custom image')
            : 'Stored locally; never uploaded',
      ),
      trailing:
          _busy
              ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
              : const Icon(Icons.chevron_right),
      onTap: _busy ? null : _pick,
    );
  }

  Future<void> _pick() async {
    setState(() => _busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: false,
      );
      final sourcePath = result?.files.single.path;
      if (sourcePath == null) return;

      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(docs.path, 'backgrounds'));
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final ext = p.extension(sourcePath);
      final dest = p.join(
        dir.path,
        '${widget.slot.key}_${DateTime.now().millisecondsSinceEpoch}$ext',
      );
      await File(sourcePath).copy(dest);

      final label = p.basename(sourcePath);
      await ref
          .read(backgroundProviderFor(widget.slot).notifier)
          .apply(
            BackgroundConfig(
              kind: BackgroundKind.file,
              filePath: dest,
              dim: 0.35,
              label: label,
            ),
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't use that image.")),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _DimSlider extends StatelessWidget {
  const _DimSlider({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.brightness_medium, size: 18),
              const SizedBox(width: 8),
              const Text('Dim'),
              const Spacer(),
              Text('${(value * 100).round()}%'),
            ],
          ),
          Slider(
            value: value.clamp(0, 0.9),
            min: 0,
            max: 0.9,
            divisions: 9,
            label: '${(value * 100).round()}%',
            onChanged: onChanged,
          ),
          const Text(
            'Keeps the time and text readable over the image.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Swatch {
  const _Swatch({
    required this.config,
    required this.selected,
    required this.onTap,
    this.showLabel = false,
  });

  final BackgroundConfig config;
  final bool selected;
  final VoidCallback onTap;
  final bool showLabel;
}

class _SwatchGrid extends StatelessWidget {
  const _SwatchGrid({required this.swatches});

  final List<_Swatch> swatches;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final swatch in swatches)
            InkWell(
              key: ValueKey('bg_swatch_${swatch.config.label ?? ''}'),
              borderRadius: BorderRadius.circular(14),
              onTap: swatch.onTap,
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color:
                            swatch.selected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outlineVariant,
                        width: swatch.selected ? 3 : 1,
                      ),
                      color:
                          swatch.config.kind == BackgroundKind.solid
                              ? Color(swatch.config.color ?? 0xFF000000)
                              : null,
                      gradient:
                          swatch.config.kind == BackgroundKind.gradient
                              ? LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors:
                                    swatch.config.gradientColors
                                        .map(Color.new)
                                        .toList(),
                              )
                              : null,
                    ),
                    child:
                        swatch.selected
                            ? Icon(
                              Icons.check,
                              color: theme.colorScheme.primary,
                            )
                            : null,
                  ),
                  if (swatch.showLabel && swatch.config.label != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: SizedBox(
                        width: 72,
                        child: Text(
                          swatch.config.label!,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.secondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
