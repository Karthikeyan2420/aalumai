import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/localization/l10n_extension.dart';
import '../../core/widgets/common.dart';
import 'data/run_tracker.dart';
import 'domain/geo.dart';
import 'widgets/route_map.dart';

/// Records a GPS run or walk, showing live distance, time and pace. The
/// finished session is stored as a normal workout session (type run/walk) with
/// its route.
class RunWalkScreen extends ConsumerStatefulWidget {
  const RunWalkScreen({super.key});

  @override
  ConsumerState<RunWalkScreen> createState() => _RunWalkScreenState();
}

class _RunWalkScreenState extends ConsumerState<RunWalkScreen> {
  RunType _selected = RunType.run;
  LatLng? _mapCenter;

  @override
  void initState() {
    super.initState();
    _loadMapCenter();
  }

  Future<void> _loadMapCenter() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      return;
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
      ),
    );
    if (!mounted) return;
    setState(
      () => _mapCenter = LatLng(position.latitude, position.longitude),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final state = ref.watch(runTrackerProvider);
    final controller = ref.read(runTrackerProvider.notifier);

    return PopScope(
      canPop: !state.active,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !state.active) return;
        await _leave(context, controller);
      },
      child: Scaffold(
        appBar: AppBar(title: Text('${l10n.run} / ${l10n.walk}')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!state.active)
                  SegmentedButton<RunType>(
                    segments: [
                      ButtonSegment(
                        value: RunType.run,
                        icon: const Icon(Icons.directions_run),
                        label: Text(l10n.run),
                      ),
                      ButtonSegment(
                        value: RunType.walk,
                        icon: const Icon(Icons.directions_walk),
                        label: Text(l10n.walk),
                      ),
                    ],
                    selected: {_selected},
                    onSelectionChanged:
                        (s) => setState(() => _selected = s.first),
                  ),
                const SizedBox(height: 16),
                Expanded(
                  child: RouteMapView(
                    points: state.points,
                    active: state.active,
                    emptyHint: l10n.waitingForGps,
                    initialCenter: _mapCenter,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  formatDistanceKm(state.distanceMeters),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.distance,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _Stat(
                      label: l10n.time,
                      value: formatRunDuration(state.elapsedSec),
                    ),
                    _Stat(label: l10n.pace, value: formatPace(state.pacePerKm)),
                  ],
                ),
                if (state.error != null) ...[
                  const SizedBox(height: 16),
                  _ErrorNotice(error: state.error!),
                ],
                const SizedBox(height: 16),
                if (!state.active)
                  FilledButton.icon(
                    onPressed:
                        () => controller.start(
                          type: _selected,
                          name: _selected == RunType.run ? l10n.run : l10n.walk,
                        ),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(l10n.start),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed:
                              state.paused
                                  ? controller.resume
                                  : controller.pause,
                          icon: Icon(
                            state.paused ? Icons.play_arrow : Icons.pause,
                          ),
                          label: Text(state.paused ? l10n.resume : l10n.pause),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _stop(context, controller),
                          icon: const Icon(Icons.stop),
                          label: Text(l10n.stop),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _leave(
    BuildContext context,
    RunTrackerController controller,
  ) async {
    final l10n = context.l10n;
    final action = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.stop),
            content: Text(l10n.saveActivityPrompt),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'discard'),
                child: Text(l10n.discard),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, 'save'),
                child: Text(l10n.save),
              ),
            ],
          ),
    );
    if (!context.mounted || action == null) return;
    if (action == 'save') {
      await controller.stopAndSave();
    } else {
      await controller.discard();
    }
    if (!mounted) return;
    _closeAfterTrackingStops();
  }

  /// Pops on the next frame, after [runTrackerProvider] has rebuilt [PopScope]
  /// with `canPop` true.
  void _closeAfterTrackingStops() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _stop(
    BuildContext context,
    RunTrackerController controller,
  ) async {
    final l10n = context.l10n;
    final confirmed = await confirmDialog(
      context,
      title: l10n.stop,
      body: l10n.saveActivityPrompt,
      confirmLabel: l10n.save,
    );
    if (!confirmed || !context.mounted) return;
    await controller.stopAndSave();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.done)));
    _closeAfterTrackingStops();
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isPermission = error == 'permission';
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isPermission ? l10n.permissionDeniedTitle : l10n.errorTitle,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(isPermission ? l10n.permissionDeniedBody : l10n.locationLabel),
            if (isPermission)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Geolocator.openAppSettings(),
                  child: Text(l10n.settings),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
