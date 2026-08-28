class AuthProtectionConfig {
  const AuthProtectionConfig({
    required this.turnstileEnabled,
    required this.turnstileSiteKey,
    required this.phoneVerificationEnabled,
    this.authChannels = const [],
  });

  factory AuthProtectionConfig.disabled() {
    return const AuthProtectionConfig(
      turnstileEnabled: false,
      turnstileSiteKey: "",
      phoneVerificationEnabled: false,
      authChannels: [],
    );
  }

  factory AuthProtectionConfig.fromJson(Map<String, dynamic> json) {
    final turnstile = Map<String, dynamic>.from(json["turnstile"] as Map? ?? {});
    final phone = Map<String, dynamic>.from(
      json["phone_verification"] as Map? ?? {},
    );
    final auth = Map<String, dynamic>.from(json["auth"] as Map? ?? {});
    return AuthProtectionConfig(
      turnstileEnabled: turnstile["enabled"] == true,
      turnstileSiteKey: (turnstile["site_key"] as String?) ?? "",
      phoneVerificationEnabled: phone["enabled"] == true,
      authChannels: [
        for (final item in auth["channels"] as List? ?? const [])
          if (item is String) item,
      ],
    );
  }

  final bool turnstileEnabled;
  final String turnstileSiteKey;
  final bool phoneVerificationEnabled;
  final List<String> authChannels;

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
    this.email = "",
    this.availableChannels = const [],
  });

  factory PhoneChallenge.fromJson(Map<String, dynamic> json) {
    return PhoneChallenge(
      challengeId: json["challenge_id"] as String,
      phone: json["phone"] as String? ?? "",
      email: json["email"] as String? ?? "",
      channel: json["channel"] as String? ?? "telegram",
      detail: json["detail"] as String? ?? "Код подтверждения отправлен.",
      codeLength: json["code_length"] as int? ?? 4,
      canTryNextChannel: json["can_try_next_channel"] == true,
      verified: json["verified"] == true,
      needsCode: json["needs_code"] != false,
      receiveNumber: json["receive_number"] as String? ?? "",
      availableChannels: [
        for (final item in json["available_channels"] as List? ?? const [])
          if (item is String) item,
      ],
    );
  }

  final String challengeId;
  final String phone;
  final String email;
  final String channel;
  final String detail;
  final int codeLength;
  final bool canTryNextChannel;
  final bool verified;
  final bool needsCode;
  final String receiveNumber;
  final List<String> availableChannels;

  bool get isCall => channel == "call";
  bool get isReceive => channel == "receive";
  bool get isEmail => channel == "email";
}

class PhoneConfirmationRequired implements Exception {
  const PhoneConfirmationRequired(this.challenge);

  final PhoneChallenge challenge;
}
