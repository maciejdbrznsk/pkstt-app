import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class CachedPayload {
  const CachedPayload({
    required this.version,
    required this.savedAt,
    required this.data,
  });

  final String version;
  final DateTime savedAt;
  final Map<String, dynamic> data;
}

/// Persistent local store for schedule catalogs, stop bays, timetables, and fallback departures.
abstract interface class OfflineCacheStore {
  Future<String?> readActiveStaticVersion();
  Future<void> writeActiveStaticVersion(String version);
  Future<CachedPayload?> readJson(String namespace, String key);
  Future<void> writeJson(
    String namespace,
    String key,
    Map<String, dynamic> data, {
    String version = '',
  });
  Future<int> totalBytes();
  Future<void> clearAll();
}

/// Gzip-compressed disk cache stored inside persistent Application Support storage.
class DiskOfflineCacheStore implements OfflineCacheStore {
  DiskOfflineCacheStore(this.rootDir);

  final Directory rootDir;
  String? _cachedVersion;

  static Future<DiskOfflineCacheStore> createDefault() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'pkstt_cache'));
    await dir.create(recursive: true);
    return DiskOfflineCacheStore(dir);
  }

  File get _versionFile => File(p.join(rootDir.path, 'static_version.txt'));

  File _entryFile(String namespace, String key) {
    final nsDir = p.join(rootDir.path, _sanitizeSegment(namespace));
    return File(p.join(nsDir, '${_hashKey(key)}.json.gz'));
  }

  @override
  Future<String?> readActiveStaticVersion() async {
    if (_cachedVersion != null) return _cachedVersion;
    try {
      if (!await _versionFile.exists()) return null;
      final v = (await _versionFile.readAsString()).trim();
      _cachedVersion = v.isEmpty ? null : v;
      return _cachedVersion;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeActiveStaticVersion(String version) async {
    _cachedVersion = version;
    try {
      await rootDir.create(recursive: true);
      await _versionFile.writeAsString(version, flush: true);
    } catch (_) {}
  }

  @override
  Future<CachedPayload?> readJson(String namespace, String key) async {
    final file = _entryFile(namespace, key);
    try {
      if (!await file.exists()) return null;
      final compressed = await file.readAsBytes();
      final decoded = utf8.decode(gzip.decode(compressed));
      final envelope = jsonDecode(decoded);
      if (envelope is! Map<String, dynamic>) return null;
      final payload = envelope['data'];
      if (payload is! Map<String, dynamic>) return null;
      final version = (envelope['v'] as String?) ?? '';
      final tsRaw = envelope['ts'] as String?;
      final savedAt = tsRaw != null
          ? DateTime.tryParse(tsRaw)?.toLocal() ?? DateTime.now()
          : DateTime.now();
      return CachedPayload(version: version, savedAt: savedAt, data: payload);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeJson(
    String namespace,
    String key,
    Map<String, dynamic> data, {
    String version = '',
  }) async {
    final file = _entryFile(namespace, key);
    try {
      await file.parent.create(recursive: true);
      final envelope = {
        'v': version,
        'ts': DateTime.now().toUtc().toIso8601String(),
        'data': data,
      };
      final gzBytes = gzip.encode(utf8.encode(jsonEncode(envelope)));
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsBytes(gzBytes, flush: true);
      if (await file.exists()) {
        await file.delete();
      }
      await tmp.rename(file.path);
    } catch (_) {}
  }

  @override
  Future<int> totalBytes() async {
    try {
      if (!await rootDir.exists()) return 0;
      var sum = 0;
      await for (final entity in rootDir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          sum += await entity.length();
        }
      }
      return sum;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<void> clearAll() async {
    _cachedVersion = null;
    try {
      if (await rootDir.exists()) {
        await rootDir.delete(recursive: true);
      }
      await rootDir.create(recursive: true);
    } catch (_) {}
  }

  static String _sanitizeSegment(String input) =>
      input.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

  static String _hashKey(String key) {
    // 128-bit dual FNV-1a hex digest: fast, collision-safe, cross-platform filename.
    var h1 = 0xcbf29ce484222325;
    var h2 = 0x84222325cbf29ce4;
    final bytes = utf8.encode(key);
    for (var i = 0; i < bytes.length; i++) {
      h1 ^= bytes[i];
      h1 = (h1 * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
      h2 ^= bytes[bytes.length - 1 - i];
      h2 = (h2 * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return '${h1.toRadixString(16).padLeft(16, '0')}${h2.toRadixString(16).padLeft(16, '0')}';
  }
}

/// Fast in-memory cache store used in unit/widget tests or web fallback.
class InMemoryOfflineCacheStore implements OfflineCacheStore {
  String? _version;
  final Map<String, CachedPayload> _entries = {};

  @override
  Future<String?> readActiveStaticVersion() async => _version;

  @override
  Future<void> writeActiveStaticVersion(String version) async {
    _version = version;
  }

  @override
  Future<CachedPayload?> readJson(String namespace, String key) async =>
      _entries['$namespace::$key'];

  @override
  Future<void> writeJson(
    String namespace,
    String key,
    Map<String, dynamic> data, {
    String version = '',
  }) async {
    _entries['$namespace::$key'] = CachedPayload(
      version: version,
      savedAt: DateTime.now(),
      data: data,
    );
  }

  @override
  Future<int> totalBytes() async => _entries.length * 1024;

  @override
  Future<void> clearAll() async {
    _version = null;
    _entries.clear();
  }
}
