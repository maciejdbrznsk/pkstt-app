import 'package:material_ui/material_ui.dart';
import '../app_scope.dart';
import '../models/transit_models.dart';
import '../theme/one_ui_theme.dart';
import '../utils/transit_format.dart';
import '../widgets/one_ui_widgets.dart';
import 'route_timetable_board_screen.dart';

/// Step 2 & 3 of Line Timetable flow: pick direction, then pick ordered stop on route.
class RouteDirectionStopScreen extends StatefulWidget {
  const RouteDirectionStopScreen({super.key, required this.route});

  final RouteSummary route;

  @override
  State<RouteDirectionStopScreen> createState() => _RouteDirectionStopScreenState();
}

class _RouteDirectionStopScreenState extends State<RouteDirectionStopScreen> {
  final ScrollController _stopsScrollController = ScrollController();
  RouteTimetableResponse? _timetable;
  int? _directionId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _stopsScrollController.dispose();
    super.dispose();
  }

  Future<void> _load({int? directionId}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await AppScope.of(context).api.fetchRouteTimetable(
            widget.route.id,
            directionId: directionId ?? _directionId,
          );
      if (!mounted) return;
      setState(() {
        _timetable = resp;
        _directionId = resp.selectedDirectionId;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _stopsScrollController.hasClients) {
          _stopsScrollController.jumpTo(0);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.oneUi;
    final accent = lineBadgeColor(
      p,
      operatorId: widget.route.operatorId,
      shortName: widget.route.shortName,
    );

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: AppBar(
        backgroundColor: p.canvas,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: p.ink),
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: 'Wstecz',
          ),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Linia ${widget.route.shortName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: p.ink,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              '${operatorDisplayLabel(widget.route.operatorId, widget.route.shortName)} · wybierz kierunek i przystanek',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: p.inkSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Odśwież',
            icon: Icon(Icons.refresh_rounded, color: p.ink),
            onPressed: () => _load(directionId: _directionId),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: OneUiStatusCard(
                      icon: Icons.cloud_off_rounded,
                      title: 'Błąd pobierania trasy',
                      message: _error,
                      actionLabel: 'Spróbuj ponownie',
                      onAction: () => _load(directionId: _directionId),
                    ),
                  )
                : _timetable == null
                    ? const SizedBox.shrink()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OfflineStatusStrip(
                            onRetry: () => _load(directionId: _directionId),
                          ),
                          if (_timetable!.directions.isNotEmpty) ...[
                            const OneUiSectionLabel('1. WYBIERZ KIERUNEK'),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                children: [
                                  for (var i = 0; i < _timetable!.directions.length; i++) ...[
                                    _DirectionCard(
                                      dir: _timetable!.directions[i],
                                      selected: _timetable!.directions[i].directionId ==
                                          _timetable!.selectedDirectionId,
                                      accent: accent,
                                      onTap: () =>
                                          _load(directionId: _timetable!.directions[i].directionId),
                                    ),
                                    if (i < _timetable!.directions.length - 1)
                                      const SizedBox(height: 8),
                                  ],
                                ],
                              ),
                            ),
                          ],
                          OneUiSectionLabel(
                            '2. WYBIERZ PRZYSTANEK NA TRASIE (${_timetable!.stops.length})',
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                              child: OneUiCard(
                                padding: EdgeInsets.zero,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(26),
                                  child: RefreshIndicator(
                                    onRefresh: () => _load(directionId: _directionId),
                                    color: p.accent,
                                    child: Scrollbar(
                                      controller: _stopsScrollController,
                                      child: ListView.builder(
                                        controller: _stopsScrollController,
                                        physics: const BouncingScrollPhysics(
                                          parent: AlwaysScrollableScrollPhysics(),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        itemCount: _timetable!.stops.length,
                                        itemBuilder: (context, i) {
                                          final st = _timetable!.stops[i];
                                          return _OrderedRouteStopTile(
                                            stop: st,
                                            isFirst: i == 0,
                                            isLast: i == _timetable!.stops.length - 1,
                                            accent: accent,
                                            onTap: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) => RouteTimetableBoardScreen(
                                                    routeId: widget.route.id,
                                                    directionId: _timetable!.selectedDirectionId,
                                                    stopId: st.stopId,
                                                  ),
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }
}

class _DirectionCard extends StatelessWidget {
  const _DirectionCard({
    required this.dir,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final RouteDirection dir;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.oneUi;
    return OneUiCard(
      onTap: onTap,
      radius: 22,
      backgroundColor: selected ? accent.withValues(alpha: 0.12) : p.card,
      borderColor: selected ? accent : p.divider,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Icon(
            selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
            color: selected ? accent : p.inkSecondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dir.headsign.isNotEmpty ? 'Kierunek: ${dir.headsign}' : 'Kierunek ${dir.directionId + 1}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: selected ? accent : p.ink,
                  ),
                ),
                if (dir.variantHeadsigns.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Warianty: ${dir.variantHeadsigns.join(', ')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: p.inkSecondary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderedRouteStopTile extends StatelessWidget {
  const _OrderedRouteStopTile({
    required this.stop,
    required this.isFirst,
    required this.isLast,
    required this.accent,
    required this.onTap,
  });

  final TimetableRouteStop stop;
  final bool isFirst;
  final bool isLast;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.oneUi;
    return InkWell(
      onTap: stop.isTerminus ? null : onTap,
      child: IntrinsicHeight(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        width: 3,
                        color: isFirst ? Colors.transparent : accent.withValues(alpha: 0.45),
                      ),
                    ),
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: stop.isTerminus ? p.cardAlt : accent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: stop.isTerminus ? p.inkSecondary : p.card,
                          width: 2.5,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        width: 3,
                        color: isLast ? Colors.transparent : accent.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stop.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: stop.isTerminus ? p.inkSecondary : p.ink,
                              ),
                            ),
                            if (stop.isTerminus)
                              Text(
                                'Przystanek końcowy (tylko wysiadanie)',
                                style: TextStyle(fontSize: 11.5, color: p.inkSecondary),
                              ),
                          ],
                        ),
                      ),
                      if (stop.isOnDemand)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: p.warnAmber.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            'NŻ',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: p.warnAmber,
                            ),
                          ),
                        ),
                      if (!stop.isTerminus)
                        Icon(Icons.chevron_right_rounded, size: 20, color: p.inkSecondary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
