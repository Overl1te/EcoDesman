import type { SupportReport, SupportThreadSummary, UserRole } from "@/lib/types";

export const REPORT_REASON_OPTIONS: Array<{
  value: "spam" | "abuse" | "misinformation" | "dangerous" | "copyright" | "other";
  label: string;
  description: string;
}> = [
  {
    value: "spam",
    label: "Спам",
    description: "Реклама, повторяющийся или нерелевантный контент.",
  },
  {
    value: "abuse",
    label: "Оскорбления",
    description: "Токсичное поведение, травля или агрессия.",
  },
  {
    value: "misinformation",
    label: "Недостоверно",
    description: "Неверные или вводящие в заблуждение сведения.",
  },
  {
    value: "dangerous",
    label: "Опасно",
    description: "Контент может навредить людям, животным или среде.",
  },
  {
    value: "copyright",
    label: "Авторские права",
    description: "Чужой материал опубликован без разрешения.",
  },
  {
    value: "other",
    label: "Другое",
    description: "Любая другая проблема, которую нужно описать текстом.",
  },
];

export const SUPPORT_THREAD_CATEGORY_OPTIONS: Array<{
  value: SupportThreadSummary["category"];
  label: string;
  description: string;
}> = [
  {
    value: "general",
    label: "Общее",
    description: "Любые вопросы по приложению и сервису.",
  },
  {
    value: "account",
    label: "Аккаунт",
    description: "Вход, профиль, пароль и ограничения аккаунта.",
  },
  {
    value: "content",
    label: "Контент",
    description: "Посты, комментарии, скрытия и публикация.",
  },
  {
    value: "map",
    label: "Карта",
    description: "Точки, отзывы, фотографии и ошибки карты.",
  },
  {
    value: "report",
    label: "Жалоба",
    description: "Разбор отправленных жалоб и модерационных решений.",
  },
];

export const SUPPORT_THREAD_STATUS_OPTIONS: Array<{
  value: SupportThreadSummary["status"];
  label: string;
}> = [
  { value: "open", label: "Открыт" },
  { value: "waiting_support", label: "Ждет поддержки" },
  { value: "waiting_user", label: "Ждет пользователя" },
  { value: "closed", label: "Закрыт" },
];

export const SUPPORT_REPORT_STATUS_OPTIONS: Array<{
  value: SupportReport["status"];
  label: string;
}> = [
  { value: "new", label: "Новая" },
  { value: "in_review", label: "В работе" },
  { value: "resolved", label: "Решена" },
  { value: "rejected", label: "Отклонена" },
];

export function getRoleLabel(role: UserRole): string {
  if (role === "admin") {
    return "Админ";
  }
  if (role === "support") {
    return "Техподдержка";
  }
  if (role === "moderator") {
    return "Модератор";
  }
  return "Пользователь";
}

export function getSupportThreadStatusLabel(status: SupportThreadSummary["status"]): string {
  return (
    SUPPORT_THREAD_STATUS_OPTIONS.find((item) => item.value === status)?.label ?? "Открыт"
  );
}

export function getSupportThreadCategoryLabel(
  category: SupportThreadSummary["category"],
): string {
  return (
    SUPPORT_THREAD_CATEGORY_OPTIONS.find((item) => item.value === category)?.label ?? "Общее"
  );
}

export function getSupportReportStatusLabel(status: SupportReport["status"]): string {
  return (
    SUPPORT_REPORT_STATUS_OPTIONS.find((item) => item.value === status)?.label ?? "Новая"
  );
}

export function getSupportReportTargetLabel(targetType: SupportReport["target_type"]): string {
  if (targetType === "comment") {
    return "Комментарий";
  }
  if (targetType === "map_review") {
    return "Отзыв на карте";
  }
  return "Пост";
}

export function getSupportReportReasonLabel(reason: SupportReport["reason"]): string {
  return REPORT_REASON_OPTIONS.find((item) => item.value === reason)?.label ?? "Другое";
}
