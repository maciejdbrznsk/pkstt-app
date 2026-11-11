import 'dart:async';
import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../app_scope.dart';
import '../models/transit_models.dart';
import '../services/map_tile_cache.dart';
import '../theme/one_ui_theme.dart';
import '../utils/transit_format.dart';
import '../widgets/one_ui_widgets.dart';
import 'stop_bays_screen.dart';
import 'trip_tracker_screen.dart';

/// Interactive OpenStreetMap view showing live ZTM/MPK & PKS/MKS buses and nearby stops.
class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({
    super.key,
    this.focusLat,
    this.focusLon,
    this.focusTitle,
  });

  final double? focusLat;
  final double? focusLon;
  final String? focusTitle;

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  static const _rzeszowCenter = LatLng(50.0412, 21.9991);

  final MapController _mapController = MapController();
  List<LiveVehicle> _vehicles = const [];
  List<StopGroup> _stops = const [];
  String _operatorFilter = '';
  bool _showStops = true;
  bool _mapReady = false;
  double _currentZoom = 13.4;
  LatLng? _renderedCenter;
  LatLng? _userLocation;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _currentZoom = widget.focusLat != null ? 15.8 : 13.4;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVehicles();
      _loadStops();
      _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) => _loadVehicles());
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    try {
      final list = await AppScope.of(context).api.fetchVehicles(operatorFilter: _operatorFilter);
      if (!mounted) return;
      setState(() => _vehicles = list);
    } catch (_) {
      if (mounted && _vehicles.isNotEmpty) {
        setState(() => _vehicles = const []);
      }
    }
  }

  bool _inVisibleArea(StopGroup s, LatLngBounds bounds) {
    final latPad = (bounds.north - bounds.south) * 0.25;
    final lonPad = (bounds.east - bounds.west) * 0.25;
    return s.lat >= bounds.south - latPad &&
        s.lat <= bounds.north + latPad &&
        s.lon >= bounds.west - lonPad &&
        s.lon <= bounds.east + lonPad;
  }

  Future<void> _loadStops() async {
    try {
      final groups = await AppScope.of(context).api.fetchAllStopGroups();
      if (!mounted) return;
      setState(() => _stops = groups);
    } catch (_) {}
  }

  Future<void> _centerOnUser() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _showToast('Włącz GPS, aby wyśrodkować mapę na sobie.');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        _showToast('Brak uprawnienia do lokalizacji.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (!mounted) return;
      final pt = LatLng(pos.latitude, pos.longitude);
      setState(() => _userLocation = pt);
      _mapController.move(pt, 15.2);
    } catch (_) {
      _showToast('Nie udało się odczytać pozycji GPS.');
    }
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _showVehicleSheet(LiveVehicle v) {
    final p = context.oneUi;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  LineBadge(shortName: v.routeShortName, operatorId: v.operatorId),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v.headsign.isNotEmpty ? v.headsign : 'Linia ${v.routeShortName}',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.ink),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          children: [
                            OperatorTag(
                              operatorId: v.operatorId,
                              routeShortName: v.routeShortName,
                            ),
                            const LiveLocationPill(
                              hasLiveLocation: true,
                              isRealtime: true,
                              verbose: true,
                            ),
                            DelayPill(
                              delaySeconds: v.delaySeconds,
                              isRealtime: v.delaySeconds != null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _vehicleDetailsText(v),
                style: TextStyle(fontSize: 13, color: p.inkSecondary),
              ),
              if (v.tripId.isNotEmpty) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TripTrackerScreen(
                            tripId: v.tripId,
                            initialLine: v.routeShortName,
                            initialHeadsign: v.headsign,
                            initialOperator: v.operatorId,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.timeline_rounded),
                    label: const Text(
                      'Śledź trasę (2 linie: plan vs GPS)',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: p.accent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showStopSheet(StopGroup g) {
    final p = context.oneUi;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                g.name,
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: p.ink),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  for (final op in g.operators) OperatorTag(operatorId: op),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StopBaysScreen(groupId: g.groupId, initialName: g.name),
                      ),
                    );
                  },
                  icon: const Icon(Icons.departure_board_rounded),
                  label: const Text(
                    'Wybierz słupek i zobacz odjazdy',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: p.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _vehicleDetailsText(LiveVehicle v) {
    final cfg = AppScope.of(context).themeController;
    final parts = <String>[];
    if (cfg.displayBusNumber && v.vehicleId.isNotEmpty) {
      parts.add('Pojazd #${v.vehicleId}');
    }
    if (cfg.displayBusPlate && v.licensePlate.isNotEmpty) {
      parts.add(v.licensePlate);
    }
    if (cfg.displayBusBrigade && v.brigade.isNotEmpty) {
      parts.add('Brygada ${v.brigade}');
    }
    if (v.speedMps != null) {
      parts.add('${(v.speedMps! * 3.6).round()} km/h');
    }
    parts.add('Aktualizacja: ${formatClock(v.timestamp)}');
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.oneUi;
    final initialCenter = widget.focusLat != null && widget.focusLon != null
        ? LatLng(widget.focusLat!, widget.focusLon!)
        : _rzeszowCenter;
    final initialZoom = widget.focusLat != null ? 15.8 : 13.4;

    final bounds = (_mapReady && _showStops && _currentZoom >= 13.8)
        ? _mapController.camera.visibleBounds
        : null;
    final visibleStops = (_showStops && _currentZoom >= 13.8)
        ? _stops
            .where(
              (s) =>
                  (_operatorFilter.isEmpty || s.operators.contains(_operatorFilter)) &&
                  (bounds == null || _inVisibleArea(s, bounds)),
            )
            .take(150)
            .toList()
        : const <StopGroup>[];

    return Scaffold(
      backgroundColor: p.canvas,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: initialZoom,
              onMapReady: () {
                setState(() {
                  _mapReady = true;
                  _currentZoom = _mapController.camera.zoom;
                  _renderedCenter = _mapController.camera.center;
                });
              },
              onPositionChanged: (camera, hasGesture) {
                final prevZoom = _currentZoom;
                final zoomChanged = (camera.zoom - prevZoom).abs() >= 0.25 ||
                    ((prevZoom < 13.8) != (camera.zoom < 13.8));
                final center = camera.center;
                final pannedEnough = camera.zoom >= 13.8 &&
                    (_renderedCenter == null ||
                        (center.latitude - _renderedCenter!.latitude).abs() >= 0.0025 ||
                        (center.longitude - _renderedCenter!.longitude).abs() >= 0.0035);
                if (zoomChanged ||
                    pannedEnough ||
                    (!hasGesture && camera.zoom >= 13.8 && center != _renderedCenter)) {
                  setState(() {
                    _currentZoom = camera.zoom;
                    _renderedCenter = center;
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'pl.maciejdbrznsk.pkstt',
                tileProvider: MapTileCache.createTileProvider(),
              ),
              MarkerLayer(
                markers: [
                  for (final s in visibleStops)
                    Marker(
                      point: LatLng(s.lat, s.lon),
                      width: 24,
                      height: 24,
                      child: GestureDetector(
                        onTap: () => _showStopSheet(s),
                        child: Container(
                          decoration: BoxDecoration(
                            color: p.card,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: s.operators.contains('ztm') && s.operators.contains('pks')
                                  ? p.accent
                                  : (s.operators.contains('ztm') ? p.ztmOrange : p.pksBlue),
                              width: 2.5,
                            ),
                          ),
                          child: Icon(Icons.directions_bus_filled_outlined, size: 13, color: p.ink),
                        ),
                      ),
                    ),
                  if (_userLocation != null)
                    Marker(
                      point: _userLocation!,
                      width: 22,
                      height: 22,
                      child: Container(
                        decoration: BoxDecoration(
                          color: p.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                      ),
                    ),
                  for (final v in _vehicles)
                    Marker(
                      point: LatLng(v.lat, v.lon),
                      width: 56,
                      height: 36,
                      child: GestureDetector(
                        onTap: () => _showVehicleSheet(v),
                        child: _BusMapMarker(vehicle: v),
                      ),
                    ),
                ],
              ),
            ],
          ),
          // Top floating One UI header & filter controls
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OneUiCard(
                    radius: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 19, color: p.ink),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        Expanded(
                          child: Text(
                            widget.focusTitle ?? 'Mapa na żywo',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: p.ink),
                          ),
                        ),
                        ValueListenableBuilder<bool>(
                          valueListenable: AppScope.of(context).api.isOffline,
                          builder: (context, offline, _) {
                            final pillBg = offline
                                ? p.warnAmber.withValues(alpha: 0.18)
                                : p.liveGreenSoft;
                            final pillFg = offline ? p.warnAmber : p.liveGreen;
                            return GestureDetector(
                              onTap: offline
                                  ? () {
                                      _loadVehicles();
                                      if (_stops.isEmpty) _loadStops();
                                    }
                                  : null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: pillBg,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  offline ? 'Tryb offline' : '${_vehicles.length} autobusów',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: pillFg,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  OneUiSegmentedPills<String>(
                    selected: _operatorFilter,
                    onSelected: (v) {
                      setState(() => _operatorFilter = v);
                      _loadVehicles();
                    },
                    options: [
                      ('', 'Wszystkie', null),
                      ('ztm', 'MPK / ZTM', p.ztmOrange),
                      ('pks', 'MKS / PKS', p.pksBlue),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Bottom-right floating action buttons & bottom-left OSM attribution
          Positioned(
            right: 16,
            bottom: 24,
            child: SafeArea(
              child: Column(
                children: [
                  FloatingActionButton.small(
                    heroTag: 'stops_toggle',
                    backgroundColor: _showStops ? p.accent : p.card,
                    foregroundColor: _showStops ? Colors.white : p.ink,
                    onPressed: () => setState(() => _showStops = !_showStops),
                    tooltip: 'Pokaż/ukryj przystanki (widoczne po przybliżeniu)',
                    child: const Icon(Icons.place_rounded),
                  ),
                  const SizedBox(height: 10),
                  FloatingActionButton(
                    heroTag: 'my_location',
                    backgroundColor: p.card,
                    foregroundColor: p.ink,
                    onPressed: _centerOnUser,
                    tooltip: 'Moja lokalizacja',
                    child: const Icon(Icons.my_location_rounded),
                  ),
                ],
              ),
            ),
          ),
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
                  '© OpenStreetMap · cache offline · Przystanki po przybliżeniu',
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

class _BusMapMarker extends StatelessWidget {
  const _BusMapMarker({required this.vehicle});

  final LiveVehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final p = context.oneUi;
    final bg = lineBadgeColor(
      p,
      operatorId: vehicle.operatorId,
      shortName: vehicle.routeShortName,
    );
    final label = vehicle.routeShortName.isNotEmpty ? vehicle.routeShortName : '?';

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            if (vehicle.bearing != null) ...[
              const SizedBox(width: 2),
              Transform.rotate(
                angle: vehicle.bearing! * math.pi / 180.0,
                child: const Icon(Icons.navigation_rounded, size: 12, color: Colors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
