import 'dart:async';
import 'package:material_ui/material_ui.dart';
import '../app_scope.dart';
import '../models/transit_models.dart';
import '../services/api_client.dart';
import '../services/map_tile_cache.dart';
import '../theme/one_ui_theme.dart';
import '../widgets/one_ui_widgets.dart';
import 'departures_screen.dart';
import 'live_map_screen.dart';
import 'routes_list_screen.dart';
import 'stop_bays_screen.dart';
import 'stops_browser_screen.dart';

/// Main One UI 9 home hub: compact action tiles (Stops, Lines, Map) and favorites below.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<RealtimeFeedStatus> _feeds = const [];
  int _alertCount = 0;
  bool _initialSyncTriggered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshMeta();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialSyncTriggered) {
      _initialSyncTriggered = true;
      _refreshMeta();
    }
  }

  Future<void> _refreshMeta() async {
    final scope = AppScope.of(context);
    try {
      final results = await Future.wait([
        scope.api.syncStaticVersion(force: true),
        scope.api.fetchAlerts().catchError((_) => const <ServiceAlert>[]),
      ]);
      if (!mounted) return;
      final sync = results[0] as StaticSyncResult;
      final alerts = results[1] as List<ServiceAlert>;
      setState(() {
        _feeds = sync.online ? (sync.meta?.realtimeFeeds ?? const []) : const [];
        _alertCount = alerts.length;
      });
      if (sync.updated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Zaktualizowano lokalny rozkład jazdy'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
      if (sync.online) {
        unawaited(_warmFavoriteCaches(scope));
      }
    } catch (_) {
      if (!mounted) return;
    }
  }

  Future<void> _warmFavoriteCaches(AppScope scope) async {
    final groupIds = <String>{
      for (final fav in scope.favorites.items) fav.groupId,
    }.take(5);
    for (final gid in groupIds) {
      if (!mounted) return;
      try {
        await scope.api.fetchStopGroupDetail(gid);
      } catch (_) {}
    }
  }

  int get _totalVehicles => _feeds.fold<int>(0, (acc, f) => acc + f.vehicleCount);

  void _openThemeSettings(BuildContext context) {
    final scope = AppScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _ThemeSettingsSheet(
        controller: scope.themeController,
        api: scope.api,
        onSchedulesSynced: _refreshMeta,
      ),
    );
  }

  Future<void> _openAlertsSheet(BuildContext context) async {
    final api = AppScope.of(context).api;
    final p = context.oneUi;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => FutureBuilder<List<ServiceAlert>>(
        future: api.fetchAlerts(),
        builder: (ctx, snap) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Komunikaty przewoźników',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: p.ink),
                  ),
                  const SizedBox(height: 12),
                  if (snap.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (snap.hasError)
                    OneUiStatusCard(
                      icon: Icons.cloud_off_rounded,
                      title: 'Nie udało się pobrać komunikatów',
                      message: snap.error.toString(),
                    )
                  else if ((snap.data ?? const []).isEmpty)
                    const OneUiStatusCard(
                      icon: Icons.check_circle_outline_rounded,
                      title: 'Brak aktywnych utrudnień',
                      message: 'Wszystkie linie MPK i PKS kursują bez zgłoszonych alertów.',
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 380),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: snap.data!.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final al = snap.data![i];
                          return OneUiCard(
                            backgroundColor: p.cardAlt,
                            radius: 20,
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                OperatorTag(operatorId: al.operatorId),
                                const SizedBox(height: 6),
                                Text(
                                  al.header,
                                  style: TextStyle(fontWeight: FontWeight.w700, color: p.ink),
                                ),
                                if (al.description.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    al.description,
                                    style: TextStyle(fontSize: 13, color: p.inkSecondary),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openFavorite(BuildContext context, FavoriteStop fav) {
    if (fav.isSpecificBay) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DeparturesScreen(
            groupId: fav.groupId,
            title: fav.title,
            stopIds: fav.stopIds,
            operators: fav.operators,
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StopBaysScreen(
          groupId: fav.groupId,
          initialName: fav.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.oneUi;
    final favorites = AppScope.of(context).favorites;

    return OneUiScaffold(
      title: 'PKSTT Rzeszów',
      showBackButton: false,
      expandedHeight: 136,
      onRefresh: _refreshMeta,
      actions: [
        IconButton(
          onPressed: () => _openAlertsSheet(context),
          tooltip: 'Komunikaty',
          icon: Badge(
            isLabelVisible: _alertCount > 0,
            label: Text('$_alertCount'),
            backgroundColor: p.dangerRed,
            child: Icon(Icons.notifications_none_rounded, color: p.ink),
          ),
        ),
        IconButton(
          onPressed: () => _openThemeSettings(context),
          tooltip: 'Ustawienia',
          icon: Icon(Icons.settings_outlined, color: p.ink),
        ),
      ],
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _HomeHubTile(
                icon: Icons.departure_board_rounded,
                iconBg: p.accentSoft,
                iconColor: p.accent,
                title: 'Rozkład jazdy przystanku',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StopsBrowserScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _HomeHubTile(
                icon: Icons.route_rounded,
                iconBg: p.ztmSoft,
                iconColor: p.ztmOrange,
                title: 'Rozkład jazdy linii',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RoutesListScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _HomeHubTile(
                icon: Icons.map_rounded,
                iconBg: p.liveGreenSoft,
                iconColor: p.liveGreen,
                title: 'Mapa na żywo',
                trailingPill: _totalVehicles > 0 ? '$_totalVehicles na żywo' : null,
                trailingColor: p.liveGreen,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LiveMapScreen()),
                ),
              ),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: OneUiSectionLabel(
            'ULUBIONE PRZYSTANKI',
            trailing: TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StopsBrowserScreen()),
              ),
              icon: Icon(Icons.add_rounded, size: 18, color: p.accent),
              label: Text(
                'Dodaj',
                style: TextStyle(fontWeight: FontWeight.w700, color: p.accent),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: ListenableBuilder(
              listenable: favorites,
              builder: (context, _) {
                final items = favorites.items;
                if (items.isEmpty) {
                  return OneUiStatusCard(
                    icon: Icons.star_border_rounded,
                    title: 'Brak ulubionych przystanków',
                    message:
                        'Otwórz „Rozkład jazdy przystanku” i przypnij przystanek lub konkretny słupek gwiazdką.',
                    actionLabel: 'Przeglądaj przystanki',
                    onAction: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const StopsBrowserScreen()),
                    ),
                  );
                }

                return OneUiCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        _FavoriteRow(
                          item: items[i],
                          onTap: () => _openFavorite(context, items[i]),
                          onRemove: () => favorites.removeByKey(items[i].key),
                        ),
                        if (i < items.length - 1)
                          Divider(
                            height: 1,
                            indent: 18,
                            endIndent: 18,
                            color: p.divider,
                          ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeHubTile extends StatelessWidget {
  const _HomeHubTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    this.trailingPill,
    this.trailingColor,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String? trailingPill;
  final Color? trailingColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.oneUi;
    return OneUiCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, size: 28, color: iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 19.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: p.ink,
              ),
            ),
          ),
          if (trailingPill != null && trailingColor != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: trailingColor!.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                trailingPill!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: trailingColor,
                ),
              ),
            ),
          ],
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, color: p.inkSecondary),
        ],
      ),
    );
  }
}

class _FavoriteRow extends StatelessWidget {
  const _FavoriteRow({
    required this.item,
    required this.onTap,
    required this.onRemove,
  });

  final FavoriteStop item;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final p = context.oneUi;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: p.ink,
                    ),
                  ),
                  if (item.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: p.inkSecondary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            for (final op in item.operators) ...[
              OperatorTag(operatorId: op),
              const SizedBox(width: 5),
            ],
            IconButton(
              icon: Icon(Icons.star_rounded, color: p.warnAmber, size: 22),
              tooltip: 'Usuń z ulubionych',
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

class _BusDetailSwitchRow extends StatelessWidget {
  const _BusDetailSwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.oneUi;
    return SwitchListTile.adaptive(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.only(left: 8),
      activeTrackColor: p.accent,
      value: value,
      onChanged: onChanged,
      title: Text(
        label,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: p.ink),
      ),
    );
  }
}

class _ThemeSettingsSheet extends StatefulWidget {
  const _ThemeSettingsSheet({
    required this.controller,
    required this.api,
    required this.onSchedulesSynced,
  });

  final ThemeController controller;
  final PksttApiClient api;
  final Future<void> Function() onSchedulesSynced;

  @override
  State<_ThemeSettingsSheet> createState() => _ThemeSettingsSheetState();
}

class _ThemeSettingsSheetState extends State<_ThemeSettingsSheet> {
  int _scheduleBytes = 0;
  int _tileBytes = 0;
  bool _loadingSizes = true;
  bool _checkingUpdate = false;
  bool _clearingCache = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadCacheSizes();
  }

  Future<void> _loadCacheSizes() async {
    final results = await Future.wait([
      widget.api.getScheduleCacheBytes(),
      MapTileCache.totalBytes(),
    ]);
    if (!mounted) return;
    setState(() {
      _scheduleBytes = results[0];
      _tileBytes = results[1];
      _loadingSizes = false;
    });
  }

  Future<void> _checkScheduleUpdate() async {
    if (_checkingUpdate || _clearingCache) return;
    setState(() {
      _checkingUpdate = true;
      _statusMessage = null;
    });
    final res = await widget.api.syncStaticVersion(force: true);
    if (res.updated) {
      await Future.wait([
        widget.api.fetchAllStopGroups().catchError((_) => const <StopGroup>[]),
        widget.api.fetchRoutes().catchError((_) => const <RouteSummary>[]),
      ]);
      await widget.onSchedulesSynced();
    }
    await _loadCacheSizes();
    if (!mounted) return;
    setState(() {
      _checkingUpdate = false;
      _statusMessage = !res.online
          ? 'Brak połączenia z serwerem — używane są zapisane rozkłady.'
          : res.updated
              ? 'Pobrano zaktualizowany rozkład jazdy.'
              : 'Lokalny rozkład jazdy jest już aktualny.';
    });
  }

  Future<void> _clearAllCaches() async {
    if (_checkingUpdate || _clearingCache) return;
    setState(() {
      _clearingCache = true;
      _statusMessage = null;
    });
    await Future.wait([
      widget.api.clearScheduleCache(),
      MapTileCache.clearCache(),
    ]);
    await _loadCacheSizes();
    if (!mounted) return;
    setState(() {
      _clearingCache = false;
      _statusMessage = 'Wyczyszczono pamięć lokalną rozkładów i mapy.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return ListenableBuilder(
      listenable: controller,
      builder: (ctx, _) {
        final p = ctx.oneUi;
        final selectedAccent = kOneUiAccentPresets.firstWhere(
          (preset) => preset.color.toARGB32() == controller.customAccent.toARGB32(),
          orElse: () => kOneUiAccentPresets.first,
        );

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ustawienia',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 14),
                OneUiSegmentedPills<ThemeMode>(
                  selected: controller.themeMode,
                  onSelected: controller.setThemeMode,
                  options: const [
                    (ThemeMode.system, 'System', null),
                    (ThemeMode.light, 'Jasny', null),
                    (ThemeMode.dark, 'AMOLED', null),
                  ],
                ),
                const SizedBox(height: 14),
                OneUiCard(
                  backgroundColor: p.cardAlt,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  radius: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile.adaptive(
                        value: controller.useDynamicColor,
                        onChanged: controller.setUseDynamicColor,
                        contentPadding: EdgeInsets.zero,
                        activeTrackColor: p.accent,
                        title: Text(
                          'Kolorystyka dynamiczna',
                          style: TextStyle(fontWeight: FontWeight.w600, color: p.ink),
                        ),
                        subtitle: Text(
                          'Dopasuj akcent do tapety Androida 13+',
                          style: TextStyle(fontSize: 12.5, color: p.inkSecondary),
                        ),
                      ),
                      if (!controller.useDynamicColor) ...[
                        Divider(height: 12, color: p.divider),
                        Row(
                          children: [
                            Text(
                              'Kolor wiodący',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: p.ink,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              selectedAccent.name,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: p.accent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final preset in kOneUiAccentPresets)
                              _AccentColorSwatch(
                                color: preset.color,
                                label: preset.name,
                                selected: preset.color.toARGB32() ==
                                    controller.customAccent.toARGB32(),
                                onTap: () => controller.setCustomAccent(preset.color),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OneUiCard(
                  backgroundColor: p.cardAlt,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  radius: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile.adaptive(
                        value: controller.showAdvancedBusInfo,
                        onChanged: controller.setShowAdvancedBusInfo,
                        contentPadding: EdgeInsets.zero,
                        activeTrackColor: p.accent,
                        title: Text(
                          'Pokaż zaawansowane informacje o autobusie',
                          style: TextStyle(fontWeight: FontWeight.w600, color: p.ink),
                        ),
                        subtitle: Text(
                          'Domyślnie ukryte dla czystego widoku trasy',
                          style: TextStyle(fontSize: 12.5, color: p.inkSecondary),
                        ),
                      ),
                      if (controller.showAdvancedBusInfo) ...[
                        Divider(height: 10, color: p.divider),
                        _BusDetailSwitchRow(
                          label: 'Numer pojazdu',
                          value: controller.showBusNumber,
                          onChanged: controller.setShowBusNumber,
                        ),
                        _BusDetailSwitchRow(
                          label: 'Rejestracja',
                          value: controller.showBusPlate,
                          onChanged: controller.setShowBusPlate,
                        ),
                        _BusDetailSwitchRow(
                          label: 'Brygada',
                          value: controller.showBusBrigade,
                          onChanged: controller.setShowBusBrigade,
                        ),
                        _BusDetailSwitchRow(
                          label: 'Niskopodłogowy',
                          value: controller.showBusLowFloor,
                          onChanged: controller.setShowBusLowFloor,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 2),
                          child: Text(
                            'Model pojazdu nie jest udostępniany w danych ZTM / PKS.',
                            style: TextStyle(fontSize: 11.5, color: p.inkSecondary),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _OfflineSettingsCard(
                  api: widget.api,
                  scheduleBytes: _scheduleBytes,
                  tileBytes: _tileBytes,
                  loadingSizes: _loadingSizes,
                  checkingUpdate: _checkingUpdate,
                  clearingCache: _clearingCache,
                  statusMessage: _statusMessage,
                  onCheckUpdate: _checkScheduleUpdate,
                  onClearCache: _clearAllCaches,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AccentColorSwatch extends StatelessWidget {
  const _AccentColorSwatch({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.oneUi;
    final checkColor = ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;

    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 36,
          height: 36,
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? p.ink : Colors.transparent,
              width: 2,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: selected
                ? Icon(Icons.check_rounded, size: 18, color: checkColor)
                : null,
          ),
        ),
      ),
    );
  }
}

class _OfflineSettingsCard extends StatelessWidget {
  const _OfflineSettingsCard({
    required this.api,
    required this.scheduleBytes,
    required this.tileBytes,
    required this.loadingSizes,
    required this.checkingUpdate,
    required this.clearingCache,
    required this.statusMessage,
    required this.onCheckUpdate,
    required this.onClearCache,
  });

  final PksttApiClient api;
  final int scheduleBytes;
  final int tileBytes;
  final bool loadingSizes;
  final bool checkingUpdate;
  final bool clearingCache;
  final String? statusMessage;
  final VoidCallback onCheckUpdate;
  final VoidCallback onClearCache;

  @override
  Widget build(BuildContext context) {
    final p = context.oneUi;

    return OneUiCard(
      backgroundColor: p.cardAlt,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Aktualizacje i pamięć offline',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: p.ink),
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: api.isOffline,
                builder: (context, offline, _) {
                  final badgeColor = offline ? p.warnAmber : p.liveGreen;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      offline ? 'Offline' : 'Online',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: badgeColor,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          ValueListenableBuilder<List<StaticFeedStatus>>(
            valueListenable: api.staticFeeds,
            builder: (context, feeds, _) {
              if (feeds.isEmpty) {
                return Text(
                  'Wersja rozkładu zostanie sprawdzona przy najbliższym połączeniu.',
                  style: TextStyle(fontSize: 12.5, color: p.inkSecondary),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final f in feeds)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        _formatFeedLine(f),
                        style: TextStyle(fontSize: 12.5, color: p.inkSecondary),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          Text(
            loadingSizes
                ? 'Obliczanie rozmiaru pamięci…'
                : 'Rozkłady: ${_formatCacheBytes(scheduleBytes)} · Kafelki mapy: ${_formatCacheBytes(tileBytes)}',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: p.ink),
          ),
          if (statusMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              statusMessage!,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: p.accent),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: checkingUpdate || clearingCache ? null : onCheckUpdate,
              icon: checkingUpdate
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: p.accent),
                    )
                  : const Icon(Icons.sync_rounded, size: 18),
              label: const Text(
                'Sprawdź aktualizację rozkładu',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: p.accent,
                side: BorderSide(color: p.accent.withValues(alpha: 0.35)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: checkingUpdate || clearingCache ? null : onClearCache,
              icon: clearingCache
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: p.dangerRed),
                    )
                  : Icon(Icons.delete_outline_rounded, size: 18, color: p.dangerRed),
              label: Text(
                'Wyczyść pamięć mapy i rozkładów',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: p.dangerRed,
                ),
              ),
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFeedLine(StaticFeedStatus feed) {
    final name = feed.feed.toUpperCase();
    final ver = feed.feedVersion.isNotEmpty ? 'wersja ${feed.feedVersion}' : 'brak wersji';
    final range = (feed.startDate != null &&
            feed.endDate != null &&
            feed.startDate!.isNotEmpty &&
            feed.endDate!.isNotEmpty)
        ? ' (${feed.startDate}–${feed.endDate})'
        : '';
    return '$name: $ver$range';
  }
}

String _formatCacheBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024.0;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024.0;
  return '${mb.toStringAsFixed(1)} MB';
}
