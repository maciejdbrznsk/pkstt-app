/// Immutable API models mapping pkstt-backend JSON responses cleanly.
library;

class SampleDirection {
  const SampleDirection({
    required this.operatorId,
    required this.routeId,
    required this.routeShortName,
    required this.routeColor,
    required this.headsign,
    required this.tripCount,
  });

  final String operatorId;
  final String routeId;
  final String routeShortName;
  final String routeColor;
  final String headsign;
  final int tripCount;

  factory SampleDirection.fromJson(Map<String, dynamic> json) {
    return SampleDirection(
      operatorId: (json['operator'] ?? '') as String,
      routeId: (json['route_id'] ?? '') as String,
      routeShortName: (json['route_short_name'] ?? '') as String,
      routeColor: (json['route_color'] ?? '') as String,
      headsign: (json['headsign'] ?? '') as String,
      tripCount: (json['trip_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class StopPlatform {
  const StopPlatform({
    required this.id,
    required this.operatorId,
    required this.name,
    required this.code,
    required this.platformCode,
    required this.isOnDemand,
    required this.lat,
    required this.lon,
    required this.sampleDirections,
  });

  final String id;
  final String operatorId;
  final String name;
  final String code;
  final String platformCode;
  final bool isOnDemand;
  final double lat;
  final double lon;
  final List<SampleDirection> sampleDirections;

  factory StopPlatform.fromJson(Map<String, dynamic> json) {
    final rawDirs = (json['sample_directions'] as List<dynamic>?) ?? const [];
    return StopPlatform(
      id: (json['id'] ?? '') as String,
      operatorId: (json['operator'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      code: (json['code'] ?? '') as String,
      platformCode: (json['platform_code'] ?? '') as String,
      isOnDemand: (json['is_on_demand'] as bool?) ?? false,
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lon: (json['lon'] as num?)?.toDouble() ?? 0,
      sampleDirections: rawDirs
          .map((e) => SampleDirection.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class StopBay {
  const StopBay({
    required this.bayId,
    required this.label,
    required this.platformCode,
    required this.operators,
    required this.stopIds,
    required this.isOnDemand,
    required this.lat,
    required this.lon,
    required this.sampleDirections,
  });

  final String bayId;
  final String label;
  final String platformCode;
  final List<String> operators;
  final List<String> stopIds;
  final bool isOnDemand;
  final double lat;
  final double lon;
  final List<SampleDirection> sampleDirections;

  factory StopBay.fromJson(Map<String, dynamic> json) {
    return StopBay(
      bayId: (json['bay_id'] ?? '') as String,
      label: (json['label'] ?? '') as String,
      platformCode: (json['platform_code'] ?? '') as String,
      operators: ((json['operators'] as List<dynamic>?) ?? const [])
          .cast<String>(),
      stopIds: ((json['stop_ids'] as List<dynamic>?) ?? const [])
          .cast<String>(),
      isOnDemand: (json['is_on_demand'] as bool?) ?? false,
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lon: (json['lon'] as num?)?.toDouble() ?? 0,
      sampleDirections: ((json['sample_directions'] as List<dynamic>?) ?? const [])
          .map((e) => SampleDirection.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class StopGroup {
  const StopGroup({
    required this.groupId,
    required this.name,
    required this.operators,
    required this.lat,
    required this.lon,
    required this.stopCount,
    required this.platforms,
    this.distanceMeters,
  });

  final String groupId;
  final String name;
  final List<String> operators;
  final double lat;
  final double lon;
  final int stopCount;
  final double? distanceMeters;
  final List<StopPlatform> platforms;

  factory StopGroup.fromJson(Map<String, dynamic> json) {
    return StopGroup(
      groupId: (json['group_id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      operators: ((json['operators'] as List<dynamic>?) ?? const [])
          .cast<String>(),
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lon: (json['lon'] as num?)?.toDouble() ?? 0,
      stopCount: (json['stop_count'] as num?)?.toInt() ?? 0,
      distanceMeters: (json['distance_m'] as num?)?.toDouble(),
      platforms: ((json['platforms'] as List<dynamic>?) ?? const [])
          .map((e) => StopPlatform.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class StopGroupDetail {
  const StopGroupDetail({
    required this.group,
    required this.bays,
  });

  final StopGroup group;
  final List<StopBay> bays;

  factory StopGroupDetail.fromJson(Map<String, dynamic> json) {
    final group = StopGroup.fromJson(json['stop_group'] as Map<String, dynamic>);
    final bays = ((json['bays'] as List<dynamic>?) ?? const [])
        .map((e) => StopBay.fromJson(e as Map<String, dynamic>))
        .toList();
    return StopGroupDetail(group: group, bays: bays);
  }
}

class DepartureItem {
  const DepartureItem({
    required this.operatorId,
    required this.stopId,
    required this.stopName,
    required this.platformCode,
    required this.routeId,
    required this.routeShortName,
    required this.routeColor,
    required this.routeTextColor,
    required this.tripId,
    required this.serviceDate,
    required this.headsign,
    required this.brigade,
    required this.wheelchairAccessible,
    required this.scheduledDeparture,
    required this.scheduledTime,
    required this.estimatedTime,
    required this.delaySeconds,
    required this.isRealtime,
    required this.hasLiveLocation,
    required this.canceled,
    required this.skipped,
    required this.vehicleId,
  });

  final String operatorId;
  final String stopId;
  final String stopName;
  final String platformCode;
  final String routeId;
  final String routeShortName;
  final String routeColor;
  final String routeTextColor;
  final String tripId;
  final String serviceDate;
  final String headsign;
  final String brigade;
  final bool wheelchairAccessible;
  final String scheduledDeparture;
  final DateTime scheduledTime;
  final DateTime estimatedTime;
  final int? delaySeconds;
  final bool isRealtime;
  final bool hasLiveLocation;
  final bool canceled;
  final bool skipped;
  final String vehicleId;

  factory DepartureItem.fromJson(Map<String, dynamic> json) {
    return DepartureItem(
      operatorId: (json['operator'] ?? '') as String,
      stopId: (json['stop_id'] ?? '') as String,
      stopName: (json['stop_name'] ?? '') as String,
      platformCode: (json['platform_code'] ?? '') as String,
      routeId: (json['route_id'] ?? '') as String,
      routeShortName: (json['route_short_name'] ?? '') as String,
      routeColor: (json['route_color'] ?? '') as String,
      routeTextColor: (json['route_text_color'] ?? '') as String,
      tripId: (json['trip_id'] ?? '') as String,
      serviceDate: (json['service_date'] ?? '') as String,
      headsign: (json['headsign'] ?? '') as String,
      brigade: (json['brigade'] ?? '') as String,
      wheelchairAccessible: (json['wheelchair_accessible'] as bool?) ?? false,
      scheduledDeparture: (json['scheduled_departure'] ?? '') as String,
      scheduledTime: DateTime.parse(json['scheduled_time'] as String).toLocal(),
      estimatedTime: DateTime.parse(json['estimated_time'] as String).toLocal(),
      delaySeconds: (json['delay_seconds'] as num?)?.toInt(),
      isRealtime: (json['is_realtime'] as bool?) ?? false,
      hasLiveLocation: (json['has_live_location'] as bool?) ?? false,
      canceled: (json['canceled'] as bool?) ?? false,
      skipped: (json['skipped'] as bool?) ?? false,
      vehicleId: (json['vehicle_id'] ?? '') as String,
    );
  }

  DepartureItem asOfflineScheduled() {
    return DepartureItem(
      operatorId: operatorId,
      stopId: stopId,
      stopName: stopName,
      platformCode: platformCode,
      routeId: routeId,
      routeShortName: routeShortName,
      routeColor: routeColor,
      routeTextColor: routeTextColor,
      tripId: tripId,
      serviceDate: serviceDate,
      headsign: headsign,
      brigade: brigade,
      wheelchairAccessible: wheelchairAccessible,
      scheduledDeparture: scheduledDeparture,
      scheduledTime: scheduledTime,
      estimatedTime: scheduledTime,
      delaySeconds: null,
      isRealtime: false,
      hasLiveLocation: false,
      canceled: canceled,
      skipped: skipped,
      vehicleId: '',
    );
  }
}

class RouteSummary {
  const RouteSummary({
    required this.id,
    required this.operatorId,
    required this.shortName,
    required this.longName,
    required this.routeType,
    required this.color,
    required this.textColor,
  });

  final String id;
  final String operatorId;
  final String shortName;
  final String longName;
  final int routeType;
  final String color;
  final String textColor;

  factory RouteSummary.fromJson(Map<String, dynamic> json) {
    return RouteSummary(
      id: (json['id'] ?? '') as String,
      operatorId: (json['operator'] ?? '') as String,
      shortName: (json['short_name'] ?? '') as String,
      longName: (json['long_name'] ?? '') as String,
      routeType: (json['route_type'] as num?)?.toInt() ?? 3,
      color: (json['color'] ?? '') as String,
      textColor: (json['text_color'] ?? '') as String,
    );
  }
}

class RouteDirection {
  const RouteDirection({
    required this.directionId,
    required this.headsign,
    required this.variantHeadsigns,
    required this.tripCount,
  });

  final int directionId;
  final String headsign;
  final List<String> variantHeadsigns;
  final int tripCount;

  factory RouteDirection.fromJson(Map<String, dynamic> json) {
    return RouteDirection(
      directionId: (json['direction_id'] as num?)?.toInt() ?? 0,
      headsign: (json['headsign'] ?? '') as String,
      variantHeadsigns: ((json['variant_headsigns'] as List<dynamic>?) ?? const [])
          .cast<String>(),
      tripCount: (json['trip_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class TimetableRouteStop {
  const TimetableRouteStop({
    required this.stopSequence,
    required this.stopId,
    required this.groupId,
    required this.name,
    required this.platformCode,
    required this.isOnDemand,
    required this.isTerminus,
    required this.lat,
    required this.lon,
  });

  final int stopSequence;
  final String stopId;
  final String groupId;
  final String name;
  final String platformCode;
  final bool isOnDemand;
  final bool isTerminus;
  final double lat;
  final double lon;

  factory TimetableRouteStop.fromJson(Map<String, dynamic> json) {
    return TimetableRouteStop(
      stopSequence: (json['stop_sequence'] as num?)?.toInt() ?? 0,
      stopId: (json['stop_id'] ?? '') as String,
      groupId: (json['group_id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      platformCode: (json['platform_code'] ?? '') as String,
      isOnDemand: (json['is_on_demand'] as bool?) ?? false,
      isTerminus: (json['is_terminus'] as bool?) ?? false,
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lon: (json['lon'] as num?)?.toDouble() ?? 0,
    );
  }
}

class TimetableEntry {
  const TimetableEntry({
    required this.tripId,
    required this.hour,
    required this.displayHour,
    required this.minute,
    required this.time,
    required this.variantCode,
    required this.headsign,
    required this.wheelchairAccessible,
  });

  final String tripId;
  final int hour;
  final int displayHour;
  final int minute;
  final String time;
  final String variantCode;
  final String headsign;
  final bool wheelchairAccessible;

  factory TimetableEntry.fromJson(Map<String, dynamic> json) {
    return TimetableEntry(
      tripId: (json['trip_id'] ?? '') as String,
      hour: (json['hour'] as num?)?.toInt() ?? 0,
      displayHour: (json['display_hour'] as num?)?.toInt() ?? 0,
      minute: (json['minute'] as num?)?.toInt() ?? 0,
      time: (json['time'] ?? '') as String,
      variantCode: (json['variant_code'] ?? '') as String,
      headsign: (json['headsign'] ?? '') as String,
      wheelchairAccessible: (json['wheelchair_accessible'] as bool?) ?? false,
    );
  }
}

class TimetableHourRow {
  const TimetableHourRow({
    required this.hour,
    required this.displayHour,
    required this.departures,
  });

  final int hour;
  final int displayHour;
  final List<TimetableEntry> departures;

  factory TimetableHourRow.fromJson(Map<String, dynamic> json) {
    return TimetableHourRow(
      hour: (json['hour'] as num?)?.toInt() ?? 0,
      displayHour: (json['display_hour'] as num?)?.toInt() ?? 0,
      departures: ((json['departures'] as List<dynamic>?) ?? const [])
          .map((e) => TimetableEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TimetableDay {
  const TimetableDay({
    required this.serviceId,
    required this.label,
    required this.shortLabel,
    required this.activeToday,
    required this.hours,
  });

  final String serviceId;
  final String label;
  final String shortLabel;
  final bool activeToday;
  final List<TimetableHourRow> hours;

  factory TimetableDay.fromJson(Map<String, dynamic> json) {
    return TimetableDay(
      serviceId: (json['service_id'] ?? '') as String,
      label: (json['label'] ?? '') as String,
      shortLabel: (json['short_label'] ?? '') as String,
      activeToday: (json['active_today'] as bool?) ?? false,
      hours: ((json['hours'] as List<dynamic>?) ?? const [])
          .map((e) => TimetableHourRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TimetableLegendItem {
  const TimetableLegendItem({
    required this.code,
    required this.description,
  });

  final String code;
  final String description;

  factory TimetableLegendItem.fromJson(Map<String, dynamic> json) {
    return TimetableLegendItem(
      code: (json['code'] ?? '') as String,
      description: (json['description'] ?? '') as String,
    );
  }
}

class RouteTimetableResponse {
  const RouteTimetableResponse({
    required this.route,
    required this.directions,
    required this.selectedDirectionId,
    required this.stops,
    required this.selectedStop,
    required this.activeServiceIds,
    required this.dayTypes,
    required this.legend,
  });

  final RouteSummary route;
  final List<RouteDirection> directions;
  final int selectedDirectionId;
  final List<TimetableRouteStop> stops;
  final TimetableRouteStop? selectedStop;
  final List<String> activeServiceIds;
  final List<TimetableDay> dayTypes;
  final List<TimetableLegendItem> legend;

  factory RouteTimetableResponse.fromJson(Map<String, dynamic> json) {
    return RouteTimetableResponse(
      route: RouteSummary.fromJson(json['route'] as Map<String, dynamic>),
      directions: ((json['directions'] as List<dynamic>?) ?? const [])
          .map((e) => RouteDirection.fromJson(e as Map<String, dynamic>))
          .toList(),
      selectedDirectionId: (json['selected_direction_id'] as num?)?.toInt() ?? 0,
      stops: ((json['stops'] as List<dynamic>?) ?? const [])
          .map((e) => TimetableRouteStop.fromJson(e as Map<String, dynamic>))
          .toList(),
      selectedStop: json['selected_stop'] != null
          ? TimetableRouteStop.fromJson(json['selected_stop'] as Map<String, dynamic>)
          : null,
      activeServiceIds: ((json['active_service_ids'] as List<dynamic>?) ?? const [])
          .cast<String>(),
      dayTypes: ((json['day_types'] as List<dynamic>?) ?? const [])
          .map((e) => TimetableDay.fromJson(e as Map<String, dynamic>))
          .toList(),
      legend: ((json['legend'] as List<dynamic>?) ?? const [])
          .map((e) => TimetableLegendItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class LiveVehicle {
  const LiveVehicle({
    required this.id,
    required this.operatorId,
    required this.vehicleId,
    required this.label,
    required this.licensePlate,
    required this.tripId,
    required this.routeId,
    required this.routeShortName,
    required this.routeColor,
    required this.headsign,
    required this.brigade,
    required this.directionId,
    required this.lat,
    required this.lon,
    required this.bearing,
    required this.speedMps,
    required this.currentStopSequence,
    required this.stopId,
    required this.delaySeconds,
    required this.timestamp,
  });

  final String id;
  final String operatorId;
  final String vehicleId;
  final String label;
  final String licensePlate;
  final String tripId;
  final String routeId;
  final String routeShortName;
  final String routeColor;
  final String headsign;
  final String brigade;
  final int directionId;
  final double lat;
  final double lon;
  final double? bearing;
  final double? speedMps;
  final int? currentStopSequence;
  final String stopId;
  final int? delaySeconds;
  final DateTime timestamp;

  factory LiveVehicle.fromJson(Map<String, dynamic> json) {
    return LiveVehicle(
      id: (json['id'] ?? '') as String,
      operatorId: (json['operator'] ?? '') as String,
      vehicleId: (json['vehicle_id'] ?? '') as String,
      label: (json['label'] ?? '') as String,
      licensePlate: (json['license_plate'] ?? '') as String,
      tripId: (json['trip_id'] ?? '') as String,
      routeId: (json['route_id'] ?? '') as String,
      routeShortName: (json['route_short_name'] ?? '') as String,
      routeColor: (json['route_color'] ?? '') as String,
      headsign: (json['headsign'] ?? '') as String,
      brigade: (json['brigade'] ?? '') as String,
      directionId: (json['direction_id'] as num?)?.toInt() ?? 0,
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lon: (json['lon'] as num?)?.toDouble() ?? 0,
      bearing: (json['bearing'] as num?)?.toDouble(),
      speedMps: (json['speed'] as num?)?.toDouble(),
      currentStopSequence: (json['current_stop_sequence'] as num?)?.toInt(),
      stopId: (json['stop_id'] ?? '') as String,
      delaySeconds: (json['delay_seconds'] as num?)?.toInt(),
      timestamp: DateTime.parse(json['timestamp'] as String).toLocal(),
    );
  }
}

class TripDetail {
  const TripDetail({
    required this.id,
    required this.operatorId,
    required this.routeId,
    required this.routeShortName,
    required this.routeColor,
    required this.headsign,
    required this.directionId,
    required this.brigade,
    required this.wheelchairAccessible,
    required this.shapeId,
    required this.serviceDate,
    required this.hasLiveLocation,
  });

  final String id;
  final String operatorId;
  final String routeId;
  final String routeShortName;
  final String routeColor;
  final String headsign;
  final int directionId;
  final String brigade;
  final bool wheelchairAccessible;
  final String shapeId;
  final String serviceDate;
  final bool hasLiveLocation;

  factory TripDetail.fromJson(Map<String, dynamic> json) {
    return TripDetail(
      id: (json['id'] ?? '') as String,
      operatorId: (json['operator'] ?? '') as String,
      routeId: (json['route_id'] ?? '') as String,
      routeShortName: (json['route_short_name'] ?? '') as String,
      routeColor: (json['route_color'] ?? '') as String,
      headsign: (json['headsign'] ?? '') as String,
      directionId: (json['direction_id'] as num?)?.toInt() ?? 0,
      brigade: (json['brigade'] ?? '') as String,
      wheelchairAccessible: (json['wheelchair_accessible'] as bool?) ?? false,
      shapeId: (json['shape_id'] ?? '') as String,
      serviceDate: (json['service_date'] ?? '') as String,
      hasLiveLocation: (json['has_live_location'] as bool?) ?? false,
    );
  }
}

class TripStopCall {
  const TripStopCall({
    required this.stopSequence,
    required this.stopId,
    required this.groupId,
    required this.stopName,
    required this.platformCode,
    required this.isOnDemand,
    required this.lat,
    required this.lon,
    required this.pickupType,
    required this.dropOffType,
    required this.shapeDistTraveled,
    required this.scheduledArrival,
    required this.scheduledDeparture,
    required this.scheduledArrivalTime,
    required this.scheduledDepartureTime,
    required this.estimatedArrival,
    required this.estimatedDeparture,
    required this.delaySeconds,
    required this.isRealtime,
    required this.skipped,
  });

  final int stopSequence;
  final String stopId;
  final String groupId;
  final String stopName;
  final String platformCode;
  final bool isOnDemand;
  final double lat;
  final double lon;
  final int pickupType;
  final int dropOffType;
  final double? shapeDistTraveled;
  final String scheduledArrival;
  final String scheduledDeparture;
  final DateTime scheduledArrivalTime;
  final DateTime scheduledDepartureTime;
  final DateTime estimatedArrival;
  final DateTime estimatedDeparture;
  final int? delaySeconds;
  final bool isRealtime;
  final bool skipped;

  factory TripStopCall.fromJson(Map<String, dynamic> json) {
    return TripStopCall(
      stopSequence: (json['stop_sequence'] as num?)?.toInt() ?? 0,
      stopId: (json['stop_id'] ?? '') as String,
      groupId: (json['group_id'] ?? '') as String,
      stopName: (json['stop_name'] ?? '') as String,
      platformCode: (json['platform_code'] ?? '') as String,
      isOnDemand: (json['is_on_demand'] as bool?) ?? false,
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lon: (json['lon'] as num?)?.toDouble() ?? 0,
      pickupType: (json['pickup_type'] as num?)?.toInt() ?? 0,
      dropOffType: (json['drop_off_type'] as num?)?.toInt() ?? 0,
      shapeDistTraveled: (json['shape_dist_traveled'] as num?)?.toDouble(),
      scheduledArrival: (json['scheduled_arrival'] ?? '') as String,
      scheduledDeparture: (json['scheduled_departure'] ?? '') as String,
      scheduledArrivalTime: DateTime.parse(json['scheduled_arrival_time'] as String).toLocal(),
      scheduledDepartureTime: DateTime.parse(json['scheduled_departure_time'] as String).toLocal(),
      estimatedArrival: DateTime.parse(json['estimated_arrival'] as String).toLocal(),
      estimatedDeparture: DateTime.parse(json['estimated_departure'] as String).toLocal(),
      delaySeconds: (json['delay_seconds'] as num?)?.toInt(),
      isRealtime: (json['is_realtime'] as bool?) ?? false,
      skipped: (json['skipped'] as bool?) ?? false,
    );
  }
}

class TripResponse {
  const TripResponse({
    required this.trip,
    required this.vehicle,
    required this.stops,
    required this.shape,
  });

  final TripDetail trip;
  final LiveVehicle? vehicle;
  final List<TripStopCall> stops;
  final List<(double lat, double lon)> shape;

  factory TripResponse.fromJson(Map<String, dynamic> json) {
    final rawShape = (json['shape'] as List<dynamic>?) ?? const [];
    final shapePts = <(double, double)>[];
    for (final pt in rawShape) {
      if (pt is List && pt.length >= 2) {
        shapePts.add(((pt[0] as num).toDouble(), (pt[1] as num).toDouble()));
      }
    }
    return TripResponse(
      trip: TripDetail.fromJson(json['trip'] as Map<String, dynamic>),
      vehicle: json['vehicle'] != null
          ? LiveVehicle.fromJson(json['vehicle'] as Map<String, dynamic>)
          : null,
      stops: ((json['stops'] as List<dynamic>?) ?? const [])
          .map((e) => TripStopCall.fromJson(e as Map<String, dynamic>))
          .toList(),
      shape: shapePts,
    );
  }
}

class ServiceAlert {
  const ServiceAlert({
    required this.id,
    required this.operatorId,
    required this.header,
    required this.description,
    required this.url,
  });

  final String id;
  final String operatorId;
  final String header;
  final String description;
  final String url;

  factory ServiceAlert.fromJson(Map<String, dynamic> json) {
    return ServiceAlert(
      id: (json['id'] ?? '') as String,
      operatorId: (json['operator'] ?? '') as String,
      header: (json['header'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      url: (json['url'] ?? '') as String,
    );
  }
}

class StaticFeedStatus {
  const StaticFeedStatus({
    required this.feed,
    required this.feedVersion,
    required this.startDate,
    required this.endDate,
    required this.lastUpdatedAt,
    required this.lastError,
  });

  final String feed;
  final String feedVersion;
  final String? startDate;
  final String? endDate;
  final String? lastUpdatedAt;
  final String lastError;

  factory StaticFeedStatus.fromJson(Map<String, dynamic> json) {
    return StaticFeedStatus(
      feed: (json['feed'] ?? '') as String,
      feedVersion: (json['feed_version'] ?? '') as String,
      startDate: json['feed_start_date'] as String?,
      endDate: json['feed_end_date'] as String?,
      lastUpdatedAt: json['last_updated_at'] as String?,
      lastError: (json['last_error'] ?? '') as String,
    );
  }
}

class MetaResponse {
  const MetaResponse({
    required this.timezone,
    required this.staticFeeds,
    required this.realtimeFeeds,
  });

  final String timezone;
  final List<StaticFeedStatus> staticFeeds;
  final List<RealtimeFeedStatus> realtimeFeeds;

  String get staticVersionKey {
    if (staticFeeds.isEmpty) return '';
    final sorted = [...staticFeeds]..sort((a, b) => a.feed.compareTo(b.feed));
    return sorted
        .map((f) => '${f.feed}=${f.feedVersion}|${f.lastUpdatedAt ?? ""}|${f.startDate ?? ""}-${f.endDate ?? ""}')
        .join(';');
  }

  factory MetaResponse.fromJson(Map<String, dynamic> json) {
    final sList = (json['static_feeds'] as List<dynamic>?) ?? const [];
    final rList = (json['realtime_feeds'] as List<dynamic>?) ?? const [];
    return MetaResponse(
      timezone: (json['timezone'] ?? '') as String,
      staticFeeds: sList
          .map((e) => StaticFeedStatus.fromJson(e as Map<String, dynamic>))
          .toList(),
      realtimeFeeds: rList
          .map((e) => RealtimeFeedStatus.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RealtimeFeedStatus {
  const RealtimeFeedStatus({
    required this.feed,
    required this.vehicleCount,
    required this.tripUpdateCount,
    required this.alertCount,
    required this.stale,
  });

  final String feed;
  final int vehicleCount;
  final int tripUpdateCount;
  final int alertCount;
  final bool stale;

  factory RealtimeFeedStatus.fromJson(Map<String, dynamic> json) {
    return RealtimeFeedStatus(
      feed: (json['feed'] ?? '') as String,
      vehicleCount: (json['vehicle_count'] as num?)?.toInt() ?? 0,
      tripUpdateCount: (json['trip_update_count'] as num?)?.toInt() ?? 0,
      alertCount: (json['alert_count'] as num?)?.toInt() ?? 0,
      stale: (json['stale'] as bool?) ?? true,
    );
  }
}

class FavoriteStop {
  const FavoriteStop({
    required this.key,
    required this.groupId,
    required this.title,
    required this.subtitle,
    required this.operators,
    this.bayId,
    this.stopIds = const [],
  });

  final String key;
  final String groupId;
  final String title;
  final String subtitle;
  final List<String> operators;
  final String? bayId;
  final List<String> stopIds;

  bool get isSpecificBay => stopIds.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'key': key,
        'group_id': groupId,
        'title': title,
        'subtitle': subtitle,
        'operators': operators,
        'bay_id': bayId,
        'stop_ids': stopIds,
      };

  factory FavoriteStop.fromJson(Map<String, dynamic> json) {
    return FavoriteStop(
      key: (json['key'] ?? '') as String,
      groupId: (json['group_id'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      subtitle: (json['subtitle'] ?? '') as String,
      operators: ((json['operators'] as List<dynamic>?) ?? const [])
          .cast<String>(),
      bayId: json['bay_id'] as String?,
      stopIds: ((json['stop_ids'] as List<dynamic>?) ?? const [])
          .cast<String>(),
    );
  }
}
