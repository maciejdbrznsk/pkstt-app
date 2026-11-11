import 'package:material_ui/material_ui.dart';
import '../app_scope.dart';
import '../models/transit_models.dart';
import '../theme/one_ui_theme.dart';
import '../utils/transit_format.dart';
import '../widgets/one_ui_widgets.dart';
import 'departures_screen.dart';
import 'trip_tracker_screen.dart';

/// Polish-style "Tabliczka przystankowa" showing departures grouped by service day type and hour,
/// with superscript route variant markers and a structured legend below.
class RouteTimetableBoardScreen extends StatefulWidget {
  const RouteTimetableBoardScreen({
    super.key,
    required this.routeId,
    required this.directionId,
    required this.stopId,
  });

  final String routeId;
  final int directionId;
  final String stopId;

  @override
  State<RouteTimetableBoardScreen> createState() => _RouteTimetableBoardScreenState();
}

class _RouteTimetableBoardScreenState extends State<RouteTimetableBoardScreen> {
  RouteTimetableResponse? _data;
  int _selectedDayIndex = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await AppScope.of(context).api.fetchRouteTimetable(
            widget.routeId,
            directionId: widget.directionId,
            stopId: widget.stopId,
          );
      if (!mounted) return;
      final activeIdx = resp.dayTypes.indexWhere((d) => d.activeToday);
      setState(() {
        _data = resp;
        _selectedDayIndex = activeIdx >= 0 ? activeIdx : 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String? _findNextEntryTripId(TimetableDay day) {
    if (!day.activeToday) return null;
    final now = DateTime.now();
    final nowMins = now.hour * 60 + now.minute;
    for (final hr in day.hours) {
      for (final dep in hr.departures) {
        final depMins = dep.hour * 60 + dep.minute;
        if (depMins >= nowMins) {
          return dep.tripId;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.oneUi;
    final data = _data;
    final stopName = data?.selectedStop?.name ?? 'Tabliczka przystankowa';
    final lineName = data?.route.shortName ?? '';

    return OneUiScaffold(
      title: stopName,
      subtitle: data != null ? 'Linia $lineName · rozkład przystankowy' : 'Ładowanie tabliczki...',
      expandedHeight: 136,
      onRefresh: _load,
      actions: [
        if (data?.selectedStop != null && data!.selectedStop!.groupId.isNotEmpty)
          IconButton(
            tooltip: 'Odjazdy na żywo ze słupka',
            icon: Icon(Icons.sensors_rounded, color: p.ink),
            onPressed: () {
              final st = data.selectedStop!;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DeparturesScreen(
                    groupId: st.groupId,
                    title: st.name,
                    stopIds: [st.stopId],
                  ),
                ),
              );
            },
          ),
      ],
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
                title: 'Błąd pobierania tabliczki',
                message: _error,
                actionLabel: 'Spróbuj ponownie',
                onAction: _load,
              ),
            ),
          )
        else if (data != null)
          ..._buildTimetableSlivers(context, data),
      ],
    );
  }

  List<Widget> _buildTimetableSlivers(BuildContext context, RouteTimetableResponse data) {
    final p = context.oneUi;
    final route = data.route;
    final accent = lineBadgeColor(p, operatorId: route.operatorId, shortName: route.shortName);
    final dirObj = data.directions
        .where((d) => d.directionId == data.selectedDirectionId)
        .firstOrNull;

    final safeIdx = data.dayTypes.isEmpty
        ? 0
        : _selectedDayIndex.clamp(0, data.dayTypes.length - 1);
    final activeDay = data.dayTypes.isNotEmpty ? data.dayTypes[safeIdx] : null;
    final nextTripId = activeDay != null ? _findNextEntryTripId(activeDay) : null;

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        sliver: SliverToBoxAdapter(
          child: OneUiCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                LineBadge(shortName: route.shortName, operatorId: route.operatorId),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          OperatorTag(
                            operatorId: route.operatorId,
                            routeShortName: route.shortName,
                          ),
                          if (data.selectedStop?.isOnDemand == true)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: p.warnAmber.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'PRZYSTANEK NŻ',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: p.warnAmber,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        dirObj != null && dirObj.headsign.isNotEmpty
                            ? 'Kierunek: ${dirObj.headsign}'
                            : 'Kierunek ${data.selectedDirectionId + 1}',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: p.ink),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      if (data.dayTypes.isEmpty)
        const SliverPadding(
          padding: EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: OneUiStatusCard(
              icon: Icons.event_busy_rounded,
              title: 'Brak odjazdów z tego przystanku',
              message: 'Ten przystanek może pełnić rolę wyłącznie przystanku końcowego.',
            ),
          ),
        )
      else ...[
        SliverToBoxAdapter(
          child: SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: data.dayTypes.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final day = data.dayTypes[i];
                final isSel = i == safeIdx;
                return ChoiceChip(
                  selected: isSel,
                  onSelected: (_) => setState(() => _selectedDayIndex = i),
                  showCheckmark: false,
                  selectedColor: accent,
                  backgroundColor: p.card,
                  side: BorderSide(color: isSel ? accent : p.divider),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (day.activeToday) ...[
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: isSel ? Colors.white : p.liveGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        day.activeToday ? '${day.shortLabel} · DZIŚ' : day.shortLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isSel ? Colors.white : p.ink,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: OneUiSectionLabel(activeDay!.label.toUpperCase()),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: OneUiCard(
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: Column(
                  children: [
                    // Header bar of tabliczka
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      color: accent.withValues(alpha: 0.12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 48,
                            child: Text(
                              'GODZ.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 22),
                          Expanded(
                            child: Text(
                              'MINUTY ODJAZDÓW (kliknij, aby śledzić)',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (var i = 0; i < activeDay.hours.length; i++)
                      _TimetableHourRow(
                        row: activeDay.hours[i],
                        accent: accent,
                        isAlternate: i.isOdd,
                        highlightTripId: nextTripId,
                        onTapEntry: (entry) => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TripTrackerScreen(
                              tripId: entry.tripId,
                              highlightStopId: data.selectedStop?.stopId,
                              initialLine: route.shortName,
                              initialHeadsign: entry.headsign,
                              initialOperator: route.operatorId,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: OneUiSectionLabel('LEGENDA I OZNACZENIA')),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: OneUiCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in data.legend) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              item.code,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item.description,
                              style: TextStyle(fontSize: 13.5, color: p.ink),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (data.legend.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Wszystkie kursy w tym kierunku realizowane są na głównej trasie.',
                        style: TextStyle(fontSize: 13, color: p.inkSecondary),
                      ),
                    ),
                  Divider(height: 18, color: p.divider),
                  Text(
                    '• Zielona kropka przy zakładce oznacza rozkład obowiązujący dzisiaj.',
                    style: TextStyle(fontSize: 12.5, color: p.inkSecondary),
                  ),
                  if (data.selectedStop?.isOnDemand == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      '• NŻ — przystanek na żądanie (zasygnalizuj chęć wejścia lub wyjścia).',
                      style: TextStyle(fontSize: 12.5, color: p.inkSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    ];
  }
}

class _TimetableHourRow extends StatelessWidget {
  const _TimetableHourRow({
    required this.row,
    required this.accent,
    required this.isAlternate,
    required this.highlightTripId,
    required this.onTapEntry,
  });

  final TimetableHourRow row;
  final Color accent;
  final bool isAlternate;
  final String? highlightTripId;
  final ValueChanged<TimetableEntry> onTapEntry;

  @override
  Widget build(BuildContext context) {
    final p = context.oneUi;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rowBg = isAlternate
        ? (isDark ? const Color(0xFF21222A) : const Color(0xFFEEF0F5))
        : p.card;
    final hourLabel = row.displayHour.toString().padLeft(2, '0');
    final hasNextInHour = row.departures.any((d) => d.tripId == highlightTripId);

    return ColoredBox(
      color: rowBg,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              child: Text(
                hourLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                  color: hasNextInHour ? accent : p.ink,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 2.5,
              height: 24,
              decoration: BoxDecoration(
                color: hasNextInHour ? accent : p.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                spacing: 10,
                runSpacing: 6,
                children: row.departures.map((dep) {
                  final isNext = dep.tripId == highlightTripId;
                  final minStr = dep.minute.toString().padLeft(2, '0');
                  return InkWell(
                    onTap: () => onTapEntry(dep),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: minStr,
                              style: TextStyle(
                                fontSize: isNext ? 17.5 : 16.5,
                                fontWeight: isNext ? FontWeight.w900 : FontWeight.w600,
                                color: isNext ? accent : p.ink,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            if (dep.variantCode.isNotEmpty)
                              TextSpan(
                                text: dep.variantCode,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: accent,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
