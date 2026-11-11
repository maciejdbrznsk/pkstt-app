import 'dart:convert';
import 'dart:io';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pkstt/app_scope.dart';
import 'package:pkstt/main.dart';
import 'package:pkstt/models/transit_models.dart';
import 'package:pkstt/screens/trip_tracker_screen.dart';
import 'package:pkstt/services/api_client.dart';
import 'package:pkstt/services/favorites_store.dart';
import 'package:pkstt/services/offline_cache.dart';
import 'package:pkstt/theme/one_ui_theme.dart';
import 'package:pkstt/utils/transit_format.dart';

void main() {
  test('foldPolish folds diacritics and classifies operators accurately', () {
    expect(
      foldPolish('Marszałkowska Żółkiewskiego Źródlana ĄĘĆŃÓŚ'),
      'marszalkowska zolkiewskiego zrodlana aecnos',
    );
    expect(operatorDisplayLabel('ztm', '18'), 'MPK');
    expect(operatorDisplayLabel('ztm', 'N1'), 'MPK · Nocna');
    expect(operatorDisplayLabel('pks', '202'), 'MKS');
    expect(operatorDisplayLabel('pks', '108'), 'PKS');
    expect(isNightLine('ztm', 'N2'), isTrue);
    expect(isNightLine('ztm', '0A'), isFalse);
  });

  test('computeTripTrackProgress computes dual scheduled vs live GPS positions', () {
    final t0 = DateTime(2026, 11, 11, 20, 0, 0);
    final t1 = DateTime(2026, 11, 11, 20, 4, 0);
    final t2 = DateTime(2026, 11, 11, 20, 8, 0);

    final stops = [
      TripStopCall(
        stopSequence: 1,
        stopId: 'ztm:1',
        groupId: 'a',
        stopName: 'Start',
        platformCode: '01',
        isOnDemand: false,
        lat: 50.0400,
        lon: 22.0000,
        pickupType: 0,
        dropOffType: 0,
        shapeDistTraveled: 0,
        scheduledArrival: '20:00:00',
        scheduledDeparture: '20:00:00',
        scheduledArrivalTime: t0,
        scheduledDepartureTime: t0,
        estimatedArrival: t0,
        estimatedDeparture: t0,
        delaySeconds: 180,
        isRealtime: true,
        skipped: false,
      ),
      TripStopCall(
        stopSequence: 2,
        stopId: 'ztm:2',
        groupId: 'b',
        stopName: 'Middle',
        platformCode: '01',
        isOnDemand: false,
        lat: 50.0450,
        lon: 22.0000,
        pickupType: 0,
        dropOffType: 0,
        shapeDistTraveled: 500,
        scheduledArrival: '20:04:00',
        scheduledDeparture: '20:04:00',
        scheduledArrivalTime: t1,
        scheduledDepartureTime: t1,
        estimatedArrival: t1.add(const Duration(minutes: 3)),
        estimatedDeparture: t1.add(const Duration(minutes: 3)),
        delaySeconds: 180,
        isRealtime: true,
        skipped: false,
      ),
      TripStopCall(
        stopSequence: 3,
        stopId: 'ztm:3',
        groupId: 'c',
        stopName: 'End',
        platformCode: '01',
        isOnDemand: false,
        lat: 50.0500,
        lon: 22.0000,
        pickupType: 0,
        dropOffType: 0,
        shapeDistTraveled: 1000,
        scheduledArrival: '20:08:00',
        scheduledDeparture: '20:08:00',
        scheduledArrivalTime: t2,
        scheduledDepartureTime: t2,
        estimatedArrival: t2.add(const Duration(minutes: 3)),
        estimatedDeparture: t2.add(const Duration(minutes: 3)),
        delaySeconds: 180,
        isRealtime: true,
        skipped: false,
      ),
    ];

    final vehicleAtThreeQuarters = LiveVehicle(
      id: 'ztm:100',
      operatorId: 'ztm',
      vehicleId: '100',
      label: '100',
      licensePlate: 'RZ01',
      tripId: 'ztm:t1',
      routeId: 'ztm:18',
      routeShortName: '18',
      routeColor: 'D32A00',
      headsign: 'End',
      brigade: '18/1',
      directionId: 0,
      lat: 50.0475,
      lon: 22.0000,
      bearing: 0,
      speedMps: 10,
      currentStopSequence: 2,
      stopId: 'ztm:2',
      delaySeconds: 180,
      timestamp: t0.add(const Duration(minutes: 2)),
    );

    // Scheduled time at 20:02:00 is halfway between stop 0 (20:00) and stop 1 (20:04) => ~0.5.
    // GPS latitude 50.0475 is halfway between stop 1 (50.0450) and stop 2 (50.0500) => ~1.5.
    final prog = computeTripTrackProgress(
      stops,
      vehicleAtThreeQuarters,
      t0.add(const Duration(minutes: 2)),
    );
    expect(prog.scheduledProgress, closeTo(0.5, 0.01));
    expect(prog.hasLiveTrack, isTrue);
    expect(prog.hasGpsCoordinates, isTrue);
    expect(prog.liveProgress!, closeTo(1.5, 0.05));
  });

  test('FavoritesStore persists bay and group favorites', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = FavoritesStore(prefs);

    final fav = FavoriteStop(
      key: FavoritesStore.bayKey('marszalkowska', '01'),
      groupId: 'marszalkowska',
      title: 'Marszałkowska 01',
      subtitle: '18 → Łukasiewicza',
      operators: const ['ztm'],
      bayId: '01',
      stopIds: const ['ztm:66'],
    );

    await store.toggle(fav);
    expect(store.items.length, 1);
    expect(store.isFavorite(fav.key), isTrue);

    final reloaded = FavoritesStore(prefs);
    expect(reloaded.items.length, 1);
    expect(reloaded.items.first.stopIds, ['ztm:66']);

    await reloaded.toggle(fav);
    expect(reloaded.items, isEmpty);
  });

  testWidgets('HomeScreen renders One UI 9 hub cards and favorites section', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final mockHttp = MockClient((req) async {
      if (req.url.path == '/v1/meta') {
        return http.Response(
          jsonEncode({
            'realtime_feeds': [
              {'feed': 'ztm', 'vehicle_count': 42, 'trip_update_count': 42, 'alert_count': 0, 'stale': false},
              {'feed': 'pks', 'vehicle_count': 12, 'trip_update_count': 15, 'alert_count': 0, 'stale': false},
            ],
          }),
          200,
        );
      }
      if (req.url.path == '/v1/alerts') {
        return http.Response(jsonEncode({'alerts': [], 'count': 0}), 200);
      }
      return http.Response('{}', 404);
    });

    final app = PksttApp(
      apiClient: PksttApiClient(httpClient: mockHttp),
      favoritesStore: FavoritesStore(prefs),
      themeController: ThemeController(prefs),
    );

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(find.text('PKSTT Rzeszów'), findsAtLeastNWidgets(1));
    expect(find.text('Rozkład jazdy przystanku'), findsOneWidget);
    expect(find.text('Rozkład jazdy linii'), findsOneWidget);
    expect(find.text('Mapa na żywo'), findsOneWidget);
    expect(find.text('54 na żywo'), findsOneWidget);
    expect(find.text('ULUBIONE PRZYSTANKI'), findsOneWidget);
  });

  test('PksttApiClient preserves colon separator in canonical route and trip IDs', () async {
    final capturedPaths = <String>[];
    final mockHttp = MockClient((req) async {
      capturedPaths.add(req.url.path);
      if (req.url.path == '/v1/routes/ztm:18/timetable') {
        return http.Response(
          jsonEncode({
            'route': {
              'id': 'ztm:18',
              'operator': 'ztm',
              'short_name': '18',
              'route_type': 3,
            },
            'directions': [],
            'selected_direction_id': 0,
            'stops': [],
            'active_service_ids': [],
            'day_types': [],
            'legend': [],
          }),
          200,
        );
      }
      if (req.url.path == '/v1/trips/ztm:225838') {
        return http.Response(
          jsonEncode({
            'trip': {
              'id': 'ztm:225838',
              'operator': 'ztm',
              'route_id': 'ztm:28',
              'route_short_name': '28',
              'headsign': 'Lubelska MPK',
              'direction_id': 0,
              'brigade': '',
              'wheelchair_accessible': true,
              'shape_id': '',
              'service_date': '2026-11-11',
              'has_live_location': false,
            },
            'vehicle': null,
            'stops': [],
            'shape': [],
          }),
          200,
        );
      }
      return http.Response('{"error":"bad path"}', 400);
    });

    final api = PksttApiClient(httpClient: mockHttp);
    await api.fetchRouteTimetable('ztm:18');
    await api.fetchTrip('ztm:225838');

    expect(capturedPaths, [
      '/v1/routes/ztm:18/timetable',
      '/v1/trips/ztm:225838',
    ]);
  });

  test('ThemeController keeps advanced bus details off by default and persists toggles', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final ctrl = ThemeController(prefs);

    expect(ctrl.showAdvancedBusInfo, isFalse);
    expect(ctrl.displayBusNumber, isFalse);
    expect(ctrl.displayBusPlate, isFalse);
    expect(ctrl.displayBusBrigade, isFalse);
    expect(ctrl.displayBusLowFloor, isFalse);

    await ctrl.setShowAdvancedBusInfo(true);
    await ctrl.setShowBusPlate(false);

    final reloaded = ThemeController(prefs);
    expect(reloaded.showAdvancedBusInfo, isTrue);
    expect(reloaded.displayBusNumber, isTrue);
    expect(reloaded.displayBusPlate, isFalse);
    expect(reloaded.displayBusBrigade, isTrue);
    expect(reloaded.displayBusLowFloor, isTrue);
  });

  test('PksttApiClient requests 24h departures window with explicit at timestamp', () async {
    Uri? capturedUri;
    final mockHttp = MockClient((req) async {
      capturedUri = req.url;
      return http.Response(
        jsonEncode({
          'group_id': 'zalesie-szkola',
          'group_name': 'Zalesie szkoła',
          'generated_at': '2026-11-11T22:00:00Z',
          'stops': [],
          'departures': [],
        }),
        200,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final api = PksttApiClient(httpClient: mockHttp);
    await api.fetchStopGroupDepartures('zalesie-szkola');

    expect(capturedUri, isNotNull);
    expect(capturedUri!.path, '/v1/stop-groups/zalesie-szkola/departures');
    expect(capturedUri!.queryParameters['window'], '1440');
    expect(capturedUri!.queryParameters['limit'], '50');
    expect(capturedUri!.queryParameters['at'], isNotEmpty);
  });

  testWidgets(
      'TripTrackerScreen hides map initially, expands to ~54% height zoomed on bus, and opens TripFullScreenMapScreen',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final mockHttp = MockClient((req) async {
      if (req.url.path == '/v1/trips/ztm:225838') {
        return http.Response(
          jsonEncode({
            'trip': {
              'id': 'ztm:225838',
              'operator': 'ztm',
              'route_id': 'ztm:18',
              'route_short_name': '18',
              'headsign': 'Łukasiewicza',
              'direction_id': 0,
              'brigade': '18/2',
              'wheelchair_accessible': true,
              'shape_id': '',
              'service_date': '2026-11-11',
              'has_live_location': true,
            },
            'vehicle': {
              'feed': 'ztm',
              'operator': 'ztm',
              'vehicle_id': '705',
              'license_plate': 'RZ 12345',
              'trip_id': 'ztm:225838',
              'route_id': 'ztm:18',
              'route_short_name': '18',
              'headsign': 'Łukasiewicza',
              'brigade': '18/2',
              'lat': 50.0412,
              'lon': 22.0045,
              'timestamp': '2026-11-11T21:55:00Z',
            },
            'stops': [
              {
                'stop_sequence': 1,
                'stop_id': 'ztm:1',
                'group_id': 'start',
                'stop_name': 'Startowy',
                'platform_code': '01',
                'is_on_demand': false,
                'lat': 50.0300,
                'lon': 21.9900,
                'pickup_type': 0,
                'drop_off_type': 0,
                'shape_dist_traveled': 0,
                'scheduled_arrival': '21:50:00',
                'scheduled_departure': '21:50:00',
                'scheduled_arrival_time': '2026-11-11T20:50:00Z',
                'scheduled_departure_time': '2026-11-11T20:50:00Z',
                'estimated_arrival': '2026-11-11T20:50:00Z',
                'estimated_departure': '2026-11-11T20:50:00Z',
                'is_realtime': false,
                'skipped': false,
              },
              {
                'stop_sequence': 2,
                'stop_id': 'ztm:2',
                'group_id': 'end',
                'stop_name': 'Końcowy',
                'platform_code': '02',
                'is_on_demand': false,
                'lat': 50.0550,
                'lon': 22.0200,
                'pickup_type': 0,
                'drop_off_type': 0,
                'shape_dist_traveled': 2500,
                'scheduled_arrival': '22:05:00',
                'scheduled_departure': '22:05:00',
                'scheduled_arrival_time': '2026-11-11T21:05:00Z',
                'scheduled_departure_time': '2026-11-11T21:05:00Z',
                'estimated_arrival': '2026-11-11T21:05:00Z',
                'estimated_departure': '2026-11-11T21:05:00Z',
                'is_realtime': false,
                'skipped': false,
              },
            ],
            'shape': [],
          }),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('{}', 404);
    });

    final themeController = ThemeController(prefs);
    await tester.pumpWidget(
      AppScope(
        api: PksttApiClient(httpClient: mockHttp),
        favorites: FavoritesStore(prefs),
        themeController: themeController,
        child: MaterialApp(
          theme: buildOneUiTheme(brightness: Brightness.light, useDynamicColor: false),
          home: const TripTrackerScreen(tripId: 'ztm:225838'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(FlutterMap), findsNothing);
    expect(find.text('Pokaż mapę'), findsOneWidget);

    await tester.tap(find.text('Pokaż mapę'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final mapFinder = find.byType(FlutterMap);
    expect(mapFinder, findsOneWidget);
    final mapSize = tester.getSize(mapFinder);
    expect(mapSize.height, inInclusiveRange(400.0, 480.0));

    final mapWidget = tester.widget<FlutterMap>(mapFinder);
    expect(mapWidget.options.initialCenter.latitude, closeTo(50.0412, 0.0001));
    expect(mapWidget.options.initialCenter.longitude, closeTo(22.0045, 0.0001));
    expect(mapWidget.options.initialZoom, closeTo(15.6, 0.01));

    await tester.tap(find.byIcon(Icons.fullscreen_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(TripFullScreenMapScreen), findsOneWidget);
    expect(find.byIcon(Icons.zoom_out_map_rounded), findsOneWidget);
  });

  test('ThemeController customAccent persists and adapts contrast for dark mode', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final controller = ThemeController(prefs);

    await controller.setUseDynamicColor(false);
    final orange = kOneUiAccentPresets[1].color;
    await controller.setCustomAccent(orange);

    expect(controller.useDynamicColor, isFalse);
    expect(controller.customAccent.toARGB32(), orange.toARGB32());

    // Reload controller from same SharedPreferences
    final reloaded = ThemeController(prefs);
    expect(reloaded.useDynamicColor, isFalse);
    expect(reloaded.customAccent.toARGB32(), orange.toARGB32());

    // Dark-mode adaptation raises lightness of deep custom accents for OLED legibility
    const deepNavy = Color(0xFF002266);
    final lightTheme = buildOneUiTheme(
      brightness: Brightness.light,
      useDynamicColor: false,
      customAccent: deepNavy,
    );
    final darkTheme = buildOneUiTheme(
      brightness: Brightness.dark,
      useDynamicColor: false,
      customAccent: deepNavy,
    );

    expect(lightTheme.extension<OneUiPalette>()!.accent.toARGB32(), deepNavy.toARGB32());
    final adaptedLightness =
        HSLColor.fromColor(darkTheme.extension<OneUiPalette>()!.accent).lightness;
    expect(adaptedLightness, greaterThanOrEqualTo(0.56));
  });

  test('DiskOfflineCacheStore persists gzipped payloads, reports size, and clears cleanly',
      () async {
    final tempDir = Directory.systemTemp.createTempSync('pkstt_cache_test_');
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    final store = DiskOfflineCacheStore(tempDir);
    await store.writeActiveStaticVersion('ztm=v1');
    await store.writeJson(
      'catalog',
      'routes_all',
      {
        'routes': [
          {'id': 'ztm:18', 'operator': 'ztm', 'short_name': '18', 'long_name': 'A - B'},
        ],
      },
      version: 'ztm=v1',
    );

    expect(await store.totalBytes(), greaterThan(0));

    // Reopen from disk in a fresh DiskOfflineCacheStore instance
    final reopened = DiskOfflineCacheStore(tempDir);
    expect(await reopened.readActiveStaticVersion(), 'ztm=v1');
    final cached = await reopened.readJson('catalog', 'routes_all');
    expect(cached, isNotNull);
    expect(cached!.version, 'ztm=v1');
    expect((cached.data['routes'] as List).length, 1);

    await reopened.clearAll();
    expect(await reopened.readActiveStaticVersion(), isNull);
    expect(await reopened.readJson('catalog', 'routes_all'), isNull);
    expect(await reopened.totalBytes(), 0);
  });

  test('PksttApiClient uses versioned cache, skips redundant fetches, updates on change, and works offline',
      () async {
    final tempDir = Directory.systemTemp.createTempSync('pkstt_api_offline_test_');
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    var serverFeedVersion = '2026-11-11-v1';
    var offlineMode = false;
    final pathsSession1 = <String>[];
    final pathsSession2 = <String>[];
    final pathsSession3 = <String>[];
    var activePaths = pathsSession1;

    final nowUtc = DateTime.now().toUtc();
    final futureDep = nowUtc.add(const Duration(minutes: 25)).toIso8601String();
    final pastDep = nowUtc.subtract(const Duration(minutes: 20)).toIso8601String();

    http.Client buildMockClient() => MockClient((req) async {
          activePaths.add(req.url.path);
          if (offlineMode) {
            throw const SocketException('Brak sieci');
          }
          if (req.url.path == '/v1/meta') {
            return http.Response(
              jsonEncode({
                'timezone': 'Europe/Warsaw',
                'static_feeds': [
                  {
                    'feed': 'ztm',
                    'feed_version': serverFeedVersion,
                    'feed_start_date': '20261101',
                    'feed_end_date': '20261231',
                    'last_updated_at': '2026-11-11T10:00:00Z',
                    'last_error': '',
                  },
                ],
                'realtime_feeds': [],
              }),
              200,
              headers: const {'content-type': 'application/json; charset=utf-8'},
            );
          }
          if (req.url.path == '/v1/stop-groups' && !req.url.queryParameters.containsKey('lat')) {
            return http.Response(
              jsonEncode({
                'stop_groups': [
                  {
                    'group_id': 'group:near',
                    'name': 'Marszałkowska',
                    'operators': ['ztm'],
                    'lat': 50.0420,
                    'lon': 22.0000,
                    'stop_count': 2,
                    'platforms': [],
                  },
                  {
                    'group_id': 'group:far',
                    'name': 'Odległy',
                    'operators': ['pks'],
                    'lat': 50.1500,
                    'lon': 22.1500,
                    'stop_count': 1,
                    'platforms': [],
                  },
                ],
              }),
              200,
              headers: const {'content-type': 'application/json; charset=utf-8'},
            );
          }
          if (req.url.path == '/v1/routes') {
            return http.Response(
              jsonEncode({
                'routes': [
                  {
                    'id': 'ztm:18',
                    'operator': 'ztm',
                    'short_name': '18',
                    'long_name':
                        serverFeedVersion == '2026-11-11-v1' ? 'Trasa v1' : 'Trasa v2',
                    'route_type': 3,
                  },
                ],
              }),
              200,
              headers: const {'content-type': 'application/json; charset=utf-8'},
            );
          }
          if (req.url.path == '/v1/stop-groups/group:near/departures') {
            return http.Response(
              jsonEncode({
                'departures': [
                  {
                    'operator': 'ztm',
                    'stop_id': 'ztm:s1',
                    'stop_name': 'Marszałkowska 01',
                    'platform_code': '01',
                    'route_id': 'ztm:18',
                    'route_short_name': '18',
                    'route_color': 'D32A00',
                    'route_text_color': 'FFFFFF',
                    'trip_id': 'ztm:t1',
                    'service_date': '2026-11-11',
                    'headsign': 'Łukasiewicza',
                    'brigade': '1',
                    'wheelchair_accessible': true,
                    'scheduled_departure': '12:30:00',
                    'scheduled_time': futureDep,
                    'estimated_time': futureDep,
                    'delay_seconds': 120,
                    'is_realtime': true,
                    'has_live_location': true,
                    'canceled': false,
                    'skipped': false,
                    'vehicle_id': '301',
                  },
                  {
                    'operator': 'ztm',
                    'stop_id': 'ztm:s1',
                    'stop_name': 'Marszałkowska 01',
                    'platform_code': '01',
                    'route_id': 'ztm:18',
                    'route_short_name': '18',
                    'route_color': 'D32A00',
                    'route_text_color': 'FFFFFF',
                    'trip_id': 'ztm:past',
                    'service_date': '2026-11-11',
                    'headsign': 'Stary kurs',
                    'brigade': '1',
                    'wheelchair_accessible': false,
                    'scheduled_departure': '11:40:00',
                    'scheduled_time': pastDep,
                    'estimated_time': pastDep,
                    'delay_seconds': 0,
                    'is_realtime': false,
                    'has_live_location': false,
                    'canceled': false,
                    'skipped': false,
                    'vehicle_id': '',
                  },
                ],
              }),
              200,
              headers: const {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response('{}', 404);
        });

    // Session 1: Populate disk cache at v1
    final api1 = PksttApiClient(
      httpClient: buildMockClient(),
      cacheStore: DiskOfflineCacheStore(tempDir),
    );
    final sync1 = await api1.syncStaticVersion(force: true);
    expect(sync1.online, isTrue);
    expect(sync1.updated, isFalse);
    final stops1 = await api1.fetchAllStopGroups();
    final routes1 = await api1.fetchRoutes();
    final deps1 = await api1.fetchStopGroupDepartures('group:near');
    expect(stops1.length, 2);
    expect(routes1.single.longName, 'Trasa v1');
    expect(deps1.length, 2);
    expect(pathsSession1, containsAll(['/v1/meta', '/v1/stop-groups', '/v1/routes']));

    // Session 2: Cold restart with SAME server feed_version -> skips stop-groups & routes network fetches
    activePaths = pathsSession2;
    final api2 = PksttApiClient(
      httpClient: buildMockClient(),
      cacheStore: DiskOfflineCacheStore(tempDir),
    );
    final stops2 = await api2.fetchAllStopGroups();
    final routes2 = await api2.fetchRoutes();
    expect(stops2.length, 2);
    expect(routes2.single.longName, 'Trasa v1');
    expect(pathsSession2, contains('/v1/meta'));
    expect(pathsSession2, isNot(contains('/v1/stop-groups')));
    expect(pathsSession2, isNot(contains('/v1/routes')));

    // Session 3: Server publishes feed_version v2 -> auto-detects update and re-fetches routes
    serverFeedVersion = '2026-11-11-v2';
    activePaths = pathsSession3;
    final api3 = PksttApiClient(
      httpClient: buildMockClient(),
      cacheStore: DiskOfflineCacheStore(tempDir),
    );
    final sync3 = await api3.syncStaticVersion(force: true);
    expect(sync3.updated, isTrue);
    final routes3 = await api3.fetchRoutes();
    expect(routes3.single.longName, 'Trasa v2');
    expect(pathsSession3, contains('/v1/routes'));

    // Session 4: Offline mode -> cached stops, offline Haversine nearby, offline scheduled 24h departures
    offlineMode = true;
    final apiOffline = PksttApiClient(
      httpClient: buildMockClient(),
      cacheStore: DiskOfflineCacheStore(tempDir),
    );
    final cachedStops = await apiOffline.fetchAllStopGroups();
    expect(cachedStops.length, 2);
    expect(apiOffline.isOffline.value, isTrue);

    final nearbyOffline = await apiOffline.fetchNearbyStopGroups(
      50.0412,
      21.9991,
      radiusMeters: 1500,
    );
    expect(nearbyOffline.map((g) => g.groupId).toList(), ['group:near']);
    expect(nearbyOffline.single.distanceMeters, lessThan(300));

    final offlineDeps = await apiOffline.fetchStopGroupDepartures('group:near');
    expect(apiOffline.lastDeparturesFromCache, isTrue);
    expect(offlineDeps.length, 1);
    expect(offlineDeps.single.tripId, 'ztm:t1');
    expect(offlineDeps.single.isRealtime, isFalse);
    expect(offlineDeps.single.hasLiveLocation, isFalse);

    // Online recovery clears offline flag
    offlineMode = false;
    final syncBack = await apiOffline.syncStaticVersion(force: true);
    expect(syncBack.online, isTrue);
    expect(apiOffline.isOffline.value, isFalse);
  });
}
