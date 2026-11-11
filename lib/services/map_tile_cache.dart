import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Persistent OpenStreetMap tile cache service stored in Application Support.
/// Serves already-visited areas offline and reduces repeated tile server traffic.
class MapTileCache {
  MapTileCache._();

  static final http.Client _sharedTileClient = RetryClient(http.Client());
  static Directory? _tileDir;
  static BuiltInMapCachingProvider? _builtInCaching;
  static bool Function()? _offlineChecker;

  static Future<void> init({bool Function()? isOffline}) async {
    _offlineChecker = isOffline;
    try {
      final support = await getApplicationSupportDirectory();
      final dir = Directory(p.join(support.path, 'pkstt_map_tiles'));
      await dir.create(recursive: true);
      _tileDir = dir;
      _builtInCaching = BuiltInMapCachingProvider.getOrCreateInstance(
        cacheDirectory: dir.path,
        maxCacheSize: 250 * 1024 * 1024, // 250 MB cap
        overrideFreshAge: const Duration(days: 30),
      );
    } catch (_) {
      _builtInCaching = null;
    }
  }

  static void attachOfflineChecker(bool Function() isOffline) {
    _offlineChecker = isOffline;
  }

  /// Creates a lightweight TileProvider backed by the shared persistent cache
  /// and external long-lived HTTP client (safe when TileLayer disposes).
  static TileProvider createTileProvider() {
    final baseCache = _builtInCaching;
    return NetworkTileProvider(
      httpClient: _sharedTileClient,
      silenceExceptions: true,
      headers: <String, String>{
        'User-Agent': 'pkstt/1.0 (pl.maciejdbrznsk.pkstt)',
      },
      cachingProvider: baseCache != null
          ? _OfflineResilientMapCachingProvider(
              baseCache,
              isOffline: () => _offlineChecker?.call() ?? false,
            )
          : const DisabledMapCachingProvider(),
    );
  }

  static Future<int> totalBytes() async {
    final dir = _tileDir;
    if (dir == null) return 0;
    try {
      if (!await dir.exists()) return 0;
      var sum = 0;
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          sum += await entity.length();
        }
      }
      return sum;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> clearCache() async {
    final current = _builtInCaching;
    final dir = _tileDir;
    if (current != null) {
      await current.destroy(deleteCache: true);
      _builtInCaching = null;
    } else if (dir != null && await dir.exists()) {
      await dir.delete(recursive: true);
    }
    if (dir != null) {
      await dir.create(recursive: true);
      _builtInCaching = BuiltInMapCachingProvider.getOrCreateInstance(
        cacheDirectory: dir.path,
        maxCacheSize: 250 * 1024 * 1024,
        overrideFreshAge: const Duration(days: 30),
      );
    }
  }
}

/// Wraps [BuiltInMapCachingProvider] so tiles older than 30 days are still served
/// seamlessly whenever the device is offline.
class _OfflineResilientMapCachingProvider implements MapCachingProvider {
  const _OfflineResilientMapCachingProvider(
    this._inner, {
    required this.isOffline,
  });

  final BuiltInMapCachingProvider _inner;
  final bool Function() isOffline;

  @override
  bool get isSupported => _inner.isSupported;

  @override
  Future<CachedMapTile?> getTile(String url) async {
    final cached = await _inner.getTile(url);
    if (cached == null) return null;
    if (cached.metadata.isStale && isOffline()) {
      return (
        bytes: cached.bytes,
        metadata: CachedMapTileMetadata(
          staleAt: DateTime.timestamp().add(const Duration(days: 1)),
          lastModified: cached.metadata.lastModified,
          etag: cached.metadata.etag,
        ),
      );
    }
    return cached;
  }

  @override
  Future<void> putTile({
    required String url,
    required CachedMapTileMetadata metadata,
    Uint8List? bytes,
  }) {
    return _inner.putTile(url: url, metadata: metadata, bytes: bytes);
  }
}
