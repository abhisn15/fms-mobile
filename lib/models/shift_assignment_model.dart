import 'shift_model.dart';

class ShiftAssignment {
  final String id;
  final String date; // yyyy-MM-dd
  final String? ownerId;
  final String? notes;
  final DailyShift? dailyShift;
  final ShiftOwner? owner;

  ShiftAssignment({
    required this.id,
    required this.date,
    this.ownerId,
    this.notes,
    this.dailyShift,
    this.owner,
  });

  factory ShiftAssignment.fromJson(Map<String, dynamic> json) {
    final rawDate = (json['date'] ?? '').toString();
    final normalizedDate = rawDate.contains('T') ? rawDate.split('T').first : rawDate;
    final dailyShiftJson = json['dailyShift'];
    final ownerJson = json['owner'];

    return ShiftAssignment(
      id: json['id']?.toString() ?? '',
      date: normalizedDate,
      ownerId: json['ownerId']?.toString(),
      notes: json['notes']?.toString(),
      dailyShift: dailyShiftJson is Map<String, dynamic>
          ? DailyShift.fromJson(dailyShiftJson)
          : dailyShiftJson is Map
              ? DailyShift.fromJson(Map<String, dynamic>.from(dailyShiftJson))
              : null,
      owner: ownerJson is Map<String, dynamic>
          ? ShiftOwner.fromJson(ownerJson)
          : ownerJson is Map
              ? ShiftOwner.fromJson(Map<String, dynamic>.from(ownerJson))
              : null,
    );
  }
}

class ShiftOwner {
  final String id;
  final String name;
  final String? team;
  final String? title;
  final String? site;

  ShiftOwner({
    required this.id,
    required this.name,
    this.team,
    this.title,
    this.site,
  });

  factory ShiftOwner.fromJson(Map<String, dynamic> json) {
    return ShiftOwner(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '-',
      team: json['team']?.toString(),
      title: json['position']?.toString() ?? json['title']?.toString(),
      site: json['site'] is Map ? json['site']['name']?.toString() : json['site']?.toString(),
    );
  }
}
