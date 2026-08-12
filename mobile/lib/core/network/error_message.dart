import "package:dio/dio.dart";

String _localizeServerMessage(String message) {
  return message
      .replaceAll("username", "логин")
      .replaceAll("email", "электронную почту")
      .replaceAll("file is required", "Нужно выбрать файл")
      .replaceAll(
        "unsupported file type",
        "Поддерживаются только JPG, PNG и WEBP",
      )
      .replaceAll(
        "event_starts_at is required for events",
        "Укажите дату и время начала события",
      )
      .replaceAll(
        "event_date is required for events",
        "Укажите дату мероприятия",
      )
      .replaceAll(
        "event_ends_at must be after event_starts_at",
        "Дата окончания события должна быть позже даты начала",
      )
      .replaceAll(
        "event_location is required for events",
        "Укажите место проведения события",
      )
      .replaceAll(
        "Only event posts can be cancelled",
        "Отменять можно только посты с типом мероприятия",
      );
}

String? _extractValidationMessage(dynamic data) {
  if (data is String && data.trim().isNotEmpty) {
    return data.trim();
  }

  if (data is List) {
    for (final item in data) {
      final message = _extractValidationMessage(item);
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }
    return null;
  }

  if (data is Map) {
    if (data["detail"] is String &&
        (data["detail"] as String).trim().isNotEmpty) {
      return _localizeServerMessage((data["detail"] as String).trim());
    }

    for (final key in [
      "non_field_errors",
      "current_password",
      "new_password",
      "password",
      "email",
      "username",
      "phone",
      "event_date",
      "event_starts_at",
      "event_ends_at",
      "event_location",
    ]) {
      final message = _extractValidationMessage(data[key]);
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }

    for (final entry in data.entries) {
      final message = _extractValidationMessage(entry.value);
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }
  }

  return null;
}

String humanizeNetworkError(Object error, {required String fallback}) {
  if (error is DioException) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;
    final detailMessage = _extractValidationMessage(data);

    if (detailMessage != null) {
      return _localizeServerMessage(detailMessage);
    }

    if (statusCode == 401) {
      return "Неверный логин или пароль";
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError) {
      return "Проверьте подключение к интернету";
    }
  }

  return fallback;
}
