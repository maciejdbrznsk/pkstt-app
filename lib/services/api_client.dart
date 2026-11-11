import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/transit_models.dart';
import 'offline_cache.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.isNetworkError = false});

  final String message;
  final int? statusCode;
  final bool isNetworkError;

  @override
  String toString() =>
      statusCode != null ? 'Błąd API ($statusCode): $message' : 'Błąd sieci: $message';
}

class StaticSyncResult {
  const StaticSyncResult({
    required this.online,
    required this.updated,
    required this.meta,
  });

  final bool online;
  final bool updated;
  final MetaResponse? meta;
}

/// Client for the unified Rzeszów ZTM + PKS backend (`https://pkstt.maciejdobrzanski.ovh`)
/// with persistent versioned offline caching and graceful online/offline recovery.
class PksttApiClient {
  PksttApiClient({
    this.baseUrl = 'https://pkstt.maciejdobrzanski.ovh',
    http.Client? httpClient,
    OfflineCacheStore? cacheStore,
  })  : _client = httpClient ?? http.Client(),
        _cache = cacheStore ?? InMemoryOfflineCacheStore();

  final String baseUrl;
  final http.Client _client;
  final OfflineCacheStore _cache;

  static const Duration _versionCheckInterval = Duration(minutes: 5);
  static const Distance _geoDistance = Distance();

  final ValueNotifier<bool> isOffline = ValueNotifier<bool>(false);
  final ValueNotifier<List<StaticFeedStatus>> staticFeeds =
      ValueNotifier<List<StaticFeedStatus>>(const []);
  final ValueNotifier<DateTime?> lastSyncAt = ValueNotifier<DateTime?>(null);

  bool lastDeparturesFromCache = false;
  bool lastTripFromCache = false;

  List<StopGroup>? _cachedAllGroups;
  List<RouteSummary>? _cachedRoutes;
  MetaResponse? _lastMeta;
  DateTime? _lastMetaCheckedAt;
  Future<StaticSyncResult>? _inflightSync;

  void clearCaches() {
    _cachedAllGroups = null;
    _cachedRoutes = null;
    _lastMetaCheckedAt = null;
  }

  Future<int> getScheduleCacheBytes() => _cache.totalBytes();

  Future<void> clearScheduleCache() async {
    clearCaches();
    _lastMeta = null;
    staticFeeds.value = const [];
    lastSyncAt.value = null;
    await _cache.clearAll();
  }

  bool _isConnectivityFailure(ApiException e) =>
      e.isNetworkError || (e.statusCode != null && e.statusCode! >= 500);

  Future<Map<String, dynamic>> _getJson(
    String path, {
    Map<String, String>? query,
    Duration timeout = const Duration(seconds: 9),
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: query != null && query.isNotEmpty ? query : null,
    );
    try {
      final res = await _client.get(uri).timeout(timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        String msg = res.reasonPhrase ?? 'Nieznany błąd';
        try {
          final body = jsonDecode(res.body);
          if (body is Map<String, dynamic> && body['error'] is String) {
            msg = body['error'] as String;
          }
        } catch (_) {}
        if (res.statusCode < 500) {
          isOffline.value = false;
        } else {
          isOffline.value = true;
        }
        throw ApiException(msg, statusCode: res.statusCode);
      }
      isOffline.value = false;
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } on ApiException {
      rethrow;
    } on SocketException catch (e) {
      isOffline.value = true;
      throw ApiException('Brak połączenia z serwerem (${e.message})', isNetworkError: true);
    } on TimeoutException {
      isOffline.value = true;
      throw ApiException('Przekroczono czas oczekiwania na serwer', isNetworkError: true);
    } on http.ClientException catch (e) {
      isOffline.value = true;
      throw ApiException(e.message, isNetworkError: true);
    } catch (e) {
      isOffline.value = true;
      throw ApiException(e.toString(), isNetworkError: true);
    }
  }

  /// Checks `/v1/meta` to detect whether static GTFS schedules changed on the backend.
  /// Deduplicates concurrent calls and throttles repeated checks within 5 minutes unless [force] is true.
  Future<StaticSyncResult> syncStaticVersion({bool force = false}) {
    if (!force &&
        _lastMetaCheckedAt != null &&
        DateTime.now().difference(_lastMetaCheckedAt!) < _versionCheckInterval) {
      return Future.value(
        StaticSyncResult(
          online: !isOffline.value,
          updated: false,
          meta: _lastMeta,
        ),
      );
    }
    return _inflightSync ??= _runStaticVersionSync().whenComplete(() {
      _inflightSync = null;
    });
  }

  Future<StaticSyncResult> _runStaticVersionSync() async {
    try {
      final json = await _getJson('/v1/meta', timeout: const Duration(seconds: 7));
      final meta = MetaResponse.fromJson(json);
      final serverVersion = meta.staticVersionKey;
      final savedVersion = await _cache.readActiveStaticVersion();
      final updated =
          serverVersion.isNotEmpty && savedVersion != null && savedVersion != serverVersion;

      if (serverVersion.isNotEmpty && savedVersion != serverVersion) {
        await _cache.writeActiveStaticVersion(serverVersion);
        if (savedVersion != null) {
          _cachedAllGroups = null;
          _cachedRoutes = null;
        }
      }
      await _cache.writeJson('meta', 'latest', json, version: serverVersion);
      _lastMeta = meta;
      _lastMetaCheckedAt = DateTime.now();
      staticFeeds.value = meta.staticFeeds;
      lastSyncAt.value = _lastMetaCheckedAt;

      return StaticSyncResult(online: true, updated: updated, meta: meta);
    } on ApiException {
      final cached = await _cache.readJson('meta', 'latest');
      if (cached != null) {
        final meta = MetaResponse.fromJson(cached.data);
        _lastMeta = meta;
        staticFeeds.value = meta.staticFeeds;
        lastSyncAt.value ??= cached.savedAt;
        return StaticSyncResult(online: false, updated: false, meta: meta);
      }
      return const StaticSyncResult(online: false, updated: false, meta: null);
    }
  }

  Future<List<RealtimeFeedStatus>> fetchMeta() async {
    final sync = await syncStaticVersion(force: true);
    if (!sync.online) {
      return const [];
    }
    return sync.meta?.realtimeFeeds ?? const [];
  }

  Future<Map<String, dynamic>> _fetchStaticJson({
    required String namespace,
    required String key,
    required String path,
    Map<String, String>? query,
    bool forceRefresh = false,
  }) async {
    final cached = await _cache.readJson(namespace, key);
    var activeVersion = await _cache.readActiveStaticVersion() ?? '';

    if (cached != null && !forceRefresh) {
      if (_lastMetaCheckedAt == null ||
          DateTime.now().difference(_lastMetaCheckedAt!) >= _versionCheckInterval) {
        final sync = await syncStaticVersion();
        activeVersion = sync.meta?.staticVersionKey ?? activeVersion;
      }
      if (isOffline.value || activeVersion.isEmpty || cached.version == activeVersion) {
        return cached.data;
      }
    } else if (forceRefresh) {
      final sync = await syncStaticVersion(force: true);
      activeVersion = sync.meta?.staticVersionKey ?? activeVersion;
    }

    try {
      final fresh = await _getJson(
        path,
        query: query,
        timeout: const Duration(seconds: 12),
      );
      await _cache.writeJson(namespace, key, fresh, version: activeVersion);
      return fresh;
    } on ApiException catch (e) {
      if (_isConnectivityFailure(e) && cached != null) {
        return cached.data;
      }
      rethrow;
    }
  }

  Future<List<StopGroup>> fetchAllStopGroups({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedAllGroups != null) {
      return _cachedAllGroups!;
    }
    final json = await _fetchStaticJson(
      namespace: 'catalog',
      key: 'stop_groups_all',
      path: '/v1/stop-groups',
      query: const {'limit': '2000'},
      forceRefresh: forceRefresh,
    );
    final list = (json['stop_groups'] as List<dynamic>?) ?? const [];
    final parsed = list
        .map((e) => StopGroup.fromJson(e as Map<String, dynamic>))
        .toList();
    _cachedAllGroups = parsed;
    return parsed;
  }

  Future<List<StopGroup>> fetchNearbyStopGroups(
    double lat,
    double lon, {
    int radiusMeters = 1500,
    int limit = 40,
  }) async {
    try {
      final json = await _getJson(
        '/v1/stop-groups',
        query: {
          'lat': lat.toStringAsFixed(6),
          'lon': lon.toStringAsFixed(6),
          'radius': radiusMeters.toString(),
          'limit': limit.toString(),
        },
        timeout: const Duration(seconds: 7),
      );
      final list = (json['stop_groups'] as List<dynamic>?) ?? const [];
      return list
          .map((e) => StopGroup.fromJson(e as Map<String, dynamic>))
          .toList();
    } on ApiException catch (e) {
      if (!_isConnectivityFailure(e)) rethrow;
      // Offline fallback: calculate nearby stops from locally cached stop groups.
      final all = _cachedAllGroups ?? await fetchAllStopGroups();
      final origin = LatLng(lat, lon);
      final nearby = <StopGroup>[];
      for (final g in all) {
        final d = _geoDistance.as(LengthUnit.Meter, origin, LatLng(g.lat, g.lon));
        if (d <= radiusMeters) {
          nearby.add(
            StopGroup(
              groupId: g.groupId,
              name: g.name,
              operators: g.operators,
              lat: g.lat,
              lon: g.lon,
              stopCount: g.stopCount,
              platforms: g.platforms,
              distanceMeters: d,
            ),
          );
        }
      }
      nearby.sort((a, b) => (a.distanceMeters ?? 0).compareTo(b.distanceMeters ?? 0));
      return nearby.take(limit).toList();
    }
  }

  String _encodeCanonicalSegment(String value) {
    final idx = value.indexOf(':');
    if (idx > 0) {
      final feed = Uri.encodeComponent(value.substring(0, idx));
      final raw = Uri.encodeComponent(value.substring(idx + 1));
      return '$feed:$raw';
    }
    return Uri.encodeComponent(value);
  }

  Future<StopGroupDetail> fetchStopGroupDetail(
    String groupId, {
    bool forceRefresh = false,
  }) async {
    final json = await _fetchStaticJson(
      namespace: 'stop_detail',
      key: groupId,
      path: '/v1/stop-groups/${_encodeCanonicalSegment(groupId)}',
      forceRefresh: forceRefresh,
    );
    return StopGroupDetail.fromJson(json);
  }

  Future<List<DepartureItem>> fetchStopGroupDepartures(
    String groupId, {
    List<String>? stopIds,
    String operatorFilter = '',
    int limit = 50,
    int windowMinutes = 1440,
  }) async {
    final sortedIds = [...?stopIds]..sort();
    final cacheKey = '$groupId|stops=${sortedIds.join(",")}|op=$operatorFilter';
    final query = <String, String>{
      'limit': limit.toString(),
      'window': windowMinutes.toString(),
      'at': DateTime.now().toUtc().toIso8601String(),
    };
    if (stopIds != null && stopIds.isNotEmpty) {
      query['stop_ids'] = stopIds.join(',');
    }
    if (operatorFilter.isNotEmpty) {
      query['operator'] = operatorFilter;
    }

    try {
      final json = await _getJson(
        '/v1/stop-groups/${_encodeCanonicalSegment(groupId)}/departures',
        query: query,
        timeout: const Duration(seconds: 7),
      );
      lastDeparturesFromCache = false;
      unawaited(_cache.writeJson('departures', cacheKey, json));
      final list = (json['departures'] as List<dynamic>?) ?? const [];
      return list
          .map((e) => DepartureItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on ApiException catch (e) {
      if (!_isConnectivityFailure(e)) rethrow;
      var cached = await _cache.readJson('departures', cacheKey);
      // Fallback to broader unfiltered cache for the same stop group if exact filter missed.
      cached ??= await _cache.readJson('departures', '$groupId|stops=|op=');
      if (cached == null) rethrow;

      final cutoff = DateTime.now().subtract(const Duration(minutes: 2));
      final list = (cached.data['departures'] as List<dynamic>?) ?? const [];
      final items = <DepartureItem>[];
      for (final raw in list) {
        final dep = DepartureItem.fromJson(raw as Map<String, dynamic>);
        if (stopIds != null && stopIds.isNotEmpty && !stopIds.contains(dep.stopId)) {
          continue;
        }
        if (operatorFilter.isNotEmpty && dep.operatorId != operatorFilter) {
          continue;
        }
        if (dep.scheduledTime.isAfter(cutoff)) {
          items.add(dep.asOfflineScheduled());
        }
      }
      items.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
      lastDeparturesFromCache = true;
      return items.take(limit).toList();
    }
  }

  Future<List<RouteSummary>> fetchRoutes({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedRoutes != null) {
      return _cachedRoutes!;
    }
    final json = await _fetchStaticJson(
      namespace: 'catalog',
      key: 'routes_all',
      path: '/v1/routes',
      forceRefresh: forceRefresh,
    );
    final list = (json['routes'] as List<dynamic>?) ?? const [];
    final parsed = list
        .map((e) => RouteSummary.fromJson(e as Map<String, dynamic>))
        .toList();
    _cachedRoutes = parsed;
    return parsed;
  }

  Future<RouteTimetableResponse> fetchRouteTimetable(
    String routeId, {
    int? directionId,
    String? stopId,
    bool forceRefresh = false,
  }) async {
    final query = <String, String>{};
    if (directionId != null) {
      query['direction_id'] = directionId.toString();
    }
    if (stopId != null && stopId.isNotEmpty) {
      query['stop_id'] = stopId;
    }
    final key = '$routeId|dir=${directionId ?? "default"}|stop=${stopId ?? ""}';
    final json = await _fetchStaticJson(
      namespace: 'timetable',
      key: key,
      path: '/v1/routes/${_encodeCanonicalSegment(routeId)}/timetable',
      query: query,
      forceRefresh: forceRefresh,
    );
    return RouteTimetableResponse.fromJson(json);
  }

  Future<TripResponse> fetchTrip(
    String tripId, {
    String? serviceDate,
    bool includeShape = true,
  }) async {
    final query = <String, String>{
      'include_shape': includeShape.toString(),
    };
    if (serviceDate != null && serviceDate.isNotEmpty) {
      query['service_date'] = serviceDate;
    }
    final cacheKey = '$tripId|${serviceDate ?? "today"}';
    try {
      final json = await _getJson(
        '/v1/trips/${_encodeCanonicalSegment(tripId)}',
        query: query,
        timeout: const Duration(seconds: 7),
      );
      lastTripFromCache = false;
      unawaited(_cache.writeJson('trips', cacheKey, json));
      return TripResponse.fromJson(json);
    } on ApiException catch (e) {
      if (!_isConnectivityFailure(e)) rethrow;
      final cached = await _cache.readJson('trips', cacheKey);
      if (cached == null) rethrow;
      final sanitized = Map<String, dynamic>.from(cached.data);
      sanitized['vehicle'] = null;
      if (sanitized['trip'] is Map<String, dynamic>) {
        final t = Map<String, dynamic>.from(sanitized['trip'] as Map<String, dynamic>);
        t['has_live_location'] = false;
        sanitized['trip'] = t;
      }
      lastTripFromCache = true;
      return TripResponse.fromJson(sanitized);
    }
  }

  Future<List<LiveVehicle>> fetchVehicles({String operatorFilter = ''}) async {
    final query = <String, String>{};
    if (operatorFilter.isNotEmpty) {
      query['operator'] = operatorFilter;
    }
    final json = await _getJson(
      '/v1/vehicles',
      query: query,
      timeout: const Duration(seconds: 7),
    );
    final list = (json['vehicles'] as List<dynamic>?) ?? const [];
    return list
        .map((e) => LiveVehicle.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ServiceAlert>> fetchAlerts() async {
    try {
      final json = await _getJson(
        '/v1/alerts',
        timeout: const Duration(seconds: 7),
      );
      unawaited(_cache.writeJson('alerts', 'latest', json));
      final list = (json['alerts'] as List<dynamic>?) ?? const [];
      return list
          .map((e) => ServiceAlert.fromJson(e as Map<String, dynamic>))
          .toList();
    } on ApiException catch (e) {
      if (!_isConnectivityFailure(e)) rethrow;
      final cached = await _cache.readJson('alerts', 'latest');
      if (cached == null) rethrow;
      final list = (cached.data['alerts'] as List<dynamic>?) ?? const [];
      return list
          .map((e) => ServiceAlert.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }
}
