import "event_calendar_entry.dart";

class EventCalendarMonth {
  const EventCalendarMonth({
    required this.year,
    required this.month,
    required this.startsOn,
    required this.endsOn,
    required this.events,
  });

  final int year;
  final int month;
  final DateTime startsOn;
  final DateTime endsOn;
  final List<EventCalendarEntry> events;

  factory EventCalendarMonth.fromJson(Map<String, dynamic> json) {
    return EventCalendarMonth(
      year: json["year"] as int,
      month: json["month"] as int,
      startsOn: DateTime.parse(json["starts_on"] as String),
      endsOn: DateTime.parse(json["ends_on"] as String),
      events: (json["events"] as List<dynamic>? ?? [])
          .map(
            (item) => EventCalendarEntry.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}
