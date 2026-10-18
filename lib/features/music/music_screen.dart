import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/db/database.dart';
import '../../core/localization/l10n_extension.dart';
import 'add_to_collection.dart';
import 'data/music_providers.dart';
import 'data/music_repository.dart';
import 'data/player_service.dart';
import 'music_stats_screen.dart';
import 'tabs/collections_tab.dart';
import 'tabs/favorites_tab.dart';
import 'tabs/folders_tab.dart';
import 'track_actions.dart';
import 'widgets/mini_player.dart';
import 'widgets/music_widgets.dart';

/// The music library: searchable, sortable, date-grouped song list with tabs
/// for folders, favourites, playlists and labels, plus a persistent mini
/// player.
class MusicScreen extends ConsumerStatefulWidget {
  const MusicScreen({super.key});

  @override
  ConsumerState<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends ConsumerState<MusicScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchCtrl = TextEditingController();
  bool _searching = false;
  final _selected = <int>{};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  bool get _selectionMode => _selected.isNotEmpty;

  void _scan() {
    ref.read(scanControllerProvider.notifier).scan();
  }

  @override
  Widget build(BuildContext context) {
    final scanPhase = ref.watch(scanControllerProvider);
    ref.listen(scanControllerProvider, (previous, next) {
      if (next == ScanPhase.done && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.scanComplete)));
      }
    });

    if (scanPhase == ScanPhase.permissionDenied ||
        scanPhase == ScanPhase.permissionPermanentlyDenied) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.music)),
        body: MusicPermissionView(
          permanentlyDenied: scanPhase == ScanPhase.permissionPermanentlyDenied,
          onGrant: _scan,
          onOpenSettings: openAppSettings,
        ),
      );
    }

    final query = ref.watch(libraryQueryProvider);
    final tracksAsync = ref.watch(musicTracksProvider);

    return Scaffold(
      appBar:
          _selectionMode
              ? _selectionAppBar(tracksAsync)
              : _searching
              ? _searchAppBar()
              : _normalAppBar(query),
      body: Column(
        children: [
          if (scanPhase == ScanPhase.scanning)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _SongsTab(
                  selectionMode: _selectionMode,
                  selected: _selected,
                  onToggle: _toggle,
                  onEnterSelection: (id) => setState(() => _selected.add(id)),
                ),
                FoldersTab(onScan: _scan),
                const FavoritesTab(),
                const CollectionsTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const MiniPlayer(),
      floatingActionButton:
          tracksAsync.valueOrNull?.isEmpty == true
              ? FloatingActionButton.extended(
                heroTag: 'musicScanDevice',
                onPressed: _scan,
                icon: const Icon(Icons.refresh),
                label: Text(context.l10n.scanDevice),
              )
              : null,
    );
  }

  PreferredSizeWidget _normalAppBar(LibraryQuery query) {
    return AppBar(
      title: Text(context.l10n.music),
      bottom: _tabBar(),
      actions: [
        IconButton(
          tooltip: context.l10n.search,
          icon: const Icon(Icons.search),
          onPressed: () => setState(() => _searching = true),
        ),
        IconButton(
          tooltip: context.l10n.sortBy,
          icon: Icon(
            query.ascending ? Icons.arrow_upward : Icons.arrow_downward,
          ),
          onPressed:
              () => ref
                  .read(libraryQueryProvider.notifier)
                  .setSort(query.sort, ascending: !query.ascending),
        ),
        PopupMenuButton<TrackSort>(
          tooltip: context.l10n.sortBy,
          icon: const Icon(Icons.sort),
          onSelected:
              (sort) => ref.read(libraryQueryProvider.notifier).setSort(sort),
          itemBuilder:
              (context) => [
                for (final sort in TrackSort.values)
                  CheckedPopupMenuItem(
                    value: sort,
                    checked: query.sort == sort,
                    child: Text(_sortLabel(sort)),
                  ),
              ],
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'scan') {
              _scan();
            } else if (value == 'stats') {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MusicStatsScreen(),
                ),
              );
            }
          },
          itemBuilder:
              (context) => [
                PopupMenuItem(
                  value: 'scan',
                  child: Text(context.l10n.scanDevice),
                ),
                PopupMenuItem(
                  value: 'stats',
                  child: Text(context.l10n.statistics),
                ),
              ],
        ),
      ],
    );
  }

  PreferredSizeWidget _searchAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () {
          _searchCtrl.clear();
          ref.read(libraryQueryProvider.notifier).setSearch('');
          setState(() => _searching = false);
        },
      ),
      title: TextField(
        controller: _searchCtrl,
        autofocus: true,
        decoration: InputDecoration(
          hintText: context.l10n.search,
          border: InputBorder.none,
        ),
        onChanged:
            (value) => ref.read(libraryQueryProvider.notifier).setSearch(value),
      ),
      bottom: _tabBar(),
    );
  }

  PreferredSizeWidget _selectionAppBar(AsyncValue<List<MusicTrack>> tracks) {
    final all = tracks.valueOrNull ?? const <MusicTrack>[];
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => setState(_selected.clear),
      ),
      title: Text('${_selected.length}'),
      actions: [
        IconButton(
          tooltip: context.l10n.selectAll,
          icon: const Icon(Icons.select_all),
          onPressed:
              () => setState(() {
                if (_selected.length == all.length) {
                  _selected.clear();
                } else {
                  _selected
                    ..clear()
                    ..addAll(all.map((t) => t.id));
                }
              }),
        ),
        IconButton(
          tooltip: context.l10n.addToPlaylist,
          icon: const Icon(Icons.playlist_add),
          onPressed: () {
            showAddToCollectionSheet(
              context,
              ref,
              trackIds: _selected.toList(),
            );
            setState(_selected.clear);
          },
        ),
        IconButton(
          tooltip: context.l10n.addToQueue,
          icon: const Icon(Icons.queue_music),
          onPressed: () {
            final chosen = all.where((t) => _selected.contains(t.id)).toList();
            ref.read(musicPlayerProvider.notifier).addManyToQueue(chosen);
            setState(_selected.clear);
          },
        ),
        IconButton(
          tooltip: context.l10n.favorite,
          icon: const Icon(Icons.favorite),
          onPressed: () {
            final repo = ref.read(musicRepositoryProvider);
            for (final id in _selected) {
              repo.setFavorite(id, true);
            }
            setState(_selected.clear);
          },
        ),
      ],
    );
  }

  PreferredSizeWidget _tabBar() {
    return TabBar(
      controller: _tabs,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      tabs: [
        Tab(text: context.l10n.songs),
        Tab(text: context.l10n.folders),
        Tab(text: context.l10n.favorites),
        Tab(text: context.l10n.playlists),
      ],
    );
  }

  void _toggle(int id) {
    setState(() {
      if (!_selected.add(id)) _selected.remove(id);
    });
  }

  String _sortLabel(TrackSort sort) => switch (sort) {
    TrackSort.dateAdded => context.l10n.recentlyAdded,
    TrackSort.dateModified => context.l10n.recentlyAdded,
    TrackSort.title => context.l10n.name,
    TrackSort.artist => context.l10n.artist,
    TrackSort.album => context.l10n.album,
    TrackSort.duration => context.l10n.duration,
    TrackSort.size => context.l10n.size,
  };
}

class _SongsTab extends ConsumerWidget {
  const _SongsTab({
    required this.selectionMode,
    required this.selected,
    required this.onToggle,
    required this.onEnterSelection,
  });

  final bool selectionMode;
  final Set<int> selected;
  final ValueChanged<int> onToggle;
  final ValueChanged<int> onEnterSelection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(libraryQueryProvider);
    final async = ref.watch(visibleTracksProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (tracks) {
        if (tracks.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.music_note,
                    size: 48,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.emptyMusic,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          );
        }
        final items = _group(tracks, query);
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 12),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            if (item is DateBucket) {
              return GroupHeader(title: _bucketLabel(context, item));
            }
            final track = item as MusicTrack;
            final current =
                ref.watch(musicPlayerProvider).current?.id == track.id;
            return TrackTile(
              track: track,
              isCurrent: current,
              selectionMode: selectionMode,
              selected: selected.contains(track.id),
              onTap:
                  selectionMode
                      ? () => onToggle(track.id)
                      : () => ref
                          .read(musicPlayerProvider.notifier)
                          .playQueue(tracks, tracks.indexOf(track)),
              onLongPress: () => onEnterSelection(track.id),
              onFavorite:
                  () => ref.read(musicRepositoryProvider).toggleFavorite(track),
              onMenu: () => showTrackActions(context, ref, track),
            );
          },
        );
      },
    );
  }

  List<Object> _group(List<MusicTrack> tracks, LibraryQuery query) {
    final grouped = query.sort == TrackSort.dateAdded && query.search.isEmpty;
    if (!grouped) return tracks;
    final now = DateTime.now();
    final items = <Object>[];
    DateBucket? last;
    for (final t in tracks) {
      final bucket = bucketFor(dateAddedOf(t), now);
      if (bucket != last) {
        items.add(bucket);
        last = bucket;
      }
      items.add(t);
    }
    return items;
  }

  String _bucketLabel(BuildContext context, DateBucket bucket) {
    final l10n = context.l10n;
    return switch (bucket) {
      DateBucket.today => l10n.today,
      DateBucket.yesterday => l10n.yesterday,
      DateBucket.thisWeek => l10n.thisWeek,
      DateBucket.earlier => l10n.earlier,
      DateBucket.unknown => l10n.unknown,
    };
  }
}
