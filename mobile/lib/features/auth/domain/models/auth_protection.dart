class AuthProtectionConfig {
  const AuthProtectionConfig({
    required this.turnstileEnabled,
    required this.turnstileSiteKey,
    required this.phoneVerificationEnabled,
  });

  factory AuthProtectionConfig.disabled() {
    return const AuthProtectionConfig(
      turnstileEnabled: false,
      turnstileSiteKey: "",
      phoneVerificationEnabled: false,
    );
  }

  factory AuthProtectionConfig.fromJson(Map<String, dynamic> json) {
    final turnstile = Map<String, dynamic>.from(json["turnstile"] as Map? ?? {});
    final phone = Map<String, dynamic>.from(
      json["phone_verification"] as Map? ?? {},
    );
    return AuthProtectionConfig(
      turnstileEnabled: turnstile["enabled"] == true,
      turnstileSiteKey: (turnstile["site_key"] as String?) ?? "",
      phoneVerificationEnabled: phone["enabled"] == true,
    );
  }

  final bool turnstileEnabled;
  final String turnstileSiteKey;
  final bool phoneVerificationEnabled;

  bool get hasTurnstile => turnstileEnabled && turnstileSiteKey.isNotEmpty;
}

class PhoneChallenge {
  const PhoneChallenge({
    required this.challengeId,
    required this.phone,
    required this.channel,
    required this.detail,
    required this.codeLength,
    required this.canTryNextChannel,
    required this.verified,
    required this.needsCode,
    required this.receiveNumber,
  });

  factory PhoneChallenge.fromJson(Map<String, dynamic> json) {
    return PhoneChallenge(
      challengeId: json["challenge_id"] as String,
      phone: json["phone"] as String? ?? "",
      channel: json["channel"] as String? ?? "telegram",
      detail: json["detail"] as String? ?? "Код подтверждения отправлен.",
      codeLength: json["code_length"] as int? ?? 4,
      canTryNextChannel: json["can_try_next_channel"] == true,
      verified: json["verified"] == true,
      needsCode: json["needs_code"] != false,
      receiveNumber: json["receive_number"] as String? ?? "",
    );
  }

  final String challengeId;
  final String phone;
  final String channel;
  final String detail;
  final int codeLength;
  final bool canTryNextChannel;
  final bool verified;
  final bool needsCode;
  final String receiveNumber;

  bool get isCall => channel == "call";
  bool get isReceive => channel == "receive";
}

class PhoneConfirmationRequired implements Exception {
  const PhoneConfirmationRequired(this.challenge);

  final PhoneChallenge challenge;
}
