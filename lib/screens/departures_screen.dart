import 'dart:async';
import 'package:material_ui/material_ui.dart';
import '../app_scope.dart';
import '../models/transit_models.dart';
import '../services/favorites_store.dart';
import '../theme/one_ui_theme.dart';
import '../utils/transit_format.dart';
import '../widgets/one_ui_widgets.dart';
import 'trip_tracker_screen.dart';

/// Live + 24h scheduled departure board for a stop group or specific platform bay.
class DeparturesScreen extends StatefulWidget {
  const DeparturesScreen({
    super.key,
    required this.groupId,
    required this.title,
    this.stopIds,
    this.bay,
    this.operators,
  });

  final String groupId;
  final String title;
  final List<String>? stopIds;
  final StopBay? bay;
  final List<String>? operators;

  @override
  State<DeparturesScreen> createState() => _DeparturesScreenState();
}

class _DeparturesScreenState extends State<DeparturesScreen> {
  List<DepartureItem> _departures = const [];
  String _operatorFilter = '';
  bool _loading = true;
  bool _fromCache = false;
  String? _error;
  DateTime _now = DateTime.now();
  Timer? _refreshTimer;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _load(silent: true));
      _clockTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final api = AppScope.of(context).api;
      final list = await api.fetchStopGroupDepartures(
        widget.groupId,
        stopIds: widget.stopIds,
        operatorFilter: _operatorFilter,
        limit: 50,
        windowMinutes: 1440,
      );
      if (!mounted) return;
      setState(() {
        _departures = list;
        _fromCache = api.lastDeparturesFromCache;
        _error = null;
        _now = DateTime.now();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  bool get _shouldShowOperatorFilter {
    if (_operatorFilter.isNotEmpty) return true;
    final known = widget.operators;
    if (known != null) {
      return known.length > 1;
    }
    final opsInData = _departures.map((d) => d.operatorId).toSet();
    return opsInData.length > 1;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.oneUi;
    final favorites = AppScope.of(context).favorites;
    final bay = widget.bay;
    final favKey = bay != null
        ? FavoritesStore.bayKey(widget.groupId, bay.bayId)
        : FavoritesStore.groupKey(widget.groupId);
    final opsForFav = widget.operators ??
        bay?.operators ??
        _departures.map((d) => d.operatorId).toSet().toList();

    return OneUiScaffold(
      title: widget.title,
      expandedHeight: 124,
      onRefresh: () => _load(),
      actions: [
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: p.ink),
          tooltip: 'Odśwież teraz',
          onPressed: _load,
        ),
        ListenableBuilder(
          listenable: favorites,
          builder: (ctx, _) {
            final isFav = favorites.isFavorite(favKey);
            return IconButton(
              icon: Icon(
                isFav ? Icons.star_rounded : Icons.star_border_rounded,
                color: isFav ? p.warnAmber : p.ink,
              ),
              tooltip: 'Ulubiony przystanek',
              onPressed: () => favorites.toggle(
                FavoriteStop(
                  key: favKey,
                  groupId: widget.groupId,
                  title: widget.title,
                  subtitle: '',
                  operators: opsForFav,
                  bayId: bay?.platformCode,
                  stopIds: widget.stopIds ?? const [],
                ),
              ),
            );
          },
        ),
      ],
      pinnedTopWidget: _shouldShowOperatorFilter
          ? OneUiSegmentedPills<String>(
              selected: _operatorFilter,
              onSelected: (v) {
                setState(() => _operatorFilter = v);
                _load();
              },
              options: [
                ('', 'Wszystkie', null),
                ('ztm', 'MPK', p.ztmOrange),
                ('pks', 'PKS / MKS', p.pksBlue),
              ],
            )
          : null,
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
                title: 'Błąd pobierania odjazdów',
                message: _error,
                actionLabel: 'Spróbuj ponownie',
                onAction: _load,
              ),
            ),
          )
        else if (_departures.isEmpty)
          const SliverPadding(
            padding: EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: OneUiStatusCard(
                icon: Icons.schedule_rounded,
                title: 'Brak nadchodzących odjazdów',
                message: 'W ciągu najbliższych 24 godzin nie zaplanowano kursów z tego miejsca.',
              ),
            ),
          )
        else ...[
          if (_fromCache)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              sliver: SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: p.cardAlt,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: p.divider),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 16, color: p.inkSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Dane offline · zapisany plan odjazdów (24h)',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: p.inkSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.separated(
              itemCount: _departures.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final d = _departures[index];
                return _DepartureCard(
                  dep: d,
                  now: _now,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TripTrackerScreen(
                        tripId: d.tripId,
                        serviceDate: d.serviceDate,
                        highlightStopId: d.stopId,
                        initialLine: d.routeShortName,
                        initialHeadsign: d.headsign,
                        initialOperator: d.operatorId,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _DepartureCard extends StatelessWidget {
  const _DepartureCard({
    required this.dep,
    required this.now,
    required this.onTap,
  });

  final DepartureItem dep;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.oneUi;
    final countdown = formatCountdown(dep.estimatedTime, now);
    final estClock = formatClock(dep.estimatedTime);
    final schedClock = formatClock(dep.scheduledTime);
    final hasDelayDiff = dep.isRealtime && estClock != schedClock;
    final tomorrow = isDifferentCalendarDay(dep.estimatedTime, now);

    return OneUiCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      radius: 24,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 64,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                LineBadge(shortName: dep.routeShortName, operatorId: dep.operatorId),
                const SizedBox(height: 5),
                OperatorTag(
                  operatorId: dep.operatorId,
                  routeShortName: dep.routeShortName,
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dep.headsign.isNotEmpty ? dep.headsign : 'Kurs wg rozkładu',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    LiveLocationPill(
                      hasLiveLocation: dep.hasLiveLocation,
                      isRealtime: dep.isRealtime,
                    ),
                    DelayPill(
                      delaySeconds: dep.delaySeconds,
                      isRealtime: dep.isRealtime,
                    ),
                    if (dep.wheelchairAccessible)
                      Icon(Icons.accessible_rounded, size: 14, color: p.inkSecondary),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                countdown,
                style: TextStyle(
                  fontSize: 17.5,
                  fontWeight: FontWeight.w800,
                  color: dep.hasLiveLocation
                      ? p.liveGreen
                      : (dep.isRealtime ? p.accent : p.ink),
                ),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasDelayDiff) ...[
                    Text(
                      schedClock,
                      style: TextStyle(
                        fontSize: 12,
                        color: p.inkSecondary,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    tomorrow ? 'Jutro · $estClock' : estClock,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: p.inkSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
