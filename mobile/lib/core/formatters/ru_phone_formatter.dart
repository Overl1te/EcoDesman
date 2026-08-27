import "package:flutter/services.dart";

const int _localPhoneLength = 10;

String _localDigits(String value) {
  var digits = value.replaceAll(RegExp(r"\D"), "");
  if (digits.startsWith("8") || digits.startsWith("7")) {
    digits = digits.substring(1);
  }
  if (digits.length > _localPhoneLength) {
    digits = digits.substring(0, _localPhoneLength);
  }
  return digits;
}

bool looksLikeRuPhoneInput(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return false;
  }
  if (RegExp(r"[A-Za-zА-Яа-яЁё@._]").hasMatch(trimmed)) {
    return false;
  }
  return RegExp(r"^[\d+\s()-]+$").hasMatch(trimmed);
}

String formatRuPhone(String value) {
  final local = _localDigits(value);
  if (local.isEmpty && value.trim().isEmpty) {
    return "";
  }

  final area = local.length >= 3 ? local.substring(0, 3) : local;
  final first = local.length > 3
      ? local.substring(3, local.length < 6 ? local.length : 6)
      : "";
  final second = local.length > 6
      ? local.substring(6, local.length < 8 ? local.length : 8)
      : "";
  final third = local.length > 8
      ? local.substring(8, local.length < 10 ? local.length : 10)
      : "";

  final buffer = StringBuffer("+7");
  if (area.isNotEmpty) {
    buffer.write(" ($area");
    if (area.length == 3) {
      buffer.write(")");
    }
  }
  if (first.isNotEmpty) {
    buffer.write(" $first");
  }
  if (second.isNotEmpty) {
    buffer.write("-$second");
  }
  if (third.isNotEmpty) {
    buffer.write("-$third");
  }
  return buffer.toString();
}

String? toE164RuPhone(String value) {
  final local = _localDigits(value);
  if (local.isEmpty) {
    return null;
  }
  return "+7$local";
}

String normalizeLoginIdentifier(String value) {
  final trimmed = value.trim();
  if (!looksLikeRuPhoneInput(trimmed)) {
    return trimmed;
  }
  return toE164RuPhone(trimmed) ?? trimmed;
}

class RuPhoneInputFormatter extends TextInputFormatter {
  const RuPhoneInputFormatter({this.optional = false});

  final bool optional;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (optional && !looksLikeRuPhoneInput(newValue.text) && !looksLikeRuPhoneInput(oldValue.text)) {
      return newValue;
    }

    if (optional &&
        RegExp(r"[A-Za-zА-Яа-яЁё@._]").hasMatch(newValue.text)) {
      return newValue;
    }

    final formatted = formatRuPhone(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
