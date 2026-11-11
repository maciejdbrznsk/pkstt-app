import 'package:material_ui/material_ui.dart';
import '../app_scope.dart';
import '../models/transit_models.dart';
import '../services/favorites_store.dart';
import '../theme/one_ui_theme.dart';
import '../widgets/one_ui_widgets.dart';
import 'departures_screen.dart';
import 'live_map_screen.dart';

/// Displays platform/direction variants of a stop group (e.g. Marszałkowska 01, 02, 03)
/// with sample lines and destinations so users can pick the right bay quickly.
class StopBaysScreen extends StatefulWidget {
  const StopBaysScreen({
    super.key,
    required this.groupId,
    required this.initialName,
  });

  final String groupId;
  final String initialName;

  @override
  State<StopBaysScreen> createState() => _StopBaysScreenState();
}

class _StopBaysScreenState extends State<StopBaysScreen> {
  StopGroupDetail? _detail;
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
      final detail = await AppScope.of(context).api.fetchStopGroupDetail(widget.groupId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
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

  void _openAllBays() {
    final g = _detail?.group;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DeparturesScreen(
          groupId: widget.groupId,
          title: '${g?.name ?? widget.initialName} (wszystkie)',
          operators: g?.operators,
        ),
      ),
    );
  }

  void _openBay(StopBay bay) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DeparturesScreen(
          groupId: widget.groupId,
          title: bay.label,
          stopIds: bay.stopIds,
          bay: bay,
          operators: bay.operators,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.oneUi;
    final favorites = AppScope.of(context).favorites;
    final group = _detail?.group;
    final groupFavKey = FavoritesStore.groupKey(widget.groupId);

    return OneUiScaffold(
      title: group?.name ?? widget.initialName,
      expandedHeight: 126,
      onRefresh: _load,
      actions: [
        if (group != null)
          IconButton(
            tooltip: 'Pokaż na mapie',
            icon: Icon(Icons.map_outlined, color: p.ink),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LiveMapScreen(
                  focusLat: group.lat,
                  focusLon: group.lon,
                  focusTitle: group.name,
                ),
              ),
            ),
          ),
        ListenableBuilder(
          listenable: favorites,
          builder: (ctx, _) {
            final isFav = favorites.isFavorite(groupFavKey);
            return IconButton(
              tooltip: 'Dodaj przystanek do ulubionych',
              icon: Icon(
                isFav ? Icons.star_rounded : Icons.star_border_rounded,
                color: isFav ? p.warnAmber : p.ink,
              ),
              onPressed: group == null
                  ? null
                  : () => favorites.toggle(
                        FavoriteStop(
                          key: groupFavKey,
                          groupId: group.groupId,
                          title: group.name,
                          subtitle: '',
                          operators: group.operators,
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
                title: 'Błąd pobierania wariantów',
                message: _error,
                actionLabel: 'Spróbuj ponownie',
                onAction: _load,
              ),
            ),
          )
        else ...[
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.separated(
              itemCount: _detail!.bays.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final bay = _detail!.bays[index];
                return _BayVariantCard(
                  group: group!,
                  bay: bay,
                  onTap: () => _openBay(bay),
                );
              },
            ),
          ),
          if (_detail!.bays.length > 1)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              sliver: SliverToBoxAdapter(
                child: OneUiCard(
                  onTap: _openAllBays,
                  backgroundColor: p.accentSoft,
                  borderColor: p.accent.withValues(alpha: 0.35),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  child: Row(
                    children: [
                      Icon(Icons.layers_rounded, color: p.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Wszystkie słupki razem (${group!.name})',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: p.accent,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: p.accent),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _BayVariantCard extends StatelessWidget {
  const _BayVariantCard({
    required this.group,
    required this.bay,
    required this.onTap,
  });

  final StopGroup group;
  final StopBay bay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.oneUi;
    final favorites = AppScope.of(context).favorites;
    final bayFavKey = FavoritesStore.bayKey(group.groupId, bay.bayId);
    final summarySub = bay.sampleDirections.isNotEmpty
        ? bay.sampleDirections
            .take(2)
            .map((d) => '${d.routeShortName} → ${d.headsign}')
            .join(' · ')
        : '';

    return OneUiCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        bay.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          color: p.ink,
                        ),
                      ),
                    ),
                    if (bay.isOnDemand) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: p.warnAmber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'NŻ',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: p.warnAmber,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              for (final op in bay.operators) ...[
                OperatorTag(operatorId: op),
                const SizedBox(width: 5),
              ],
              ListenableBuilder(
                listenable: favorites,
                builder: (ctx, _) {
                  final isFav = favorites.isFavorite(bayFavKey);
                  return IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    icon: Icon(
                      isFav ? Icons.star_rounded : Icons.star_border_rounded,
                      color: isFav ? p.warnAmber : p.inkSecondary,
                    ),
                    tooltip: 'Przypnij do ulubionych',
                    onPressed: () => favorites.toggle(
                      FavoriteStop(
                        key: bayFavKey,
                        groupId: group.groupId,
                        title: bay.label,
                        subtitle: summarySub,
                        operators: bay.operators,
                        bayId: bay.platformCode.isNotEmpty ? bay.platformCode : bay.bayId,
                        stopIds: bay.stopIds,
                      ),
                    ),
                  );
                },
              ),
              Icon(Icons.chevron_right_rounded, color: p.inkSecondary),
            ],
          ),
          if (bay.sampleDirections.isNotEmpty) ...[
            const SizedBox(height: 10),
            Divider(height: 1, color: p.divider),
            const SizedBox(height: 8),
            for (final d in bay.sampleDirections.take(4)) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    LineBadge(
                      shortName: d.routeShortName,
                      operatorId: d.operatorId,
                      compact: true,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        d.headsign.isNotEmpty ? d.headsign : 'Kierunek wg rozkładu',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: p.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Brak odjazdów pasażerskich lub przystanek końcowy',
              style: TextStyle(fontSize: 12.5, color: p.inkSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
