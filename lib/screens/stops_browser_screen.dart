import 'package:geolocator/geolocator.dart';
import 'package:material_ui/material_ui.dart';
import '../app_scope.dart';
import '../models/transit_models.dart';
import '../services/favorites_store.dart';
import '../theme/one_ui_theme.dart';
import '../utils/transit_format.dart';
import '../widgets/one_ui_widgets.dart';
import 'departures_screen.dart';
import 'stop_bays_screen.dart';

/// Unified stops browser displaying Favorites, Nearby GPS stops, and full A-Z list on one page.
class StopsBrowserScreen extends StatefulWidget {
  const StopsBrowserScreen({super.key});

  @override
  State<StopsBrowserScreen> createState() => _StopsBrowserScreenState();
}

class _IndexedStopGroup {
  const _IndexedStopGroup(this.group, this.foldedName);

  final StopGroup group;
  final String foldedName;
}

class _StopsBrowserScreenState extends State<StopsBrowserScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _operatorFilter = '';
  String _query = '';

  List<_IndexedStopGroup> _indexedAll = const [];
  List<StopGroup> _nearbyGroups = const [];
  List<StopGroup> _filteredCache = const [];
  List<_IndexedStopGroup>? _cachedSource;
  String? _cachedOperatorFilter;
  String? _cachedQuery;
  bool _loading = true;
  bool _loadingNearby = false;
  String? _error;
  String? _locationNotice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    final api = AppScope.of(context).api;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final groups = await api.fetchAllStopGroups(forceRefresh: forceRefresh);
      if (!mounted) return;
      final indexed = [
        for (final g in groups) _IndexedStopGroup(g, foldPolish(g.name)),
      ];
      setState(() {
        _indexedAll = indexed;
        _loading = false;
      });
      _loadNearby(silent: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadNearby({bool silent = false}) async {
    final api = AppScope.of(context).api;
    if (!silent) {
      setState(() {
        _loadingNearby = true;
        _locationNotice = null;
      });
    }
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _locationNotice = 'Włącz GPS, aby zobaczyć pobliskie przystanki.';
          _loadingNearby = false;
        });
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied && !silent) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _locationNotice = 'Nadaj uprawnienie lokalizacji, aby zobaczyć przystanki w pobliżu.';
          _loadingNearby = false;
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );

      final nearby = await api.fetchNearbyStopGroups(
        pos.latitude,
        pos.longitude,
        radiusMeters: 2500,
        limit: 15,
      );
      if (!mounted) return;
      setState(() {
        _nearbyGroups = nearby;
        _locationNotice = null;
        _loadingNearby = false;
      });
    } catch (_) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _locationNotice = 'Nie udało się ustalić pozycji GPS.';
          _loadingNearby = false;
        });
      }
    }
  }

  List<StopGroup> get _filteredAll {
    if (identical(_cachedSource, _indexedAll) &&
        _cachedOperatorFilter == _operatorFilter &&
        _cachedQuery == _query) {
      return _filteredCache;
    }
    final q = foldPolish(_query);
    final res = <StopGroup>[];
    for (final entry in _indexedAll) {
      final g = entry.group;
      if (_operatorFilter.isNotEmpty && !g.operators.contains(_operatorFilter)) {
        continue;
      }
      if (q.isEmpty || entry.foldedName.contains(q)) {
        res.add(g);
      }
    }
    _cachedSource = _indexedAll;
    _cachedOperatorFilter = _operatorFilter;
    _cachedQuery = _query;
    _filteredCache = res;
    return res;
  }

  List<StopGroup> get _filteredNearby {
    return _nearbyGroups.where((g) {
      if (_operatorFilter.isNotEmpty && !g.operators.contains(_operatorFilter)) {
        return false;
      }
      return true;
    }).toList();
  }

  void _openStopGroup(StopGroup g) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StopBaysScreen(groupId: g.groupId, initialName: g.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.oneUi;
    final favorites = AppScope.of(context).favorites;

    return OneUiScaffold(
      title: 'Przystanki',
      expandedHeight: 124,
      onRefresh: () => _loadData(forceRefresh: true),
      pinnedTopWidget: Column(
        children: [
          OneUiSearchBar(
            controller: _searchController,
            hintText: 'Szukaj przystanku (np. Marszałkowska, Szpital)...',
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _FilterChipPill(
                label: 'Wszystkie',
                selected: _operatorFilter == '',
                onTap: () => setState(() => _operatorFilter = ''),
              ),
              const SizedBox(width: 8),
              _FilterChipPill(
                label: 'MPK',
                selected: _operatorFilter == 'ztm',
                accent: p.ztmOrange,
                onTap: () => setState(() => _operatorFilter = 'ztm'),
              ),
              const SizedBox(width: 8),
              _FilterChipPill(
                label: 'PKS',
                selected: _operatorFilter == 'pks',
                accent: p.pksBlue,
                onTap: () => setState(() => _operatorFilter = 'pks'),
              ),
            ],
          ),
        ],
      ),
      slivers: [
        if (_loading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: OneUiStatusCard(
                icon: Icons.cloud_off_rounded,
                title: 'Błąd pobierania przystanków',
                message: _error,
                actionLabel: 'Spróbuj ponownie',
                onAction: () => _loadData(forceRefresh: true),
              ),
            ),
          )
        else
          ListenableBuilder(
            listenable: favorites,
            builder: (ctx, _) => SliverMainAxisGroup(
              slivers: _buildUnifiedListSlivers(ctx, favorites),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildUnifiedListSlivers(BuildContext context, FavoritesStore favorites) {
    final p = context.oneUi;
    final all = _filteredAll;
    final slivers = <Widget>[];

    if (_query.isEmpty) {
      if (favorites.items.isNotEmpty) {
        slivers.add(const SliverToBoxAdapter(child: OneUiSectionLabel('ULUBIONE')));
        slivers.add(
          SliverToBoxAdapter(
            child: SizedBox(
              height: 40,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: favorites.items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final f = favorites.items[i];
                  return ActionChip(
                    avatar: Icon(Icons.star_rounded, size: 16, color: p.warnAmber),
                    label: Text(
                      f.title,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.ink),
                    ),
                    backgroundColor: p.card,
                    side: BorderSide(color: p.divider),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => f.isSpecificBay
                              ? DeparturesScreen(
                                  groupId: f.groupId,
                                  title: f.title,
                                  stopIds: f.stopIds,
                                  operators: f.operators,
                                )
                              : StopBaysScreen(groupId: f.groupId, initialName: f.title),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );
      }

      final topNearby = _filteredNearby.take(5).toList();
      if (topNearby.isNotEmpty) {
        slivers.add(const SliverToBoxAdapter(child: OneUiSectionLabel('POBLISKIE (GPS)')));
        slivers.add(_buildStopGroupSliver(topNearby, favorites, showDistance: true));
      } else if (_nearbyGroups.isEmpty) {
        slivers.add(
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            sliver: SliverToBoxAdapter(
              child: OneUiCard(
                onTap: _loadingNearby ? null : () => _loadNearby(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                radius: 20,
                child: Row(
                  children: [
                    Icon(Icons.my_location_rounded, size: 18, color: p.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _locationNotice ?? 'Pokaż przystanki w pobliżu (GPS)',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: p.ink),
                      ),
                    ),
                    if (_loadingNearby)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(Icons.chevron_right_rounded, size: 18, color: p.inkSecondary),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      slivers.add(SliverToBoxAdapter(child: OneUiSectionLabel('ALFABETYCZNIE (${all.length})')));
    } else {
      slivers.add(SliverToBoxAdapter(child: OneUiSectionLabel('WYNIKI (${all.length})')));
    }

    if (all.isEmpty) {
      slivers.add(
        const SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: OneUiStatusCard(
              icon: Icons.search_off_rounded,
              title: 'Brak wyników',
              message: 'Spróbuj wpisać inną nazwę przystanku lub zmień filtr.',
            ),
          ),
        ),
      );
    } else {
      slivers.add(_buildStopGroupSliver(all, favorites, showDistance: false));
    }

    return slivers;
  }

  Widget _buildStopGroupSliver(
    List<StopGroup> groups,
    FavoritesStore favorites, {
    required bool showDistance,
  }) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.builder(
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final g = groups[index];
          final favKey = FavoritesStore.groupKey(g.groupId);
          return _StopGroupTile(
            group: g,
            isFirst: index == 0,
            isLast: index == groups.length - 1,
            showDistance: showDistance,
            isFavorite: favorites.isFavorite(favKey),
            onTap: () => _openStopGroup(g),
            onToggleFavorite: () => favorites.toggle(
              FavoriteStop(
                key: favKey,
                groupId: g.groupId,
                title: g.name,
                subtitle: '',
                operators: g.operators,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StopGroupTile extends StatelessWidget {
  const _StopGroupTile({
    required this.group,
    required this.isFirst,
    required this.isLast,
    required this.showDistance,
    required this.isFavorite,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final StopGroup group;
  final bool isFirst;
  final bool isLast;
  final bool showDistance;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final p = context.oneUi;
    final radius = BorderRadius.vertical(
      top: Radius.circular(isFirst ? 22 : 0),
      bottom: Radius.circular(isLast ? 22 : 0),
    );

    return Container(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: radius,
        border: Border(
          top: isFirst ? BorderSide(color: p.divider) : BorderSide.none,
          left: BorderSide(color: p.divider),
          right: BorderSide(color: p.divider),
          bottom: BorderSide(color: p.divider),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        group.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: p.ink,
                        ),
                      ),
                      if (showDistance && group.distanceMeters != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          formatDistanceMeters(group.distanceMeters!),
                          style: TextStyle(fontSize: 11.5, color: p.inkSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                for (final op in group.operators) ...[
                  OperatorTag(operatorId: op),
                  const SizedBox(width: 5),
                ],
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: Icon(
                    isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 21,
                    color: isFavorite ? p.warnAmber : p.inkSecondary,
                  ),
                  onPressed: onToggleFavorite,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterChipPill extends StatelessWidget {
  const _FilterChipPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final p = context.oneUi;
    final activeColor = accent ?? p.accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? activeColor : p.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? activeColor : p.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : p.inkSecondary,
          ),
        ),
      ),
    );
  }
}
