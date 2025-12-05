class DailyShift {
  final String id;
  final String name;
  final String code;
  final String startTime;
  final String endTime;
  final String? color;
  final bool isWfh;
  final ShiftPattern? pattern;

  DailyShift({
    required this.id,
    required this.name,
    required this.code,
    required this.startTime,
    required this.endTime,
    this.color,
    this.isWfh = false,
    this.pattern,
  });

  factory DailyShift.fromJson(Map<String, dynamic> json) {
    return DailyShift(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String,
      color: json['color'] as String?,
      isWfh: json['isWfh'] as bool? ?? false,
      pattern: json['pattern'] != null
          ? ShiftPattern.fromJson(json['pattern'] as Map<String, dynamic>)
          : null,
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
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
    );
  }
}

class ShiftSchedulePayload {
  final DailyShift? today;
  final List<DailyShift> upcoming;

  ShiftSchedulePayload({
    this.today,
    required this.upcoming,
  });

  factory ShiftSchedulePayload.fromJson(Map<String, dynamic> json) {
    return ShiftSchedulePayload(
      today: json['today'] != null
          ? DailyShift.fromJson(json['today'] as Map<String, dynamic>)
          : null,
      upcoming: (json['upcoming'] as List<dynamic>?)
              ?.map((e) => DailyShift.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

