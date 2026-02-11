import 'dart:ui';
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

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medications = ref.watch(medicationListProvider);
    final spacing = context.spacing;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top header row
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.m,
                vertical: spacing.s,
              ),
              child: const _HeaderRow(),
            ),

            SizedBox(height: spacing.s),

            // Week calendar strip
            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.m),
              child: const _WeekCalendarStrip(),
            ),

            SizedBox(height: spacing.s),

            // Journal content area
            Expanded(
              child: _SwipeableDayView(
                child: medications.isEmpty
                    ? _EmptyJournalView(
                        onTap: () => _openAddMedication(context),
                      )
                    : _DailyMedList(
                        medications: medications,
                        onAdd: () => _openAddMedication(context),
                      ),
              ),
            ),

            // One-time entry button
            Padding(
              padding: EdgeInsets.only(
                right: spacing.m,
                bottom: spacing.m,
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => _openAddMedication(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_circle_outline_rounded,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'One-time entry',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                        ),
                      ],
                    ),
                  ),
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

// -- Header Row --

class _HeaderRow extends ConsumerWidget {
  const _HeaderRow();

  String _dateLabel(DateTime selected) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (selected == today) return 'Today';
    final yesterday = today.subtract(const Duration(days: 1));
    if (selected == yesterday) return 'Yesterday';
    final tomorrow = today.add(const Duration(days: 1));
    if (selected == tomorrow) return 'Tomorrow';
    return '${selected.day}/${selected.month}';
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  int _computeStreak(Map<String, Set<String>> log) {
    final now = DateTime.now();
    var day = DateTime(now.year, now.month, now.day);
    var streak = 0;
    while (true) {
      final key = _dateKey(day);
      final taken = log[key];
      if (taken != null && taken.isNotEmpty) {
        streak++;
        day = day.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final log = ref.watch(medicationLogProvider);
    final streak = _computeStreak(log);

    return Stack(
      alignment: Alignment.center,
      children: [
        // Center: date pill (absolutely centered)
        GestureDetector(
          onTap: () async {
            final picked = await _showCalendarSheet(context, selectedDate);
            if (picked != null) {
              ref.read(selectedDateProvider.notifier).state =
                  DateTime(picked.year, picked.month, picked.day);
            }
          },
          child: _PillContainer(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            child: Text(
              _dateLabel(selectedDate),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
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

            // Right: streak + settings pill
            _PillContainer(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/fireicon.png',
                    width: 19,
                    height: 19,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$streak',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                  ),
                  const SizedBox(width: 16),
                  Image.asset(
                    'assets/cog-wheel-silhouette.png',
                    width: 17,
                    height: 17,
                    color: AppColors.textPrimary,
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
    // Find Monday of the selected date's week
    final monday = selectedDate.subtract(Duration(days: selectedDate.weekday - 1));
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final date = monday.add(Duration(days: index));
        final isSelected = date.day == selectedDate.day &&
            date.month == selectedDate.month &&
            date.year == selectedDate.year;

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
                child: Center(
                  child: Text(
                    '${date.day}',
                    style: textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? AppColors.onPrimary
                          : AppColors.textPrimary.withValues(alpha: 0.3),
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
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

// -- Calendar bottom sheet --

Future<DateTime?> _showCalendarSheet(BuildContext context, DateTime initial) {
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.15),
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      child: _CalendarSheet(initialDate: initial),
    ),
  );
}

class _CalendarSheet extends StatefulWidget {
  final DateTime initialDate;

  const _CalendarSheet({required this.initialDate});

  @override
  State<_CalendarSheet> createState() => _CalendarSheetState();
}

class _CalendarSheetState extends State<_CalendarSheet>
    with SingleTickerProviderStateMixin {
  late DateTime _selected;
  late DateTime _viewMonth;
  double _dragOffset = 0;
  late AnimationController _monthAnimController;
  double _animStartOffset = 0;
  int _pendingDirection = 0; // -1 = next, 1 = prev

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDate;
    _viewMonth = DateTime(_selected.year, _selected.month);
    _monthAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _monthAnimController.dispose();
    super.dispose();
  }

  void _animateMonth(int direction) {
    if (_monthAnimController.isAnimating) return;
    _pendingDirection = direction;
    _animStartOffset = _dragOffset;
    _monthAnimController.forward(from: 0).then((_) {
      setState(() {
        if (direction == 1) {
          _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1);
        } else {
          _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + 1);
        }
        _dragOffset = 0;
        _pendingDirection = 0;
      });
      _monthAnimController.reset();
    });
  }

  double get _currentOffset {
    if (_monthAnimController.isAnimating) {
      final double target;
      if (_pendingDirection != 0) {
        final screenWidth = MediaQuery.of(context).size.width;
        target = _pendingDirection * screenWidth;
      } else {
        target = 0;
      }
      final t = Curves.easeInOut.transform(_monthAnimController.value);
      return _animStartOffset + (target - _animStartOffset) * t;
    }
    return _dragOffset;
  }

  void _prevMonth() {
    HapticFeedback.selectionClick();
    _animateMonth(1);
  }

  void _nextMonth() {
    HapticFeedback.selectionClick();
    _animateMonth(-1);
  }

  void _goToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _selected = today;
      _viewMonth = DateTime(today.year, today.month);
    });
  }

  List<DateTime?> _daysInMonth() {
    final first = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final daysCount = DateTime(_viewMonth.year, _viewMonth.month + 1, 0).day;
    // Monday = 1, Sunday = 7
    final startWeekday = first.weekday; // 1 = Monday
    final cells = <DateTime?>[];
    // Leading nulls
    for (var i = 1; i < startWeekday; i++) {
      cells.add(null);
    }
    for (var d = 1; d <= daysCount; d++) {
      cells.add(DateTime(_viewMonth.year, _viewMonth.month, d));
    }
    return cells;
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  bool _isSelected(DateTime d) {
    return d.year == _selected.year &&
        d.month == _selected.month &&
        d.day == _selected.day;
  }

  @override
  Widget build(BuildContext context) {
    final days = _daysInMonth();
    final rows = <List<DateTime?>>[];
    for (var i = 0; i < days.length; i += 7) {
      rows.add(days.sublist(i, (i + 7).clamp(0, days.length)));
    }
    // Pad last row
    if (rows.isNotEmpty && rows.last.length < 7) {
      while (rows.last.length < 7) {
        rows.last.add(null);
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB).withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 0.5),
      ),
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 20),

          // Header: Today / Month Year / Done
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _goToday,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      'Today',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _prevMonth,
                  child: const Icon(Icons.chevron_left_rounded,
                      color: AppColors.textSecondary, size: 22),
                ),
                const SizedBox(width: 4),
                Text(
                  '${_monthNames[_viewMonth.month - 1]} ${_viewMonth.year}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: _nextMonth,
                  child: const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textSecondary, size: 22),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(_selected),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      'Done',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Day labels + grid (swipeable)
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              if (_monthAnimController.isAnimating) return;
              setState(() {
                _dragOffset += details.delta.dx;
              });
            },
            onHorizontalDragEnd: (details) {
              if (_monthAnimController.isAnimating) return;
              final velocity = details.primaryVelocity ?? 0;
              final screenWidth = MediaQuery.of(context).size.width;
              if (velocity > 200 || _dragOffset > screenWidth * 0.2) {
                _prevMonth();
              } else if (velocity < -200 || _dragOffset < -screenWidth * 0.2) {
                _nextMonth();
              } else {
                // Snap back
                _pendingDirection = 0;
                _animStartOffset = _dragOffset;
                _monthAnimController.forward(from: 0).then((_) {
                  setState(() => _dragOffset = 0);
                  _monthAnimController.reset();
                });
              }
            },
            behavior: HitTestBehavior.opaque,
            child: AnimatedBuilder(
              animation: _monthAnimController,
              builder: (context, child) {
                final offset = _currentOffset;
                final opacity = (1.0 - (offset.abs() / MediaQuery.of(context).size.width)).clamp(0.3, 1.0);
                return Transform.translate(
                  offset: Offset(offset, 0),
                  child: Opacity(
                    opacity: opacity,
                    child: child,
                  ),
                );
              },
              child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: _dayLabels
                        .map((l) => Expanded(
                              child: Center(
                                child: Text(
                                  l,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: AppColors.textTertiary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),
                ...rows.map((row) => Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      child: Row(
                        children: row.map((day) {
                          if (day == null) {
                            return const Expanded(child: SizedBox(height: 44));
                          }
                          final today = _isToday(day);
                          final selected = _isSelected(day);
                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _selected = day);
                              },
                              child: SizedBox(
                                height: 44,
                                child: Center(
                                  child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: selected
                                          ? AppColors.primary
                                          : Colors.transparent,
                                      border: today && !selected
                                          ? Border.all(
                                              color: AppColors.primary,
                                              width: 1.5,
                                            )
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${day.day}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: selected || today
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: selected
                                                  ? Colors.white
                                                  : today
                                                      ? AppColors.primary
                                                      : day.isAfter(DateTime.now())
                                                          ? AppColors.textPrimary.withValues(alpha: 0.3)
                                                          : AppColors.textPrimary,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    )),
                const SizedBox(height: 8),
              ],
            ),
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
          if (_isAnimating && _slideIn != null && _animController.value > 0.45) {
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

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final selectedDate = ref.watch(selectedDateProvider);
    final dateKey = _dateKey(selectedDate);
    final log = ref.watch(medicationLogProvider);
    final takenSet = log[dateKey] ?? {};

    return ListView.builder(
      padding: EdgeInsets.only(left: spacing.m, right: spacing.m, top: spacing.s, bottom: spacing.m),
      itemCount: medications.length + 1,
      itemBuilder: (context, index) {
        if (index == medications.length) {
          return Padding(
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
          );
        }

        final med = medications[index];
        final taken = takenSet.contains(med.id);
        return _DailyMedCard(
          medication: med,
          taken: taken,
          onTap: () {
            ref.read(medicationLogProvider.notifier).toggle(dateKey, med.id);
          },
          onEdit: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AddMedicationPage(existing: med),
              ),
            );
          },
          onDelete: () {
            ref.read(medicationListProvider.notifier).remove(med.id);
          },
        );
      },
    );
  }
}

// -- Single daily medication card --

class _DailyMedCard extends StatelessWidget {
  final Medication medication;
  final bool taken;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DailyMedCard({
    required this.medication,
    required this.taken,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Slidable(
        key: ValueKey(medication.id),
        startActionPane: ActionPane(
          motion: const BehindMotion(),
          extentRatio: 0.2,
          children: [
            CustomSlidableAction(
              onPressed: (_) => onEdit(),
              backgroundColor: Colors.transparent,
              padding: EdgeInsets.zero,
              child: _SlidableAnimatedAction(
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
              child: _SlidableAnimatedAction(
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
            height: 68,
            padding: const EdgeInsets.only(left: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: taken ? AppColors.success.withValues(alpha: 0.3) : Colors.white,
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
                // Medication form icon
                SvgPicture.asset(
                  medication.form == MedicationForm.tablet
                      ? 'assets/healthicons--pill-1-24px.svg'
                      : 'assets/fluent--pill-24-filled.svg',
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(
                    taken ? AppColors.success : AppColors.primary,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 14),
                // Med name
                Expanded(
                  child: Text(
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
                ),
                // Right side: checkmark or dosage
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: taken
                      ? Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.successContainer,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: AppColors.success,
                          ),
                        )
                      : Text(
                          (medication.dosage != null &&
                                  medication.dosage!.isNotEmpty)
                              ? medication.dosage!
                              : '',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
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
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
