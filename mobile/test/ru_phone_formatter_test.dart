import "package:eco_nizhny/core/formatters/ru_phone_formatter.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("ru phone formatter", () {
    test("formats and normalizes masked, trunk and pasted numbers", () {
      const expected = "+79991234567";

      expect(toE164RuPhone("+7 (999) 123-45-67"), expected);
      expect(toE164RuPhone("8 (999) 123-45-67"), expected);
      expect(toE164RuPhone("89991234567"), expected);
      expect(toE164RuPhone("9991234567"), expected);
      expect(toE164RuPhone("+7 89991234567"), expected);
      expect(toE164RuPhone("+7+79991234567"), expected);
    });

    test("keeps country code out of local digits while typing after +7", () {
      expect(formatRuPhone("+7"), "+7");
      expect(formatRuPhone("+79"), "+7 (9");
      expect(formatRuPhone("+7 (999) 123-45-67"), "+7 (999) 123-45-67");
      expect(formatRuPhone("+7 (899) 912-34-567"), "+7 (999) 123-45-67");
    });

    test("does not treat email or username as a phone", () {
      expect(looksLikeRuPhoneInput("anna@econizhny.local"), isFalse);
      expect(looksLikeRuPhoneInput("eco_admin"), isFalse);
      expect(normalizeLoginIdentifier("anna@econizhny.local"), "anna@econizhny.local");
    });
  });
}
