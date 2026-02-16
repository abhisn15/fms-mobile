class DailyShift {
  final String id;
  final String name;
  final String code;
  final String startTime;
  final String endTime;
  final String? color;
  final bool isWfh;
  final ShiftPattern? pattern;
  /// workday | off — untuk filter monitoring: hanya tampilkan yang workday
  final String? dayType;

  DailyShift({
    required this.id,
    required this.name,
    required this.code,
    required this.startTime,
    required this.endTime,
    this.color,
    this.isWfh = false,
    this.pattern,
    this.dayType,
  });

  bool get isOff {
    final v = dayType;
    if (v == null) return false;
    try {
      return v.toString().toLowerCase() == 'off';
    } catch (_) {
      return false;
    }
  }

  factory DailyShift.fromJson(Map<String, dynamic> json) {
    Object? rawDayType = json['dayType'];
    String? dayType;
    if (rawDayType is String) {
      dayType = rawDayType;
    } else if (rawDayType != null) {
      dayType = rawDayType.toString();
    }
    return DailyShift(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      startTime: json['startTime'] as String? ?? '08:00',
      endTime: json['endTime'] as String? ?? '17:00',
      color: json['color'] as String?,
      isWfh: json['isWfh'] as bool? ?? false,
      pattern: json['pattern'] != null
          ? ShiftPattern.fromJson(json['pattern'] as Map<String, dynamic>)
          : null,
      dayType: dayType,
    );
  }
}

class ShiftPattern {
  final String id;
  final String name;
  final String? description;

  ShiftPattern({
    required this.id,
    required this.name,
    this.description,
  });

  factory ShiftPattern.fromJson(Map<String, dynamic> json) {
    return ShiftPattern(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
    );
  }
}

class ShiftSchedulePayload {
  final List<DailyShift> today;
  final List<DailyShift> upcoming;
  final bool? blocked;
  final String? blockedType;
  final String? blockedMessage;

  ShiftSchedulePayload({
    required this.today,
    required this.upcoming,
    this.blocked = false,
    this.blockedType,
    this.blockedMessage,
  });

  factory ShiftSchedulePayload.fromJson(Map<String, dynamic> json) {
    final todayRaw = json['today'];
    List<DailyShift> parsedToday = [];

    if (todayRaw is List<dynamic>) {
      parsedToday = todayRaw
          .where((e) => e is Map<String, dynamic>)
          .map((e) => DailyShift.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (todayRaw is Map<String, dynamic>) {
      parsedToday = [DailyShift.fromJson(todayRaw)];
    } else if (todayRaw is Map) {
      parsedToday = [DailyShift.fromJson(Map<String, dynamic>.from(todayRaw))];
    }

    final upcomingRaw = json['upcoming'];
    final parsedUpcoming = (upcomingRaw is List<dynamic>)
        ? upcomingRaw
            .where((e) => e is Map<String, dynamic>)
            .map((e) => DailyShift.fromJson(e as Map<String, dynamic>))
            .toList()
        : <DailyShift>[];

    return ShiftSchedulePayload(
      today: parsedToday,
      upcoming: parsedUpcoming,
      blocked: json['blocked'] == true,
      blockedType: json['blockedType'] as String?,
      blockedMessage: json['blockedMessage'] as String?,
    );
  }
}
