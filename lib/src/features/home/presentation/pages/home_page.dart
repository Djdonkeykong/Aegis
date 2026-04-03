import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../medications/domain/models/medication.dart';
import '../../../medications/domain/providers/medication_providers.dart';
import '../../../medications/presentation/pages/add_medication_page.dart';

final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

enum CalendarViewMode { daily, weekly, monthly }

final calendarViewModeProvider =
    StateProvider<CalendarViewMode?>((ref) => null);

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medications = ref.watch(medicationListProvider);
    final requestedViewMode = ref.watch(calendarViewModeProvider);
    final viewMode = requestedViewMode ??
        (medications.isEmpty
            ? CalendarViewMode.monthly
            : CalendarViewMode.daily);
    final spacing = context.spacing;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.large(
        heroTag: 'calendar-add-entry',
        onPressed: () => _openAddMedication(context),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 2,
        child: const Icon(Icons.add_rounded, size: 34),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top header row
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.m,
                vertical: spacing.s,
              ),
              child: _HeaderRow(viewMode: viewMode),
            ),

            SizedBox(height: spacing.s),

            if (viewMode == CalendarViewMode.weekly) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing.m),
                child: const _WeekCalendarStrip(),
              ),
              SizedBox(height: spacing.s),
            ],

            // Journal content area
            Expanded(
              child: viewMode == CalendarViewMode.monthly
                  ? _MonthlyCalendarView(
                      medications: medications,
                      onAdd: () => _openAddMedication(context),
                    )
                  : _SwipeableDayView(
                      child: _CalendarDayView(
                        medications: medications,
                        onAdd: () => _openAddMedication(context),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _openAddMedication(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddMedicationPage()),
    );
  }
}

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

bool _isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _monthName(int month) => _monthNames[month - 1];

String _weekdayName(DateTime date) => _weekdayNames[date.weekday - 1];

String _formatSelectedDate(DateTime date) =>
    '${_monthName(date.month)} ${date.day}';

String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

int _scheduledDoseCountForDay(List<Medication> medications) {
  var count = 0;
  for (final medication in medications) {
    count += medication.reminderTimes.isNotEmpty
        ? medication.reminderTimes.length
        : 1;
  }
  return count;
}

bool _isDayFullyCompleted({
  required DateTime day,
  required List<Medication> medications,
  required Map<String, Set<String>> log,
}) {
  final scheduledCount = _scheduledDoseCountForDay(medications);
  if (scheduledCount == 0) return false;

  final takenCount = (log[_dateKey(day)] ?? {}).length;
  return takenCount >= scheduledCount;
}

String _calendarViewModeLabel(CalendarViewMode mode) {
  switch (mode) {
    case CalendarViewMode.daily:
      return 'Daily';
    case CalendarViewMode.weekly:
      return 'Weekly';
    case CalendarViewMode.monthly:
      return 'Monthly';
  }
}

// -- Header Row --

class _HeaderRow extends ConsumerWidget {
  const _HeaderRow({required this.viewMode});

  final CalendarViewMode viewMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      alignment: Alignment.center,
      children: [
        PopupMenuButton<CalendarViewMode>(
          tooltip: 'Switch calendar view',
          onSelected: (mode) {
            HapticFeedback.selectionClick();
            ref.read(calendarViewModeProvider.notifier).state = mode;
          },
          itemBuilder: (context) => CalendarViewMode.values
              .map(
                (mode) => PopupMenuItem<CalendarViewMode>(
                  value: mode,
                  child: Text(_calendarViewModeLabel(mode)),
                ),
              )
              .toList(),
          child: _PillContainer(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _calendarViewModeLabel(viewMode),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: AppColors.textPrimary,
                ),
              ],
            ),
          ),
        ),

        // Left + Right positioned on top
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: logo
            Image.asset(
              'assets/logo@4x.png',
              width: 36,
              height: 36,
              fit: BoxFit.contain,
            ),

            // Right: notifications + app settings
            _PillContainer(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Notifications',
                    onPressed: () {},
                    splashRadius: 18,
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 18,
                    color: AppColors.outline,
                  ),
                  IconButton(
                    tooltip: 'App settings',
                    onPressed: () {},
                    splashRadius: 18,
                    icon: const Icon(
                      Icons.more_horiz_rounded,
                      color: AppColors.textPrimary,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// -- Week calendar strip --

class _WeekCalendarStrip extends ConsumerWidget {
  const _WeekCalendarStrip();

  static const _dayLabels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final log = ref.watch(medicationLogProvider);
    final medications = ref.watch(medicationListProvider);
    // Find Monday of the selected date's week
    final monday =
        selectedDate.subtract(Duration(days: selectedDate.weekday - 1));
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final date = monday.add(Duration(days: index));
        final isSelected = date.day == selectedDate.day &&
            date.month == selectedDate.month &&
            date.year == selectedDate.year;
        final isChecked = _isDayFullyCompleted(
          day: date,
          medications: medications,
          log: log,
        );

        return Expanded(
          child: GestureDetector(
            onTap: () {
              ref.read(selectedDateProvider.notifier).state =
                  DateTime(date.year, date.month, date.day);
            },
            child: Column(
              children: [
                Text(
                  _dayLabels[index],
                  style: textTheme.bodySmall?.copyWith(
                    color: isSelected
                        ? AppColors.textPrimary
                        : AppColors.textPrimary.withValues(alpha: 0.3),
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    border: isSelected
                        ? null
                        : Border.all(
                            color: AppColors.outline,
                            width: 1.5,
                          ),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Center(
                        child: Text(
                          '${date.day}',
                          style: textTheme.bodySmall?.copyWith(
                            color: isSelected
                                ? AppColors.onPrimary
                                : AppColors.textPrimary.withValues(alpha: 0.3),
                            fontWeight:
                                isSelected ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isChecked)
                        Positioned(
                          right: -1,
                          bottom: -1,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.onPrimary
                                  : AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              size: 10,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.onPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// -- Calendar views --

class _CalendarDayView extends StatelessWidget {
  const _CalendarDayView({
    required this.medications,
    required this.onAdd,
  });

  final List<Medication> medications;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.m),
          child: const _SelectedDateHeader(),
        ),
        SizedBox(height: spacing.s),
        Expanded(
          child: medications.isEmpty
              ? _EmptyJournalView(onTap: onAdd)
              : _DailyMedList(
                  medications: medications,
                  onAdd: onAdd,
                ),
        ),
      ],
    );
  }
}

class _MonthlyCalendarView extends ConsumerWidget {
  const _MonthlyCalendarView({
    required this.medications,
    required this.onAdd,
  });

  final List<Medication> medications;
  final VoidCallback onAdd;

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  List<DateTime?> _daysForMonth(DateTime month) {
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final leadingEmptyDays = firstDayOfMonth.weekday - 1;
    final days = <DateTime?>[
      ...List<DateTime?>.filled(leadingEmptyDays, null),
      for (var day = 1; day <= daysInMonth; day++)
        DateTime(month.year, month.month, day),
    ];

    while (days.length % 7 != 0) {
      days.add(null);
    }

    return days;
  }

  void _shiftMonth(WidgetRef ref, DateTime selectedDate, int delta) {
    final targetMonth =
        DateTime(selectedDate.year, selectedDate.month + delta, 1);
    final lastDay =
        DateUtils.getDaysInMonth(targetMonth.year, targetMonth.month);
    final clampedDay = selectedDate.day.clamp(1, lastDay);
    ref.read(selectedDateProvider.notifier).state =
        DateTime(targetMonth.year, targetMonth.month, clampedDay);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final selectedDate = ref.watch(selectedDateProvider);
    final month = DateTime(selectedDate.year, selectedDate.month, 1);
    final days = _daysForMonth(month);
    final rows = <List<DateTime?>>[];

    for (var index = 0; index < days.length; index += 7) {
      rows.add(days.sublist(index, index + 7));
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.l),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      _monthName(month.month),
                      style:
                          Theme.of(context).textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                    ),
                    const Spacer(),
                    Text(
                      '${month.year}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    SizedBox(width: spacing.s),
                  ],
                ),
              ),
              _MonthNavButton(
                icon: Icons.chevron_left_rounded,
                onTap: () => _shiftMonth(ref, selectedDate, -1),
              ),
              SizedBox(width: spacing.xs),
              _MonthNavButton(
                icon: Icons.chevron_right_rounded,
                onTap: () => _shiftMonth(ref, selectedDate, 1),
              ),
            ],
          ),
        ),
        SizedBox(height: spacing.m),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.m),
          child: Row(
            children: _dayLabels
                .map(
                  (label) => Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        SizedBox(height: spacing.s),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.xs),
          child: Column(
            children: rows
                .map(
                  (row) => Padding(
                    padding: EdgeInsets.only(bottom: spacing.xs / 2),
                    child: Row(
                      children: row
                          .map(
                            (day) => Expanded(
                              child: AspectRatio(
                                aspectRatio: 1.12,
                                child: day == null
                                    ? const SizedBox.shrink()
                                    : _MonthDayCell(day: day),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        SizedBox(height: spacing.m),
        Expanded(
          child: medications.isEmpty
              ? _MonthlyEmptyState(onTap: onAdd)
              : _DailyMedList(
                  medications: medications,
                  onAdd: onAdd,
                ),
        ),
      ],
    );
  }
}

class _SelectedDateHeader extends ConsumerWidget {
  const _SelectedDateHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final isToday = _isSameDate(selectedDate, DateTime.now());

    return _PillContainer(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              ref.read(selectedDateProvider.notifier).state =
                  selectedDate.subtract(const Duration(days: 1));
            },
            splashRadius: 18,
            icon: const Icon(
              Icons.chevron_left_rounded,
              color: AppColors.textPrimary,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  isToday ? 'Today' : _weekdayName(selectedDate),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatSelectedDate(selectedDate),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          if (!isToday)
            TextButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                ref.read(selectedDateProvider.notifier).state = _today();
              },
              child: const Text('Today'),
            ),
          IconButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              ref.read(selectedDateProvider.notifier).state =
                  selectedDate.add(const Duration(days: 1));
            },
            splashRadius: 18,
            icon: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textPrimary,
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
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            size: 22,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _MonthDayCell extends ConsumerWidget {
  const _MonthDayCell({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final log = ref.watch(medicationLogProvider);
    final medications = ref.watch(medicationListProvider);
    final isSelected = _isSameDate(day, selectedDate);
    final isToday = _isSameDate(day, DateTime.now());
    final isChecked = _isDayFullyCompleted(
      day: day,
      medications: medications,
      log: log,
    );

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        ref.read(selectedDateProvider.notifier).state = day;
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isSelected ? AppColors.primaryContainer : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? AppColors.primaryContainer
                : isToday
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                '${day.day}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: isSelected || isToday
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: isSelected
                          ? AppColors.onPrimaryContainer
                          : AppColors.textPrimary,
                    ),
              ),
            ),
            if (isChecked)
              Positioned(
                right: 6,
                bottom: 6,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.onPrimaryContainer
                        : AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 11,
                    color: isSelected
                        ? AppColors.primaryContainer
                        : AppColors.onPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyEmptyState extends StatelessWidget {
  const _MonthlyEmptyState({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Padding(
      padding: EdgeInsets.fromLTRB(spacing.l, spacing.s, spacing.l, spacing.l),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(spacing.l),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'No medications scheduled yet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
              ),
              SizedBox(height: spacing.s),
              Text(
                'Tap the + button to add your first medication and start filling this calendar.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -- Pill-shaped container --

class _PillContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;

  const _PillContainer({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// -- Empty state --

// -- Swipeable day view that slides content with the gesture --

class _SwipeableDayView extends ConsumerStatefulWidget {
  final Widget child;

  const _SwipeableDayView({required this.child});

  @override
  ConsumerState<_SwipeableDayView> createState() => _SwipeableDayViewState();
}

class _SwipeableDayViewState extends ConsumerState<_SwipeableDayView>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0;
  late AnimationController _animController;
  Animation<double>? _slideOut;
  Animation<double>? _slideIn;
  bool _isAnimating = false;
  int _slideDirection = 0; // -1 = left, 1 = right

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_isAnimating) return;
    setState(() {
      _dragOffset += details.delta.dx;
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_isAnimating) return;
    final velocity = details.primaryVelocity ?? 0;
    final screenWidth = MediaQuery.of(context).size.width;
    final threshold = screenWidth * 0.2;

    if (_dragOffset.abs() > threshold || velocity.abs() > 200) {
      // Determine direction: dragged right = previous day, dragged left = next day
      _slideDirection = _dragOffset > 0 ? 1 : -1;
      _isAnimating = true;
      HapticFeedback.mediumImpact();

      // Slide out current content
      _slideOut = Tween<double>(
        begin: _dragOffset,
        end: _slideDirection * screenWidth,
      ).animate(CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeIn),
      ));

      // Slide in new content from opposite side
      _slideIn = Tween<double>(
        begin: -_slideDirection * screenWidth * 0.3,
        end: 0.0,
      ).animate(CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.45, 1.0, curve: Curves.easeOut),
      ));

      _animController.forward(from: 0).then((_) {
        // Change the day
        final current = ref.read(selectedDateProvider);
        if (_slideDirection == 1) {
          ref.read(selectedDateProvider.notifier).state =
              current.subtract(const Duration(days: 1));
        } else {
          ref.read(selectedDateProvider.notifier).state =
              current.add(const Duration(days: 1));
        }
        setState(() {
          _dragOffset = 0;
          _isAnimating = false;
          _slideOut = null;
          _slideIn = null;
        });
        _animController.reset();
      });
    } else {
      // Snap back
      _isAnimating = true;
      _slideOut = Tween<double>(
        begin: _dragOffset,
        end: 0.0,
      ).animate(CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOut,
      ));
      _slideIn = null;

      _animController.forward(from: 0).then((_) {
        setState(() {
          _dragOffset = 0;
          _isAnimating = false;
          _slideOut = null;
        });
        _animController.reset();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      behavior: HitTestBehavior.translucent,
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          double offset;
          double opacity;
          if (_isAnimating &&
              _slideIn != null &&
              _animController.value > 0.45) {
            offset = _slideIn!.value;
            opacity = ((_animController.value - 0.45) / 0.55).clamp(0.0, 1.0);
          } else if (_isAnimating && _slideOut != null) {
            offset = _slideOut!.value;
            opacity = 1.0;
          } else {
            offset = _dragOffset;
            opacity = 1.0;
          }
          return Transform.translate(
            offset: Offset(offset, 0),
            child: Opacity(
              opacity: opacity,
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

// -- Empty state --

class _EmptyJournalView extends StatelessWidget {
  final VoidCallback onTap;

  const _EmptyJournalView({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: EdgeInsets.only(
            left: spacing.l,
            top: spacing.m,
          ),
          child: Text(
            'Start logging your meds...',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textPrimary.withValues(alpha: 0.3),
                ),
          ),
        ),
      ),
    );
  }
}

// -- Daily medication tracker list --

class _DailyMedList extends ConsumerWidget {
  final List<Medication> medications;
  final VoidCallback onAdd;

  const _DailyMedList({
    required this.medications,
    required this.onAdd,
  });

  List<_ScheduledDoseEntry> _buildEntries(List<Medication> medications) {
    final entries = <_ScheduledDoseEntry>[];

    for (final medication in medications) {
      final times = medication.reminderTimes.isNotEmpty
          ? medication.reminderTimes
          : const ['09:00'];

      for (final time in times) {
        final minutes = _timeToMinutes(time);
        entries.add(
          _ScheduledDoseEntry(
            medication: medication,
            time: time,
            logKey: '${medication.id}|$time',
            sortMinutes: minutes,
            sectionLabel: _timeSectionLabel(minutes),
          ),
        );
      }
    }

    entries.sort((a, b) {
      final compareSection = a.sortMinutes.compareTo(b.sortMinutes);
      if (compareSection != 0) return compareSection;
      return a.medication.name.toLowerCase().compareTo(
            b.medication.name.toLowerCase(),
          );
    });

    return entries;
  }

  int _timeToMinutes(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return 9 * 60;
    final hour = int.tryParse(parts[0]) ?? 9;
    final minute = int.tryParse(parts[1]) ?? 0;
    return hour * 60 + minute;
  }

  String _timeSectionLabel(int minutes) {
    if (minutes < 12 * 60) return 'Morning';
    if (minutes < 17 * 60) return 'Afternoon';
    if (minutes < 22 * 60) return 'Evening';
    return 'Night';
  }

  String _formatDoseTime(BuildContext context, String value) {
    final parts = value.split(':');
    final hour = parts.length == 2 ? int.tryParse(parts[0]) ?? 9 : 9;
    final minute = parts.length == 2 ? int.tryParse(parts[1]) ?? 0 : 0;
    return MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: hour, minute: minute),
    );
  }

  Future<void> _showDoseDetailsSheet(
    BuildContext parentContext,
    WidgetRef ref,
    _ScheduledDoseEntry entry,
    bool taken,
    String dateKey,
  ) {
    final spacing = parentContext.spacing;
    final medication = entry.medication;

    return showModalBottomSheet<void>(
      context: parentContext,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.m,
              spacing.s,
              spacing.m,
              spacing.m,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medication.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                SizedBox(height: spacing.s),
                _DoseDetailLine(
                  label: 'Time',
                  value: _formatDoseTime(context, entry.time),
                ),
                _DoseDetailLine(
                  label: 'Dosage',
                  value: medication.dosage ?? 'Not set',
                ),
                _DoseDetailLine(
                  label: 'Frequency',
                  value: medication.frequency ?? 'As needed',
                ),
                _DoseDetailLine(
                  label: 'Form',
                  value: medication.form.label,
                ),
                if (medication.foodTiming != MedicationFoodTiming.noPreference)
                  _DoseDetailLine(
                    label: 'Food',
                    value: medication.foodTiming.label,
                  ),
                if (medication.comment != null &&
                    medication.comment!.trim().isNotEmpty)
                  _DoseDetailLine(
                    label: 'Comment',
                    value: medication.comment!,
                  ),
                SizedBox(height: spacing.m),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          ref
                              .read(medicationLogProvider.notifier)
                              .toggle(dateKey, entry.logKey);
                          Navigator.of(context).pop();
                        },
                        child: Text(taken ? 'Mark Not Taken' : 'Mark Taken'),
                      ),
                    ),
                    SizedBox(width: spacing.s),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(parentContext).push(
                          MaterialPageRoute(
                            builder: (_) => AddMedicationPage(
                              existing: medication,
                            ),
                          ),
                        );
                      },
                      child: const Text('Edit'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final selectedDate = ref.watch(selectedDateProvider);
    final dateKey = _dateKey(selectedDate);
    final log = ref.watch(medicationLogProvider);
    final takenSet = log[dateKey] ?? {};
    final entries = _buildEntries(medications);
    final widgets = <Widget>[];
    String? currentSection;

    for (final entry in entries) {
      final taken = takenSet.contains(entry.logKey);
      if (entry.sectionLabel != currentSection) {
        currentSection = entry.sectionLabel;
        widgets.add(_DoseSectionHeader(title: currentSection));
      }

      widgets.add(
        _DailyDoseCard(
          medication: entry.medication,
          taken: taken,
          timeLabel: _formatDoseTime(context, entry.time),
          cardKey: entry.logKey,
          onToggle: () {
            ref
                .read(medicationLogProvider.notifier)
                .toggle(dateKey, entry.logKey);
          },
          onTap: () =>
              _showDoseDetailsSheet(context, ref, entry, taken, dateKey),
          onEdit: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AddMedicationPage(existing: entry.medication),
              ),
            );
          },
          onDelete: () {
            ref
                .read(medicationListProvider.notifier)
                .remove(entry.medication.id);
          },
        ),
      );
    }

    widgets.add(
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Center(
          child: GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF9FAFB),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 20,
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ),
      ),
    );

    return ListView(
      padding: EdgeInsets.only(
        left: spacing.m,
        right: spacing.m,
        top: spacing.s,
        bottom: spacing.m,
      ),
      children: widgets,
    );
  }
}

class _ScheduledDoseEntry {
  final Medication medication;
  final String time;
  final String logKey;
  final int sortMinutes;
  final String sectionLabel;

  const _ScheduledDoseEntry({
    required this.medication,
    required this.time,
    required this.logKey,
    required this.sortMinutes,
    required this.sectionLabel,
  });
}

class _DoseSectionHeader extends StatelessWidget {
  final String title;

  const _DoseSectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
      ),
    );
  }
}

class _DailyDoseCard extends StatelessWidget {
  final Medication medication;
  final bool taken;
  final String timeLabel;
  final String cardKey;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DailyDoseCard({
    required this.medication,
    required this.taken,
    required this.onTap,
    required this.cardKey,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.timeLabel,
  });

  String _subtitle() {
    final parts = <String>[
      if (medication.dosage != null && medication.dosage!.isNotEmpty)
        medication.dosage!,
      if (medication.foodTiming != MedicationFoodTiming.noPreference)
        medication.foodTiming.label,
      medication.form.label,
    ];
    return parts.join(' | ');
  }

  String _assetPathForForm(MedicationForm form) {
    switch (form) {
      case MedicationForm.tablet:
      case MedicationForm.capsule:
        return 'assets/healthicons--pill-1-24px.svg';
      default:
        return 'assets/fluent--pill-24-filled.svg';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Slidable(
        key: ValueKey(cardKey),
        startActionPane: ActionPane(
          motion: const BehindMotion(),
          extentRatio: 0.2,
          children: [
            CustomSlidableAction(
              onPressed: (_) => onEdit(),
              backgroundColor: Colors.transparent,
              padding: EdgeInsets.zero,
              child: const _SlidableAnimatedAction(
                color: AppColors.primary,
                icon: Icons.edit_rounded,
                label: 'Edit',
              ),
            ),
          ],
        ),
        endActionPane: ActionPane(
          motion: const BehindMotion(),
          extentRatio: 0.2,
          children: [
            CustomSlidableAction(
              onPressed: (_) => onDelete(),
              backgroundColor: Colors.transparent,
              padding: EdgeInsets.zero,
              child: const _SlidableAnimatedAction(
                color: AppColors.error,
                icon: Icons.delete_rounded,
                label: 'Delete',
              ),
            ),
          ],
        ),
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 86,
            padding: const EdgeInsets.only(left: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: taken
                    ? AppColors.success.withValues(alpha: 0.3)
                    : Colors.white,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                SvgPicture.asset(
                  _assetPathForForm(medication.form),
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(
                    taken ? AppColors.success : AppColors.primary,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medication.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: taken
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                              decoration:
                                  taken ? TextDecoration.lineThrough : null,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _subtitle(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        timeLabel,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: taken
                                      ? AppColors.textSecondary
                                      : AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: onToggle,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: taken
                                ? AppColors.successContainer
                                : AppColors.surface,
                            border: Border.all(
                              color:
                                  taken ? AppColors.success : AppColors.outline,
                            ),
                          ),
                          child: Icon(
                            taken ? Icons.check_rounded : Icons.circle_outlined,
                            size: taken ? 18 : 16,
                            color: taken
                                ? AppColors.success
                                : AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DoseDetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _DoseDetailLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
              ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

// -- Animated action that scales + fades using Slidable's animation --

class _SlidableAnimatedAction extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;

  const _SlidableAnimatedAction({
    required this.color,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Slidable.of(context)!;
    return AnimatedBuilder(
      animation: controller.animation,
      builder: (context, child) {
        final t = (controller.animation.value / 0.2).clamp(0.0, 1.0);
        return Center(
          child: Opacity(
            opacity: t,
            child: Transform.scale(
              scale: 0.5 + (0.5 * t),
              child: child,
            ),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
