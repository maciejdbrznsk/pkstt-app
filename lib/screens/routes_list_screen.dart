import 'package:material_ui/material_ui.dart';
import '../app_scope.dart';
import '../models/transit_models.dart';
import '../theme/one_ui_theme.dart';
import '../utils/transit_format.dart';
import '../widgets/one_ui_widgets.dart';
import 'route_direction_stop_screen.dart';

/// Lists all MPK/ZTM, MKS, and PKS lines using one uniform One UI tile grid
/// showing line numbers only with subtle operator color accents instead of solid fills.
class RoutesListScreen extends StatefulWidget {
  const RoutesListScreen({super.key});

  @override
  State<RoutesListScreen> createState() => _RoutesListScreenState();
}

class _RoutesListScreenState extends State<RoutesListScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<RouteSummary> _routes = const [];
  String _operatorFilter = '';
  String _query = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await AppScope.of(context).api.fetchRoutes(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _routes = list;
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

  List<RouteSummary> get _filtered {
    final q = foldPolish(_query);
    return _routes.where((r) {
      if (_operatorFilter.isNotEmpty && r.operatorId != _operatorFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return foldPolish(r.shortName).contains(q) || foldPolish(r.longName).contains(q);
    }).toList();
  }

  void _openRoute(RouteSummary route) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RouteDirectionStopScreen(route: route),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.oneUi;
    final filtered = _filtered;
    final ztmRoutes = filtered.where((r) => r.operatorId == 'ztm').toList();
    final mksRoutes = filtered
        .where((r) => r.operatorId == 'pks' && operatorDisplayLabel('pks', r.shortName) == 'MKS')
        .toList();
    final pksRoutes = filtered
        .where((r) => r.operatorId == 'pks' && operatorDisplayLabel('pks', r.shortName) == 'PKS')
        .toList();

    return OneUiScaffold(
      title: 'Rozkład jazdy linii',
      expandedHeight: 118,
      onRefresh: () => _load(forceRefresh: true),
      pinnedTopWidget: Column(
        children: [
          OneUiSearchBar(
            controller: _searchController,
            hintText: 'Szukaj numeru linii (np. 18, 202, N1)...',
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 10),
          OneUiSegmentedPills<String>(
            selected: _operatorFilter,
            onSelected: (v) => setState(() => _operatorFilter = v),
            options: [
              ('', 'Wszystkie (${_routes.length})', null),
              ('ztm', 'MPK / ZTM', p.ztmOrange),
              ('pks', 'MKS / PKS', p.pksBlue),
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
                title: 'Błąd pobierania linii',
                message: _error,
                actionLabel: 'Spróbuj ponownie',
                onAction: () => _load(forceRefresh: true),
              ),
            ),
          )
        else if (filtered.isEmpty)
          const SliverPadding(
            padding: EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: OneUiStatusCard(
                icon: Icons.search_off_rounded,
                title: 'Brak pasujących linii',
                message: 'Zmień wyszukiwanie lub filtr przewoźnika.',
              ),
            ),
          )
        else ...[
          if (ztmRoutes.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: OneUiSectionLabel('MPK / ZTM RZESZÓW (${ztmRoutes.length})'),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: _UniformRoutesGridCard(routes: ztmRoutes, onTap: _openRoute),
              ),
            ),
          ],
          if (mksRoutes.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: OneUiSectionLabel('MKS RZESZÓW (${mksRoutes.length})'),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: _UniformRoutesGridCard(routes: mksRoutes, onTap: _openRoute),
              ),
            ),
          ],
          if (pksRoutes.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: OneUiSectionLabel('PKS RZESZÓW (${pksRoutes.length})'),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: _UniformRoutesGridCard(routes: pksRoutes, onTap: _openRoute),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _UniformRoutesGridCard extends StatelessWidget {
  const _UniformRoutesGridCard({required this.routes, required this.onTap});

  final List<RouteSummary> routes;
  final ValueChanged<RouteSummary> onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.oneUi;
    return OneUiCard(
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: routes.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.25,
        ),
        itemBuilder: (ctx, i) {
          final r = routes[i];
          final night = isNightLine(r.operatorId, r.shortName);
          final isZtm = r.operatorId == 'ztm';
          final markerColor = night
              ? p.ink
              : (isZtm ? p.ztmOrange : p.pksBlue);
          final tag = night
              ? 'NOC'
              : (isZtm ? 'MPK' : operatorDisplayLabel(r.operatorId, r.shortName));

          return Material(
            color: p.cardAlt,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onTap(r),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: p.divider, width: 0.9),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: night ? p.ztmOrange : markerColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          tag,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: markerColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      r.shortName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: p.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
