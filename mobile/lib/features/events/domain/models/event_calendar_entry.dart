import "../../../feed/domain/models/post_author.dart";

class EventCalendarEntry {
  const EventCalendarEntry({
    required this.id,
    required this.slug,
    required this.title,
    required this.body,
    required this.kind,
    required this.author,
    required this.eventDate,
    required this.eventStartsAt,
    required this.eventEndsAt,
    required this.eventLocation,
    required this.isEventCancelled,
    required this.eventCancelledAt,
    required this.canEdit,
  });

  final int id;
  final String slug;
  final String title;
  final String body;
  final String kind;
  final PostAuthor author;
  final DateTime? eventDate;
  final DateTime? eventStartsAt;
  final DateTime? eventEndsAt;
  final String eventLocation;
  final bool isEventCancelled;
  final DateTime? eventCancelledAt;
  final bool canEdit;

  factory EventCalendarEntry.fromJson(Map<String, dynamic> json) {
    return EventCalendarEntry(
      id: json["id"] as int,
      slug: json["slug"] as String? ?? "",
      title: json["title"] as String? ?? "",
      body: json["body"] as String? ?? "",
      kind: json["kind"] as String? ?? "",
      author: PostAuthor.fromJson(
        Map<String, dynamic>.from(json["author"] as Map),
      ),
      eventDate: _parseDateTime(json["event_date"]),
      eventStartsAt: _parseDateTime(json["event_starts_at"]),
      eventEndsAt: _parseDateTime(json["event_ends_at"]),
      eventLocation: json["event_location"] as String? ?? "",
      isEventCancelled: json["is_event_cancelled"] as bool? ?? false,
      eventCancelledAt: _parseDateTime(json["event_cancelled_at"]),
      canEdit: json["can_edit"] as bool? ?? false,
    );
  }
}

DateTime? _parseDateTime(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.parse(value);
}
