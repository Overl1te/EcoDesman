const LOCAL_PHONE_LENGTH = 10;

function toLocalDigits(value: string): string {
  let digits = value.replace(/\D/g, "");
  if (!digits || digits === "7" || digits === "8") {
    return "";
  }

  const originalLength = digits.length;
  const hadPlus = value.includes("+");

  while (
    digits.length > LOCAL_PHONE_LENGTH &&
    (digits.startsWith("7") || digits.startsWith("8"))
  ) {
    digits = digits.slice(1);
  }

  // Formatted "+7 (99…" still contains the country code while the number is incomplete.
  if (hadPlus && originalLength <= LOCAL_PHONE_LENGTH && digits.startsWith("7")) {
    digits = digits.slice(1);
    if (digits === "7") {
      digits = "";
    }
  }

  return digits.slice(0, LOCAL_PHONE_LENGTH);
}

export function looksLikeRuPhoneInput(value: string): boolean {
  const trimmed = value.trim();
  if (!trimmed) {
    return false;
  }

  if (/[A-Za-zА-Яа-яЁё@._]/.test(trimmed)) {
    return false;
  }

  return /^[\d+\s()-]+$/.test(trimmed);
}

export function formatRuPhone(value: string): string {
  const local = toLocalDigits(value);
  if (!local && !value.trim()) {
    return "";
  }

  const area = local.slice(0, 3);
  const first = local.slice(3, 6);
  const second = local.slice(6, 8);
  const third = local.slice(8, 10);

  let formatted = "+7";
  if (area) {
    formatted += ` (${area}`;
    if (area.length === 3) {
      formatted += ")";
    }
  }
  if (first) {
    formatted += ` ${first}`;
  }
  if (second) {
    formatted += `-${second}`;
  }
  if (third) {
    formatted += `-${third}`;
  }

  return formatted;
}

export function toE164RuPhone(value: string): string | undefined {
  const local = toLocalDigits(value);
  return local.length === LOCAL_PHONE_LENGTH ? `+7${local}` : undefined;
}

export function formatLoginIdentifier(value: string): string {
  return looksLikeRuPhoneInput(value) ? formatRuPhone(value) : value;
}

export function normalizeLoginIdentifier(value: string): string {
  const trimmed = value.trim();
  if (!looksLikeRuPhoneInput(trimmed)) {
    return trimmed;
  }

  return toE164RuPhone(trimmed) ?? trimmed;
}
