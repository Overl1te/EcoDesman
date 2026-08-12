import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../../core/network/error_message.dart";
import "../../../../core/routing/app_routes.dart";
import "../../../../core/utils/date_formatter.dart";
import "../../../../shared/widgets/remote_avatar.dart";
import "../../../auth/presentation/controllers/auth_controller.dart";
import "../../../feed/data/repositories/posts_repository_impl.dart";
import "../../../feed/presentation/controllers/feed_controller.dart";
import "../../domain/models/event_calendar_entry.dart";
import "../../domain/models/event_calendar_month.dart";

class EventsPlaceholderScreen extends ConsumerStatefulWidget {
  const EventsPlaceholderScreen({super.key});

  @override
  ConsumerState<EventsPlaceholderScreen> createState() =>
      _EventsPlaceholderScreenState();
}

class _EventsPlaceholderScreenState
    extends ConsumerState<EventsPlaceholderScreen> {
  late DateTime _visibleMonth;
  DateTime? _selectedDate;
  EventCalendarMonth? _monthData;
  bool _isLoading = true;
  bool _isUpdating = false;
  String? _errorMessage;

  DateTime get _monthStart =>
      DateTime(DateTime.now().year, DateTime.now().month);
  DateTime get _monthLimit => DateTime(DateTime.now().year + 10, 12);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);
    Future.microtask(_loadCalendar);
  }

  Future<void> _loadCalendar() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final monthData = await ref
          .read(postsRepositoryProvider)
          .fetchEventCalendar(
            year: _visibleMonth.year,
            month: _visibleMonth.month,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _monthData = monthData;
        final currentMonthSelection =
            _selectedDate != null &&
            _selectedDate!.year == _visibleMonth.year &&
            _selectedDate!.month == _visibleMonth.month;
        _selectedDate = currentMonthSelection
            ? _selectedDate
            : monthData.events.firstOrNull?.eventDate ??
                  DateTime(_visibleMonth.year, _visibleMonth.month, 1);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = humanizeNetworkError(
          error,
          fallback: "Не удалось загрузить календарь мероприятий",
        );
      });
    }
  }

  Future<void> _changeMonth(int direction) async {
    final next = DateTime(_visibleMonth.year, _visibleMonth.month + direction);
    if (_compareMonth(next, _monthStart) < 0 ||
        _compareMonth(next, _monthLimit) > 0) {
      return;
    }

    setState(() {
      _visibleMonth = DateTime(next.year, next.month);
      _selectedDate = DateTime(next.year, next.month, 1);
    });
    await _loadCalendar();
  }

  Future<void> _jumpToToday() async {
    final now = DateTime.now();
    setState(() {
      _visibleMonth = DateTime(now.year, now.month);
      _selectedDate = DateTime(now.year, now.month, now.day);
    });
    await _loadCalendar();
  }

  Future<void> _toggleEventCancelled(EventCalendarEntry entry) async {
    final authState = ref.read(authControllerProvider);
    if (!authState.isAuthenticated) {
      _showSnack("Войдите, чтобы управлять мероприятием");
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      final post = await ref
          .read(postsRepositoryProvider)
          .setEventCancelled(
            postId: entry.id,
            isCancelled: !entry.isEventCancelled,
          );
      ref.read(feedControllerProvider.notifier).upsertPost(post);
      ref.invalidate(postsCollectionControllerProvider(defaultEventsQuery));
      if (!mounted) {
        return;
      }
      await _loadCalendar();
      _showSnack(
        entry.isEventCancelled
            ? "Мероприятие снова активно"
            : "Мероприятие отменено",
      );
    } catch (error) {
      _showSnack(
        humanizeNetworkError(
          error,
          fallback: "Не удалось обновить статус мероприятия",
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedEvents = _eventsForSelectedDay();
    final activeEvents = selectedEvents
        .where((entry) => !entry.isEventCancelled)
        .toList();
    final nextEvent = activeEvents.firstOrNull;
    final monthLabel = formatCalendarHeader(_visibleMonth);
    final selectedLabel = _selectedDate == null
        ? "Выберите день"
        : formatCalendarDayLabel(_selectedDate!);
    final canGoPrev = _compareMonth(_visibleMonth, _monthStart) > 0;
    final canGoNext = _compareMonth(_visibleMonth, _monthLimit) < 0;
    final now = DateTime.now();
    final shouldShowTodayButton =
        _visibleMonth.year != now.year ||
        _visibleMonth.month != now.month ||
        _selectedDate == null ||
        _selectedDate!.year != now.year ||
        _selectedDate!.month != now.month ||
        _selectedDate!.day != now.day;

    return RefreshIndicator(
      onRefresh: _loadCalendar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _EventsHeaderCard(
            monthLabel: monthLabel,
            selectedLabel: selectedLabel,
            nextEvent: nextEvent,
            showTodayButton: shouldShowTodayButton,
            onJumpToToday: _jumpToToday,
            canGoPrev: canGoPrev,
            canGoNext: canGoNext,
            onPreviousMonth: () => _changeMonth(-1),
            onNextMonth: () => _changeMonth(1),
          ),
          const SizedBox(height: 18),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_errorMessage != null)
            _EventsErrorState(message: _errorMessage!, onRetry: _loadCalendar)
          else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.72,
                  ),
                ),
              ),
              child: _MonthGrid(
                visibleMonth: _visibleMonth,
                selectedDate: _selectedDate,
                events: _monthData?.events ?? const [],
                onDateSelected: (date) {
                  setState(() {
                    _selectedDate = date;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedLabel,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          selectedEvents.isEmpty
                              ? "Пока без мероприятий"
                              : "${selectedEvents.length} ${_eventsCountLabel(selectedEvents.length)} в подборке дня",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: selectedEvents.isEmpty
                          ? theme.colorScheme.surface
                          : theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      selectedEvents.isEmpty
                          ? Icons.event_busy_outlined
                          : Icons.event_available_outlined,
                      color: selectedEvents.isEmpty
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (selectedEvents.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.surface,
                      theme.colorScheme.surfaceContainerHigh,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.calendar_today_outlined,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "День пока свободен",
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Выберите другую дату или создайте новое мероприятие, если хотите заполнить этот день.",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              ...selectedEvents.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _EventAgendaCard(
                    entry: entry,
                    isUpdating: _isUpdating,
                    onOpen: () => context.push(
                      AppRoutes.postDetail(
                        postId: entry.id,
                        authorUsername: entry.author.username,
                        postSlug: entry.slug,
                      ),
                    ),
                    onAuthorTap: () => context.push(
                      AppRoutes.profile(
                        userId: entry.author.id,
                        username: entry.author.username,
                      ),
                    ),
                    onToggleCancelled: entry.canEdit
                        ? () => _toggleEventCancelled(entry)
                        : null,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  List<EventCalendarEntry> _eventsForSelectedDay() {
    final selected = _selectedDate;
    final events = _monthData?.events ?? const <EventCalendarEntry>[];
    if (selected == null) {
      return _sortedEvents(events);
    }
    return _sortedEvents(
      events.where(
        (entry) =>
            entry.eventDate != null &&
            entry.eventDate!.year == selected.year &&
            entry.eventDate!.month == selected.month &&
            entry.eventDate!.day == selected.day,
      ),
    );
  }

  List<EventCalendarEntry> _sortedEvents(Iterable<EventCalendarEntry> source) {
    final sorted = source.toList();
    sorted.sort((left, right) {
      if (left.isEventCancelled != right.isEventCancelled) {
        return left.isEventCancelled ? 1 : -1;
      }

      final leftTime = left.eventStartsAt ?? left.eventDate;
      final rightTime = right.eventStartsAt ?? right.eventDate;
      if (leftTime == null && rightTime == null) {
        return left.id.compareTo(right.id);
      }
      if (leftTime == null) {
        return 1;
      }
      if (rightTime == null) {
        return -1;
      }

      final timeCompare = leftTime.compareTo(rightTime);
      if (timeCompare != 0) {
        return timeCompare;
      }

      return left.id.compareTo(right.id);
    });
    return sorted;
  }

  int _compareMonth(DateTime left, DateTime right) {
    return left.year * 12 + left.month - (right.year * 12 + right.month);
  }
}

class _EventsHeaderCard extends StatelessWidget {
  const _EventsHeaderCard({
    required this.monthLabel,
    required this.selectedLabel,
    required this.nextEvent,
    required this.showTodayButton,
    required this.onJumpToToday,
    required this.canGoPrev,
    required this.canGoNext,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final String monthLabel;
  final String selectedLabel;
  final EventCalendarEntry? nextEvent;
  final bool showTodayButton;
  final VoidCallback onJumpToToday;
  final bool canGoPrev;
  final bool canGoNext;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surface,
            theme.colorScheme.surfaceContainerHigh,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.82),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      monthLabel,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      selectedLabel,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (showTodayButton)
                FilledButton.tonal(
                  onPressed: onJumpToToday,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  child: const Text("Сегодня"),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MonthNavButton(
                  icon: Icons.chevron_left,
                  label: "Назад",
                  enabled: canGoPrev,
                  onPressed: onPreviousMonth,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MonthNavButton(
                  icon: Icons.chevron_right,
                  label: "Дальше",
                  enabled: canGoNext,
                  onPressed: onNextMonth,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(22),
            ),
            child: nextEvent == null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Фокус на выбранном дне",
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Когда в дне появятся мероприятия, ближайшее будет показано здесь.",
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Ближайшее в программе",
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        nextEvent!.title.isEmpty
                            ? "Мероприятие без заголовка"
                            : nextEvent!.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        nextEvent!.eventStartsAt == null
                            ? "Время уточняется"
                            : formatEventRange(
                                nextEvent!.eventStartsAt,
                                nextEvent!.eventEndsAt,
                              ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (nextEvent!.eventLocation.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          nextEvent!.eventLocation,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _MonthNavButton extends StatelessWidget {
  const _MonthNavButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return OutlinedButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        backgroundColor: enabled
            ? theme.colorScheme.surface.withValues(alpha: 0.8)
            : null,
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.visibleMonth,
    required this.selectedDate,
    required this.events,
    required this.onDateSelected,
  });

  final DateTime visibleMonth;
  final DateTime? selectedDate;
  final List<EventCalendarEntry> events;
  final ValueChanged<DateTime> onDateSelected;

  static const _weekdays = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dayMap = <String, List<EventCalendarEntry>>{};
    for (final event in events) {
      final date = event.eventDate;
      if (date == null) {
        continue;
      }
      final key = _key(date);
      dayMap.putIfAbsent(key, () => []).add(event);
    }

    final firstDay = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final firstWeekday = firstDay.weekday - 1;
    final gridStart = firstDay.subtract(Duration(days: firstWeekday));

    return Column(
      children: [
        Row(
          children: [
            for (final day in _weekdays)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 42,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 0.86,
          ),
          itemBuilder: (context, index) {
            final date = gridStart.add(Duration(days: index));
            final key = _key(date);
            final isCurrentMonth = date.month == visibleMonth.month;
            final isSelected =
                selectedDate != null &&
                selectedDate!.year == date.year &&
                selectedDate!.month == date.month &&
                selectedDate!.day == date.day;
            final dayEvents = dayMap[key] ?? const <EventCalendarEntry>[];
            final cancelledCount = dayEvents
                .where((item) => item.isEventCancelled)
                .length;

            return InkWell(
              onTap: () => onDateSelected(date),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : isCurrentMonth
                        ? theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.35,
                          )
                        : theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.15,
                          ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${date.day}",
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isCurrentMonth
                            ? null
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    if (dayEvents.isNotEmpty)
                      Text(
                        "${dayEvents.length}",
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    if (dayEvents.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          for (var i = 0; i < dayEvents.length && i < 3; i++)
                            Container(
                              width: 7,
                              height: 7,
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                color: dayEvents[i].isEventCancelled
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          const Spacer(),
                          if (cancelledCount > 0)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text(
                                "$cancelledCount",
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  String _key(DateTime value) {
    return "${value.year}-${value.month.toString().padLeft(2, "0")}-${value.day.toString().padLeft(2, "0")}";
  }
}

class _EventAgendaCard extends StatelessWidget {
  const _EventAgendaCard({
    required this.entry,
    required this.isUpdating,
    required this.onOpen,
    required this.onAuthorTap,
    this.onToggleCancelled,
  });

  final EventCalendarEntry entry;
  final bool isUpdating;
  final VoidCallback onOpen;
  final VoidCallback onAuthorTap;
  final VoidCallback? onToggleCancelled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surface,
            theme.colorScheme.surfaceContainerLowest,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InkWell(
                  onTap: onAuthorTap,
                  borderRadius: BorderRadius.circular(18),
                  child: Row(
                    children: [
                      RemoteAvatar(
                        imageUrl: entry.author.avatarUrl,
                        fallbackLabel: entry.author.displayName,
                        radius: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.author.displayName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (entry.author.statusText.isNotEmpty)
                              Text(
                                entry.author.statusText,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Chip(
                label: Text(
                  entry.isEventCancelled ? "Отменено" : "Запланировано",
                ),
                backgroundColor: entry.isEventCancelled
                    ? theme.colorScheme.errorContainer
                    : theme.colorScheme.primaryContainer,
                labelStyle: TextStyle(
                  color: entry.isEventCancelled
                      ? theme.colorScheme.onErrorContainer
                      : theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
                side: BorderSide.none,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: entry.isEventCancelled
                  ? theme.colorScheme.errorContainer.withValues(alpha: 0.9)
                  : theme.colorScheme.primaryContainer.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Icon(
                  entry.isEventCancelled
                      ? Icons.event_busy_outlined
                      : Icons.event_available_outlined,
                  size: 18,
                  color: entry.isEventCancelled
                      ? theme.colorScheme.onErrorContainer
                      : theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.eventStartsAt == null
                        ? "Время проведения уточняется"
                        : formatEventRange(
                            entry.eventStartsAt,
                            entry.eventEndsAt,
                          ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: entry.isEventCancelled
                          ? theme.colorScheme.onErrorContainer
                          : theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            entry.title.isEmpty ? "Мероприятие без заголовка" : entry.title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (entry.body.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              entry.body,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoPill(
                icon: Icons.calendar_today_outlined,
                label: formatEventDay(entry.eventDate ?? entry.eventStartsAt),
              ),
              if (entry.eventStartsAt != null)
                _InfoPill(
                  icon: Icons.schedule_outlined,
                  label: formatEventRange(
                    entry.eventStartsAt,
                    entry.eventEndsAt,
                  ),
                ),
              if (entry.eventLocation.trim().isNotEmpty)
                _InfoPill(
                  icon: Icons.place_outlined,
                  label: entry.eventLocation,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: onOpen,
                child: const Text("Открыть пост"),
              ),
              if (onToggleCancelled != null) ...[
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: isUpdating ? null : onToggleCancelled,
                  child: Text(
                    isUpdating
                        ? "Сохраняю..."
                        : entry.isEventCancelled
                        ? "Вернуть в программу"
                        : "Отменить мероприятие",
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Flexible(child: Text(label)),
        ],
      ),
    );
  }
}

class _EventsErrorState extends StatelessWidget {
  const _EventsErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Не удалось загрузить мероприятия",
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(message),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text("Повторить")),
        ],
      ),
    );
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

String _eventsCountLabel(int count) {
  final mod10 = count % 10;
  final mod100 = count % 100;

  if (mod10 == 1 && mod100 != 11) {
    return "событие";
  }
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return "события";
  }
  return "событий";
}
