import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/medcheck_icons.dart';
import '../../src/features/home/presentation/pages/home_page.dart';
import '../../src/features/interactions/presentation/pages/interaction_checker_page.dart';
import '../../src/features/progress/presentation/pages/progress_page.dart';
import '../../src/features/treatment/presentation/pages/treatment_page.dart';

final selectedTabProvider = StateProvider<int>((ref) => 0);

class MainNavigation extends ConsumerWidget {
  const MainNavigation({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedTabProvider);

    const pages = [
      HomePage(),
      InteractionCheckerPage(),
      ProgressPage(),
      TreatmentPage(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: AppColors.outline.withValues(alpha: 0.08),
              width: 0.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, -6),
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: SafeArea(
          minimum: const EdgeInsets.only(bottom: 4),
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Center(
                    child: _NavigationItem(
                      icon: MedCheckIcons.calendarCheckDuotone,
                      selectedIcon: MedCheckIcons.calendarCheckFill,
                      label: 'Today',
                      isSelected: selectedIndex == 0,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        ref.read(selectedTabProvider.notifier).state = 0;
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: _NavigationItem(
                      icon: MedCheckIcons.warningDiamond,
                      selectedIcon: MedCheckIcons.warningDiamondFill,
                      label: 'Interactions',
                      isSelected: selectedIndex == 1,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        ref.read(selectedTabProvider.notifier).state = 1;
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: _NavigationItem(
                      icon: MedCheckIcons.chartBar,
                      selectedIcon: MedCheckIcons.chartBarFill,
                      label: 'Progress',
                      isSelected: selectedIndex == 2,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        ref.read(selectedTabProvider.notifier).state = 2;
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: _NavigationItem(
                      icon: MedCheckIcons.firstAidKit,
                      selectedIcon: MedCheckIcons.firstAidKitFill,
                      label: 'Treatment',
                      isSelected: selectedIndex == 3,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        ref.read(selectedTabProvider.notifier).state = 3;
                      },
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

class _NavigationItem extends StatefulWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_NavigationItem> createState() => _NavigationItemState();
}

class _NavigationItemState extends State<_NavigationItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.08)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.08, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 60,
      ),
    ]).animate(_controller);

    if (widget.isSelected) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_NavigationItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _controller.forward(from: 0.0);
    } else if (!widget.isSelected && oldWidget.isSelected) {
      _controller.value = 0.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isSelected ? AppColors.primary : AppColors.textTertiary;

    return InkWell(
      onTap: widget.onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: SizedBox(
        width: 80,
        height: 48,
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: widget.isSelected ? _scaleAnimation.value : 1.0,
                child: child,
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: widget.isSelected
                      ? const Duration(milliseconds: 300)
                      : Duration.zero,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.8, end: 1.0)
                            .animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Icon(
                    widget.isSelected ? widget.selectedIcon : widget.icon,
                    key: ValueKey(widget.isSelected),
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight:
                        widget.isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: color,
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
