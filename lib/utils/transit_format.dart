import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import '../models/transit_models.dart';
import '../theme/one_ui_theme.dart';

const _polishMap = {
  'ą': 'a',
  'ć': 'c',
  'ę': 'e',
  'ł': 'l',
  'ń': 'n',
  'ó': 'o',
  'ś': 's',
  'ź': 'z',
  'ż': 'z',
  'Ą': 'a',
  'Ć': 'c',
  'Ę': 'e',
  'Ł': 'l',
  'Ń': 'n',
  'Ó': 'o',
  'Ś': 's',
  'Ź': 'z',
  'Ż': 'z',
};

/// Folds Polish diacritics to ASCII lowercase so search ignores accents cleanly.
String foldPolish(String input) {
  final sb = StringBuffer();
  for (final ch in input.trim().split('')) {
    sb.write(_polishMap[ch] ?? ch.toLowerCase());
  }
  return sb.toString();
}

/// Computes Haversine distance in meters between two WGS84 points.
double haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  const earthRadiusM = 6371000.0;
  final dLat = _deg2rad(lat2 - lat1);
  final dLon = _deg2rad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_deg2rad(lat1)) *
          math.cos(_deg2rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return earthRadiusM * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _deg2rad(double deg) => deg * (math.pi / 180.0);

/// Formats a meter distance concisely for Polish transit UI (`140 m`, `1.4 km`).
String formatDistanceMeters(double meters) {
  if (meters < 950) {
    return '${meters.round()} m';
  }
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

/// Formats HH:MM cleanly.
String formatClock(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// Formats remaining time until departure (`Teraz`, `za 4 min`, or `21:15`).
String formatCountdown(DateTime target, DateTime now) {
  final diffSec = target.difference(now).inSeconds;
  if (diffSec <= 45) return 'Teraz';
  final mins = (diffSec / 60).round();
  if (mins < 60) return 'za $mins min';
  return formatClock(target);
}

bool isDifferentCalendarDay(DateTime target, DateTime now) =>
    target.year != now.year || target.month != now.month || target.day != now.day;

/// Classifies PKS lines 200..299 as MKS Rzeszów, other PKS as PKS, ZTM as MPK.
String operatorDisplayLabel(String operatorId, String routeShortName) {
  if (operatorId == 'ztm') {
    if (routeShortName.toUpperCase().startsWith('N')) {
      return 'MPK · Nocna';
    }
    return 'MPK';
  }
  final n = int.tryParse(routeShortName.replaceAll(RegExp(r'[^0-9]'), ''));
  if (n != null && n >= 200 && n < 300) {
    return 'MKS';
  }
  return 'PKS';
}

bool isNightLine(String operatorId, String routeShortName) =>
    operatorId == 'ztm' && routeShortName.toUpperCase().startsWith('N');

/// Picks badge fill color distinguishing MPK/ZTM (orange), Night (dark), MKS/PKS (blue).
Color lineBadgeColor(
  OneUiPalette palette, {
  required String operatorId,
  required String shortName,
}) {
  if (isNightLine(operatorId, shortName)) return palette.nightInk;
  if (operatorId == 'ztm') return palette.ztmOrange;
  return palette.pksBlue;
}

/// Dual progress computation for mobileMPK-style "2 linie na trasie" visualization.
///
/// Indices are fractional stop offsets `[0.0 .. stops.length - 1]`.
/// `scheduledProgress` interpolates strictly on the static timetable right now;
/// `liveProgress` uses GPS coordinates projected onto adjacent stops first, then
/// `currentStopSequence`, then `estimatedArrival`/`estimatedDeparture`.
class TripTrackProgress {
  const TripTrackProgress({
    required this.scheduledProgress,
    required this.liveProgress,
    required this.hasLiveTrack,
    required this.hasGpsCoordinates,
    required this.nextScheduledIndex,
    required this.nextLiveIndex,
    required this.scheduledPosition,
  });

  final double scheduledProgress;
  final double? liveProgress;
  final bool hasLiveTrack;
  final bool hasGpsCoordinates;
  final int nextScheduledIndex;
  final int? nextLiveIndex;
  final (double lat, double lon) scheduledPosition;
}

TripTrackProgress computeTripTrackProgress(
  List<TripStopCall> stops,
  LiveVehicle? vehicle,
  DateTime now,
) {
  if (stops.isEmpty) {
    return const TripTrackProgress(
      scheduledProgress: 0,
      liveProgress: null,
      hasLiveTrack: false,
      hasGpsCoordinates: false,
      nextScheduledIndex: 0,
      nextLiveIndex: null,
      scheduledPosition: (50.0412, 21.9991),
    );
  }

  final schedProg = _interpolateTimeProgress(
    stops,
    now,
    arrivalOf: (s) => s.scheduledArrivalTime,
    departureOf: (s) => s.scheduledDepartureTime,
  );
  final schedPos = _interpolateLatLon(stops, schedProg);
  final nextSched = schedProg.ceil().clamp(0, stops.length - 1);

  double? liveProg;
  bool hasGps = false;

  if (vehicle != null && stops.length >= 2) {
    hasGps = true;
    liveProg = _projectVehicleOntoStops(stops, vehicle.lat, vehicle.lon, vehicle.currentStopSequence);
  } else if (stops.any((s) => s.isRealtime)) {
    liveProg = _interpolateTimeProgress(
      stops,
      now,
      arrivalOf: (s) => s.estimatedArrival,
      departureOf: (s) => s.estimatedDeparture,
    );
  }

  final nextLive = liveProg?.ceil().clamp(0, stops.length - 1);
  return TripTrackProgress(
    scheduledProgress: schedProg,
    liveProgress: liveProg,
    hasLiveTrack: liveProg != null,
    hasGpsCoordinates: hasGps,
    nextScheduledIndex: nextSched,
    nextLiveIndex: nextLive,
    scheduledPosition: schedPos,
  );
}

double _interpolateTimeProgress(
  List<TripStopCall> stops,
  DateTime now, {
  required DateTime Function(TripStopCall) arrivalOf,
  required DateTime Function(TripStopCall) departureOf,
}) {
  if (stops.length == 1) return 0;
  if (!now.isAfter(departureOf(stops.first))) return 0;
  if (!now.isBefore(arrivalOf(stops.last))) return (stops.length - 1).toDouble();

  for (var i = 0; i < stops.length - 1; i++) {
    final depA = departureOf(stops[i]);
    final arrB = arrivalOf(stops[i + 1]);
    if (!now.isAfter(arrB)) {
      if (!now.isAfter(depA)) {
        return i.toDouble();
      }
      final spanMs = arrB.difference(depA).inMilliseconds;
      if (spanMs <= 0) return i + 0.5;
      final elapsedMs = now.difference(depA).inMilliseconds;
      return i + (elapsedMs / spanMs).clamp(0.0, 1.0);
    }
    final depB = departureOf(stops[i + 1]);
    if (!now.isAfter(depB)) {
      return (i + 1).toDouble();
    }
  }
  return (stops.length - 1).toDouble();
}

(double, double) _interpolateLatLon(List<TripStopCall> stops, double progress) {
  final idx = progress.floor().clamp(0, stops.length - 1);
  if (idx >= stops.length - 1) {
    return (stops.last.lat, stops.last.lon);
  }
  final t = (progress - idx).clamp(0.0, 1.0);
  final a = stops[idx];
  final b = stops[idx + 1];
  return (a.lat + (b.lat - a.lat) * t, a.lon + (b.lon - a.lon) * t);
}

double _projectVehicleOntoStops(
  List<TripStopCall> stops,
  double vLat,
  double vLon,
  int? currentSeqHint,
) {
  // Approximate planar projection scaled by cos(50 deg) for orthogonal projection.
  const cosLat = 0.6428;
  var bestScore = double.infinity;
  var bestProg = 0.0;

  int hintIdx = -1;
  if (currentSeqHint != null && currentSeqHint > 0) {
    hintIdx = stops.indexWhere((s) => s.stopSequence >= currentSeqHint);
  }

  for (var i = 0; i < stops.length - 1; i++) {
    final a = stops[i];
    final b = stops[i + 1];
    final ax = a.lon * cosLat;
    final ay = a.lat;
    final bx = b.lon * cosLat;
    final by = b.lat;
    final px = vLon * cosLat;
    final py = vLat;

    final dx = bx - ax;
    final dy = by - ay;
    final lenSq = dx * dx + dy * dy;
    final t = lenSq > 1e-12
        ? (((px - ax) * dx + (py - ay) * dy) / lenSq).clamp(0.0, 1.0)
        : 0.0;
    final projLat = a.lat + (b.lat - a.lat) * t;
    final projLon = a.lon + (b.lon - a.lon) * t;
    var distM = haversineMeters(vLat, vLon, projLat, projLon);

    // Slight tie-breaker bonus toward the segment near currentStopSequence if route loops back.
    if (hintIdx >= 0) {
      final segDistIdx = (i - hintIdx).abs();
      if (segDistIdx <= 2) {
        distM *= 0.85;
      }
    }

    if (distM < bestScore) {
      bestScore = distM;
      bestProg = i + t;
    }
  }
  return bestProg.clamp(0.0, (stops.length - 1).toDouble());
}
