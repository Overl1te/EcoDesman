import "package:intl/intl.dart";

final _postDateFormat = DateFormat("d MMMM, HH:mm", "ru_RU");
final _eventDateFormat = DateFormat("d MMMM, HH:mm", "ru_RU");
final _eventDayFormat = DateFormat("d MMMM yyyy", "ru_RU");
final _eventTimeFormat = DateFormat("HH:mm", "ru_RU");
final _calendarHeaderFormat = DateFormat("LLLL yyyy", "ru_RU");
final _calendarDayLabelFormat = DateFormat("EEEE, d MMMM", "ru_RU");

String formatPostDate(DateTime value) {
  return _postDateFormat.format(value);
}

String formatEventDay(DateTime? value) {
  if (value == null) {
    return "Дата не указана";
  }
  return _eventDayFormat.format(value);
}

String formatEventTime(DateTime? value) {
  if (value == null) {
    return "Время не указано";
  }
  return _eventTimeFormat.format(value);
}

String formatCalendarHeader(DateTime value) {
  final formatted = _calendarHeaderFormat.format(value);
  if (formatted.isEmpty) {
    return "";
  }
  return "${formatted[0].toUpperCase()}${formatted.substring(1)}";
}

String formatCalendarDayLabel(DateTime value) {
  final formatted = _calendarDayLabelFormat.format(value);
  if (formatted.isEmpty) {
    return "";
  }
  return "${formatted[0].toUpperCase()}${formatted.substring(1)}";
}

String formatEventRange(DateTime? start, DateTime? end) {
  if (start == null) {
    return "Дата уточняется";
  }
  if (end == null || end.isAtSameMomentAs(start)) {
    return _eventDateFormat.format(start);
  }
  return "${_eventDateFormat.format(start)} - ${_eventDateFormat.format(end)}";
}
