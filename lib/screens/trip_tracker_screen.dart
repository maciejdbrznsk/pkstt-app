import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../app_scope.dart';
import '../models/transit_models.dart';
import '../services/map_tile_cache.dart';
import '../theme/one_ui_theme.dart';
import '../utils/transit_format.dart';
import '../widgets/one_ui_widgets.dart';
import 'route_timetable_board_screen.dart';

/// mobileMPK-style live trip view with dual vertical tracks:
/// 1) Scheduled theoretical bus position (Planowo)
/// 2) Real-time / GPS bus position (Rzeczywista) + interactive OSM route map.
class TripTrackerScreen extends StatefulWidget {
  const TripTrackerScreen({
    super.key,
    required this.tripId,
    this.serviceDate,
    this.highlightStopId,
    this.initialLine,
    this.initialHeadsign,
    this.initialOperator,
  });

  final String tripId;
  final String? serviceDate;
  final String? highlightStopId;
  final String? initialLine;
  final String? initialHeadsign;
  final String? initialOperator;

  @override
  State<TripTrackerScreen> createState() => _TripTrackerScreenState();
}

class _TripTrackerScreenState extends State<TripTrackerScreen> {
  static const double _rowHeight = 78.0;
  static const double _busZoomLevel = 15.6;

  final MapController _mapController = MapController();
  final ScrollController _stopsScrollController = ScrollController();
  TripResponse? _data;
  bool _loading = true;
  bool _showMap = false;
  String? _error;
  DateTime _now = DateTime.now();
  Timer? _refreshTimer;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) => _load(silent: true));
      _clockTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _clockTimer?.cancel();
    _stopsScrollController.dispose();
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
      final resp = await AppScope.of(context).api.fetchTrip(
            widget.tripId,
            serviceDate: widget.serviceDate,
            includeShape: true,
          );
      if (!mounted) return;
      final firstLoad = _data == null;
      setState(() {
        _data = resp;
        _now = DateTime.now();
        _loading = false;
      });
      if (firstLoad) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final progress = computeTripTrackProgress(resp.stops, resp.vehicle, _now);
          _scrollToInitialStop(resp, progress);
          if (_showMap) _focusBus(resp);
        });
      }
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

  void _scrollToInitialStop(TripResponse resp, TripTrackProgress progress) {
    if (!_stopsScrollController.hasClients || resp.stops.isEmpty) return;
    double targetIndex = 0;
    if (widget.highlightStopId != null) {
      final idx = resp.stops.indexWhere((s) => s.stopId == widget.highlightStopId);
      if (idx >= 0) {
        targetIndex = idx.toDouble();
      } else {
        targetIndex = progress.liveProgress ?? progress.scheduledProgress;
      }
    } else {
      targetIndex = progress.liveProgress ?? progress.scheduledProgress;
    }
    final pos = _stopsScrollController.position;
    final desired = (10.0 + targetIndex * _rowHeight - pos.viewportDimension * 0.25)
        .clamp(0.0, pos.maxScrollExtent);
    _stopsScrollController.jumpTo(desired);
  }

  void _toggleMap(TripResponse resp) {
    final nextShow = !_showMap;
    setState(() => _showMap = nextShow);
    if (nextShow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusBus(resp);
      });
    }
  }

  void _focusBus(TripResponse resp) {
    final progress = computeTripTrackProgress(resp.stops, resp.vehicle, _now);
    final target = _busFocusLatLng(resp, progress);
    try {
      _mapController.move(target, _busZoomLevel);
    } catch (_) {}
  }

  void _openFullScreenMap(TripResponse resp) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TripFullScreenMapScreen(
          tripId: widget.tripId,
          serviceDate: widget.serviceDate,
          initialResponse: resp,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.oneUi;
    final trip = _data?.trip;
    final lineName = trip?.routeShortName ?? widget.initialLine ?? '';
    final opId = trip?.operatorId ?? widget.initialOperator ?? 'ztm';
    final headsign = trip?.headsign ?? widget.initialHeadsign ?? 'Szczegóły kursu';
    final settings = AppScope.of(context).themeController;

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
              lineName.isNotEmpty ? 'Linia $lineName → $headsign' : headsign,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: p.ink,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              _data != null
                  ? '${operatorDisplayLabel(opId, lineName)} · ${_data!.stops.length} przystanków'
                  : 'Ładowanie trasy i pozycji na żywo...',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: p.inkSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _showMap ? 'Ukryj mapę' : 'Pokaż mapę',
            icon: Icon(_showMap ? Icons.map_rounded : Icons.map_outlined, color: p.ink),
            onPressed: _data == null ? null : () => _toggleMap(_data!),
          ),
          IconButton(
            tooltip: 'Odśwież',
            icon: Icon(Icons.refresh_rounded, color: p.ink),
            onPressed: _load,
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
                      title: 'Nie udało się pobrać kursu',
                      message: _error,
                      actionLabel: 'Spróbuj ponownie',
                      onAction: _load,
                    ),
                  )
                : ListenableBuilder(
                    listenable: settings,
                    builder: (context, _) => _buildBody(context, _data!, settings),
                  ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, TripResponse resp, ThemeController settings) {
    final p = context.oneUi;
    final trip = resp.trip;
    final vehicle = resp.vehicle;
    final stops = resp.stops;
    final progress = computeTripTrackProgress(stops, vehicle, _now);
    final routeAccent = lineBadgeColor(
      p,
      operatorId: trip.operatorId,
      shortName: trip.routeShortName,
    );

    final delaySec = vehicle?.delaySeconds ??
        stops
            .where((s) => s.delaySeconds != null)
            .map((s) => s.delaySeconds)
            .firstOrNull;
    final anyRt = trip.hasLiveLocation || stops.any((s) => s.isRealtime);
    final metaLine = _vehicleMetaLine(trip, vehicle, settings);
    final api = AppScope.of(context).api;
    final fromOfflineCache = api.lastTripFromCache || api.isOffline.value;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenH = MediaQuery.sizeOf(context).height;
        final maxSafeMapH = (constraints.maxHeight - 210).clamp(200.0, 560.0);
        final mapHeight = (screenH * 0.54).clamp(200.0, maxSafeMapH);

        return Column(
          children: [
            OfflineStatusStrip(onRetry: _load),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: OneUiCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        LineBadge(shortName: trip.routeShortName, operatorId: trip.operatorId),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  OperatorTag(
                                    operatorId: trip.operatorId,
                                    routeShortName: trip.routeShortName,
                                  ),
                                  LiveLocationPill(
                                    hasLiveLocation: trip.hasLiveLocation,
                                    isRealtime: anyRt,
                                    verbose: true,
                                  ),
                                  DelayPill(delaySeconds: delaySec, isRealtime: anyRt),
                                  if (fromOfflineCache)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: p.warnAmber.withValues(alpha: 0.16),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        'Zapisany kurs',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: p.warnAmber,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (metaLine.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  metaLine,
                                  style: TextStyle(fontSize: 12.5, color: p.inkSecondary),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _toggleMap(resp),
                        icon: Icon(
                          _showMap ? Icons.keyboard_arrow_up_rounded : Icons.map_outlined,
                          size: 18,
                        ),
                        label: Text(
                          _showMap ? 'Ukryj mapę' : 'Pokaż mapę',
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: p.accent,
                          side: BorderSide(color: p.accent.withValues(alpha: 0.32)),
                          backgroundColor: p.accentSoft.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_showMap)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: _TripMiniMapCard(
                  mapController: _mapController,
                  resp: resp,
                  progress: progress,
                  routeColor: routeAccent,
                  height: mapHeight,
                  onOpenFullScreen: () => _openFullScreenMap(resp),
                  onCenter: () => _focusBus(resp),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: OneUiCard(
                  padding: EdgeInsets.zero,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: RefreshIndicator(
                      onRefresh: _load,
                      color: p.accent,
                      child: Scrollbar(
                        controller: _stopsScrollController,
                        child: SingleChildScrollView(
                          controller: _stopsScrollController,
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: _DualTrackStopTimeline(
                            stops: stops,
                            progress: progress,
                            rowHeight: _rowHeight,
                            highlightStopId: widget.highlightStopId,
                            routeColor: routeAccent,
                            onStopTap: (stop) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => RouteTimetableBoardScreen(
                                    routeId: trip.routeId,
                                    directionId: trip.directionId,
                                    stopId: stop.stopId,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _vehicleMetaLine(TripDetail trip, LiveVehicle? vehicle, ThemeController settings) {
    if (!settings.showAdvancedBusInfo) return '';
    final parts = <String>[];
    if (settings.displayBusNumber && vehicle != null && vehicle.vehicleId.isNotEmpty) {
      parts.add('Pojazd #${vehicle.vehicleId}');
    }
    if (settings.displayBusPlate && vehicle != null && vehicle.licensePlate.isNotEmpty) {
      parts.add(vehicle.licensePlate);
    }
    if (settings.displayBusBrigade && trip.brigade.isNotEmpty) {
      parts.add('Brygada ${trip.brigade}');
    }
    if (settings.displayBusLowFloor && trip.wheelchairAccessible) {
      parts.add('Niskopodłogowy');
    }
    return parts.join(' · ');
  }
}

LatLng _busFocusLatLng(TripResponse resp, TripTrackProgress progress) {
  if (resp.vehicle != null) {
    return LatLng(resp.vehicle!.lat, resp.vehicle!.lon);
  }
  return LatLng(progress.scheduledPosition.$1, progress.scheduledPosition.$2);
}

void _fitTripRouteOnController(MapController controller, TripResponse resp) {
  final pts = <LatLng>[];
  if (resp.vehicle != null) {
    pts.add(LatLng(resp.vehicle!.lat, resp.vehicle!.lon));
  }
  for (final s in resp.stops) {
    pts.add(LatLng(s.lat, s.lon));
  }
  if (pts.length >= 2) {
    try {
      controller.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(pts),
          padding: const EdgeInsets.all(36),
        ),
      );
    } catch (_) {}
  } else if (pts.length == 1) {
    controller.move(pts.first, 15);
  }
}

const double _tripBusZoomLevel = 15.6;

class _TripRouteMap extends StatelessWidget {
  const _TripRouteMap({
    required this.mapController,
    required this.resp,
    required this.progress,
    required this.routeColor,
    this.onStopTap,
  });

  final MapController mapController;
  final TripResponse resp;
  final TripTrackProgress progress;
  final Color routeColor;
  final ValueChanged<TripStopCall>? onStopTap;

  @override
  Widget build(BuildContext context) {
    final p = context.oneUi;
    final polylinePts = resp.shape.isNotEmpty
        ? resp.shape.map((e) => LatLng(e.$1, e.$2)).toList()
        : resp.stops.map((s) => LatLng(s.lat, s.lon)).toList();

    final schedPos = LatLng(progress.scheduledPosition.$1, progress.scheduledPosition.$2);
    final focusPos = _busFocusLatLng(resp, progress);
    final veh = resp.vehicle;

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: focusPos,
        initialZoom: _tripBusZoomLevel,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'pl.maciejdbrznsk.pkstt',
          tileProvider: MapTileCache.createTileProvider(),
        ),
        if (polylinePts.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: polylinePts,
                color: routeColor.withValues(alpha: 0.85),
                strokeWidth: 4.5,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            for (final s in resp.stops)
              Marker(
                point: LatLng(s.lat, s.lon),
                width: onStopTap != null ? 18 : 12,
                height: onStopTap != null ? 18 : 12,
                child: GestureDetector(
                  onTap: onStopTap != null ? () => onStopTap!(s) : null,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: routeColor, width: 2.5),
                    ),
                  ),
                ),
              ),
            Marker(
              point: schedPos,
              width: 30,
              height: 30,
              child: Tooltip(
                message: 'Pozycja planowa wg rozkładu',
                child: Container(
                  decoration: BoxDecoration(
                    color: p.inkSecondary.withValues(alpha: 0.92),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.schedule_rounded, size: 16, color: Colors.white),
                ),
              ),
            ),
            if (veh != null)
              Marker(
                point: LatLng(veh.lat, veh.lon),
                width: 40,
                height: 40,
                child: Container(
                  decoration: BoxDecoration(
                    color: p.liveGreen,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                  child: const Icon(
                    Icons.directions_bus_rounded,
                    size: 22,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TripMiniMapCard extends StatelessWidget {
  const _TripMiniMapCard({
    required this.mapController,
    required this.resp,
    required this.progress,
    required this.routeColor,
    required this.height,
    required this.onOpenFullScreen,
    required this.onCenter,
  });

  final MapController mapController;
  final TripResponse resp;
  final TripTrackProgress progress;
  final Color routeColor;
  final double height;
  final VoidCallback onOpenFullScreen;
  final VoidCallback onCenter;

  @override
  Widget build(BuildContext context) {
    final p = context.oneUi;

    return OneUiCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              _TripRouteMap(
                mapController: mapController,
                resp: resp,
                progress: progress,
                routeColor: routeColor,
              ),
              Positioned(
                right: 10,
                top: 10,
                child: Column(
                  children: [
                    _MapMiniBtn(
                      icon: Icons.fullscreen_rounded,
                      tooltip: 'Mapa na pełnym ekranie',
                      onTap: onOpenFullScreen,
                    ),
                    const SizedBox(height: 8),
                    _MapMiniBtn(
                      icon: Icons.my_location_rounded,
                      tooltip: 'Wyśrodkuj na autobusie',
                      onTap: onCenter,
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 10,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: p.card.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '© OpenStreetMap',
                    style: TextStyle(fontSize: 10, color: p.inkSecondary),
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

class _MapMiniBtn extends StatelessWidget {
  const _MapMiniBtn({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final p = context.oneUi;
    final btn = Material(
      color: p.card.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: p.ink),
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}

/// Dedicated full-screen OpenStreetMap view for tracking a live trip and its route.
class TripFullScreenMapScreen extends StatefulWidget {
  const TripFullScreenMapScreen({
    super.key,
    required this.tripId,
    this.serviceDate,
    required this.initialResponse,
  });

  final String tripId;
  final String? serviceDate;
  final TripResponse initialResponse;

  @override
  State<TripFullScreenMapScreen> createState() => _TripFullScreenMapScreenState();
}

class _TripFullScreenMapScreenState extends State<TripFullScreenMapScreen> {
  final MapController _mapController = MapController();
  late TripResponse _resp;
  TripStopCall? _selectedStop;
  DateTime _now = DateTime.now();
  Timer? _refreshTimer;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _resp = widget.initialResponse;
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) => _refreshTrip());
    _clockTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshTrip() async {
    try {
      final latest = await AppScope.of(context).api.fetchTrip(
            widget.tripId,
            serviceDate: widget.serviceDate,
            includeShape: true,
          );
      if (!mounted) return;
      setState(() {
        _resp = latest;
        _now = DateTime.now();
      });
    } catch (_) {}
  }

  void _focusBus() {
    final progress = computeTripTrackProgress(_resp.stops, _resp.vehicle, _now);
    final target = _busFocusLatLng(_resp, progress);
    try {
      _mapController.move(target, 15.6);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final p = context.oneUi;
    final trip = _resp.trip;
    final stops = _resp.stops;
    final progress = computeTripTrackProgress(stops, _resp.vehicle, _now);
    final routeColor = lineBadgeColor(
      p,
      operatorId: trip.operatorId,
      shortName: trip.routeShortName,
    );
    final delaySec = _resp.vehicle?.delaySeconds ??
        stops.where((s) => s.delaySeconds != null).map((s) => s.delaySeconds).firstOrNull;
    final anyRt = trip.hasLiveLocation || stops.any((s) => s.isRealtime);

    return Scaffold(
      backgroundColor: p.canvas,
      body: Stack(
        children: [
          _TripRouteMap(
            mapController: _mapController,
            resp: _resp,
            progress: progress,
            routeColor: routeColor,
            onStopTap: (s) => setState(() => _selectedStop = s),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: OneUiCard(
                radius: 24,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_new_rounded, size: 19, color: p.ink),
                      tooltip: 'Wstecz',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            trip.routeShortName.isNotEmpty
                                ? 'Linia ${trip.routeShortName} → ${trip.headsign}'
                                : trip.headsign,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: p.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              LiveLocationPill(
                                hasLiveLocation: trip.hasLiveLocation,
                                isRealtime: anyRt,
                              ),
                              DelayPill(delaySeconds: delaySec, isRealtime: anyRt),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_selectedStop != null)
            Positioned(
              left: 16,
              right: 84,
              bottom: 24,
              child: SafeArea(
                child: OneUiCard(
                  radius: 22,
                  padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _selectedStop!.stopName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: p.ink,
                              ),
                            ),
                            Text(
                              _selectedStop!.isRealtime
                                  ? 'Odjazd: ${formatClock(_selectedStop!.estimatedDeparture)} (plan: ${formatClock(_selectedStop!.scheduledDepartureTime)})'
                                  : 'Planowo: ${formatClock(_selectedStop!.scheduledDepartureTime)}',
                              style: TextStyle(fontSize: 12.5, color: p.inkSecondary),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          final stopId = _selectedStop!.stopId;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RouteTimetableBoardScreen(
                                routeId: trip.routeId,
                                directionId: trip.directionId,
                                stopId: stopId,
                              ),
                            ),
                          );
                        },
                        child: const Text('Tabliczka'),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, size: 18, color: p.inkSecondary),
                        onPressed: () => setState(() => _selectedStop = null),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            right: 16,
            bottom: 24,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'trip_fit_route',
                    backgroundColor: p.card,
                    foregroundColor: p.ink,
                    onPressed: () => _fitTripRouteOnController(_mapController, _resp),
                    tooltip: 'Pokaż całą trasę',
                    child: const Icon(Icons.zoom_out_map_rounded),
                  ),
                  const SizedBox(height: 10),
                  FloatingActionButton(
                    heroTag: 'trip_center_bus',
                    backgroundColor: p.card,
                    foregroundColor: p.accent,
                    onPressed: _focusBus,
                    tooltip: 'Wyśrodkuj na autobusie',
                    child: const Icon(Icons.my_location_rounded),
                  ),
                ],
              ),
            ),
          ),
          if (_selectedStop == null)
            Positioned(
              left: 14,
              bottom: 24,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: p.card.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '© OpenStreetMap',
                    style: TextStyle(fontSize: 10.5, color: p.inkSecondary),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Custom dual vertical route timeline (Planowo line + Live GPS line) like mobileMPK.
class _DualTrackStopTimeline extends StatelessWidget {
  const _DualTrackStopTimeline({
    required this.stops,
    required this.progress,
    required this.rowHeight,
    required this.highlightStopId,
    required this.routeColor,
    required this.onStopTap,
  });

  final List<TripStopCall> stops;
  final TripTrackProgress progress;
  final double rowHeight;
  final String? highlightStopId;
  final Color routeColor;
  final ValueChanged<TripStopCall> onStopTap;

  @override
  Widget build(BuildContext context) {
    final p = context.oneUi;
    if (stops.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text('Brak przystanków na trasie.'),
      );
    }

    const railWidth = 66.0;
    const schedX = 20.0;
    const liveX = 46.0;
    final totalHeight = stops.length * rowHeight;

    final schedY = (progress.scheduledProgress * rowHeight) + rowHeight / 2;
    final liveY = progress.liveProgress != null
        ? (progress.liveProgress! * rowHeight) + rowHeight / 2
        : null;
    final liveColor = progress.hasGpsCoordinates
        ? p.liveGreen
        : (progress.hasLiveTrack ? p.accent : p.divider);

    return SizedBox(
      height: totalHeight,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            width: railWidth,
            height: totalHeight,
            child: CustomPaint(
              painter: _DualRailPainter(
                stopCount: stops.length,
                rowHeight: rowHeight,
                schedX: schedX,
                liveX: liveX,
                scheduledProgress: progress.scheduledProgress,
                liveProgress: progress.liveProgress,
                schedActiveColor: p.inkSecondary,
                schedRemainingColor: routeColor.withValues(alpha: 0.35),
                liveActiveColor: liveColor,
                liveRemainingColor: liveColor.withValues(alpha: 0.25),
                cardBg: p.card,
              ),
            ),
          ),
          Column(
            children: [
              for (var i = 0; i < stops.length; i++)
                _TripStopRow(
                  stop: stops[i],
                  height: rowHeight,
                  railWidth: railWidth,
                  isHighlighted: stops[i].stopId == highlightStopId,
                  isPassedLive: progress.liveProgress != null && i < progress.liveProgress!,
                  isPassedSched: i < progress.scheduledProgress,
                  onTap: () => onStopTap(stops[i]),
                ),
            ],
          ),
          // Scheduled vehicle indicator pill ("Plan")
          AnimatedPositioned(
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            left: schedX - 13,
            top: schedY - 13,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: p.inkSecondary,
                shape: BoxShape.circle,
                border: Border.all(color: p.card, width: 2),
              ),
              child: const Icon(Icons.schedule_rounded, size: 14, color: Colors.white),
            ),
          ),
          // Real-time / GPS vehicle indicator pill ("Live")
          if (liveY != null)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              left: liveX - 14,
              top: liveY - 14,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: liveColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: p.card, width: 2.5),
                ),
                child: const Icon(Icons.directions_bus_rounded, size: 15, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class _DualRailPainter extends CustomPainter {
  _DualRailPainter({
    required this.stopCount,
    required this.rowHeight,
    required this.schedX,
    required this.liveX,
    required this.scheduledProgress,
    required this.liveProgress,
    required this.schedActiveColor,
    required this.schedRemainingColor,
    required this.liveActiveColor,
    required this.liveRemainingColor,
    required this.cardBg,
  });

  final int stopCount;
  final double rowHeight;
  final double schedX;
  final double liveX;
  final double scheduledProgress;
  final double? liveProgress;
  final Color schedActiveColor;
  final Color schedRemainingColor;
  final Color liveActiveColor;
  final Color liveRemainingColor;
  final Color cardBg;

  @override
  void paint(Canvas canvas, Size size) {
    if (stopCount < 1) return;
    final firstY = rowHeight / 2;
    final lastY = (stopCount - 1) * rowHeight + rowHeight / 2;

    final schedCurY = (scheduledProgress * rowHeight) + rowHeight / 2;
    _drawTrack(canvas, schedX, firstY, lastY, schedCurY, schedActiveColor, schedRemainingColor);

    final liveCurY = liveProgress != null ? (liveProgress! * rowHeight) + rowHeight / 2 : firstY;
    _drawTrack(
      canvas,
      liveX,
      firstY,
      lastY,
      liveProgress != null ? liveCurY : firstY,
      liveActiveColor,
      liveRemainingColor,
    );

    final fillPaint = Paint()..color = cardBg;
    final schedRing = Paint()
      ..color = schedActiveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final liveRing = Paint()
      ..color = liveActiveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (var i = 0; i < stopCount; i++) {
      final y = i * rowHeight + rowHeight / 2;
      canvas.drawCircle(Offset(schedX, y), 4.5, fillPaint);
      canvas.drawCircle(Offset(schedX, y), 4.5, schedRing);
      canvas.drawCircle(Offset(liveX, y), 4.5, fillPaint);
      canvas.drawCircle(Offset(liveX, y), 4.5, liveRing);
    }
  }

  void _drawTrack(
    Canvas canvas,
    double x,
    double firstY,
    double lastY,
    double splitY,
    Color passedColor,
    Color upcomingColor,
  ) {
    if (lastY <= firstY) return;
    final upcomingPaint = Paint()
      ..color = upcomingColor
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x, firstY), Offset(x, lastY), upcomingPaint);

    final clampedSplit = splitY.clamp(firstY, lastY);
    if (clampedSplit > firstY) {
      final passedPaint = Paint()
        ..color = passedColor
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x, firstY), Offset(x, clampedSplit), passedPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DualRailPainter oldDelegate) =>
      oldDelegate.scheduledProgress != scheduledProgress ||
      oldDelegate.liveProgress != liveProgress ||
      oldDelegate.stopCount != stopCount;
}

class _TripStopRow extends StatelessWidget {
  const _TripStopRow({
    required this.stop,
    required this.height,
    required this.railWidth,
    required this.isHighlighted,
    required this.isPassedLive,
    required this.isPassedSched,
    required this.onTap,
  });

  final TripStopCall stop;
  final double height;
  final double railWidth;
  final bool isHighlighted;
  final bool isPassedLive;
  final bool isPassedSched;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.oneUi;
    final schedClock = formatClock(stop.scheduledDepartureTime);
    final estClock = formatClock(stop.estimatedDeparture);
    final showEst = stop.isRealtime && estClock != schedClock;
    final dimmed = isPassedLive || (!stop.isRealtime && isPassedSched);

    return SizedBox(
      height: height,
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: isHighlighted ? p.accentSoft.withValues(alpha: 0.45) : Colors.transparent,
          padding: EdgeInsets.fromLTRB(railWidth + 8, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            stop.stopName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: isHighlighted ? FontWeight.w800 : FontWeight.w600,
                              color: dimmed ? p.inkSecondary : p.ink,
                              decoration: stop.skipped ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (isHighlighted)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: p.accent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'TWÓJ PRZYSTANEK',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        if (stop.isOnDemand)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: p.warnAmber.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(6),
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
                        if (stop.skipped)
                          Text(
                            'Pominięty',
                            style: TextStyle(fontSize: 11, color: p.dangerRed, fontWeight: FontWeight.w700),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    showEst ? estClock : schedClock,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: showEst
                          ? ((stop.delaySeconds ?? 0) >= 120 ? p.dangerRed : p.liveGreen)
                          : (dimmed ? p.inkSecondary : p.ink),
                    ),
                  ),
                  if (showEst)
                    Text(
                      'Plan: $schedClock',
                      style: TextStyle(
                        fontSize: 11,
                        color: p.inkSecondary,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
