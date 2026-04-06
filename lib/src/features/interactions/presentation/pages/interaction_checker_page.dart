import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../domain/models/interaction_result.dart';
import '../../domain/providers/interaction_providers.dart';
import '../widgets/drug_search_field.dart';
import '../widgets/interaction_result_card.dart';

class InteractionCheckerPage extends ConsumerStatefulWidget {
  const InteractionCheckerPage({super.key});

  @override
  ConsumerState<InteractionCheckerPage> createState() =>
      _InteractionCheckerPageState();
}

class _InteractionCheckerPageState
    extends ConsumerState<InteractionCheckerPage> {
  final _drug1Controller = TextEditingController();
  final _drug2Controller = TextEditingController();
  final _scrollController = ScrollController();

  bool _singleMode = false;
  bool _loading = false;
  String? _errorMessage;
  InteractionResult? _pairResult;
  SingleDrugResult? _singleResult;
  final Set<SeverityLevel> _expandedSingleDrugSections = {
    SeverityLevel.high,
  };

  @override
  void initState() {
    super.initState();
    _drug1Controller.addListener(_handleDrugInputChanged);
    _drug2Controller.addListener(_handleDrugInputChanged);
    // Trigger CSV data loading
    Future.microtask(() => ref.read(drugDataLoadedProvider));
  }

  Future<void> _performCheck() async {
    final d1 = _drug1Controller.text.trim();
    final d2 = _drug2Controller.text.trim();

    if (_singleMode && d1.isEmpty) {
      setState(() => _errorMessage = 'Please enter a medication name');
      return;
    }
    if (!_singleMode && (d1.isEmpty || d2.isEmpty)) {
      setState(() => _errorMessage = 'Please enter both medication names');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
      if (_singleMode) {
        _singleResult = null;
      } else {
        _pairResult = null;
      }
    });

    await _scrollToTop();

    try {
      final drugService = ref.read(drugServiceProvider);
      if (_singleMode) {
        final result = await drugService.checkOneDrug(d1);
        setState(() => _singleResult = result);
      } else {
        final result = await drugService.checkTwoDrugs(d1, d2);
        setState(() => _pairResult = result);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _openTwoDrugCheckFromSingle(String interactionDrug) async {
    final primaryDrug =
        _singleResult?.recognizedDrug ?? _drug1Controller.text.trim();
    if (primaryDrug.isEmpty) return;

    final cleanedInteractionDrug =
        interactionDrug.replaceAll(RegExp(r'\s*\(.*\)\s*$'), '').trim();

    _drug1Controller.text = primaryDrug;
    _drug2Controller.text = cleanedInteractionDrug;

    _setMode(false);

    await _performCheck();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final dataState = ref.watch(drugDataLoadedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Interaction Checker'),
        actions: [
          IconButton(
            tooltip: 'Clear search',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _loading ? null : _clearSearchState,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          key: const PageStorageKey('interaction-checker-scroll'),
          controller: _scrollController,
          padding: EdgeInsets.all(spacing.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mode toggle
              _ModeToggle(
                singleMode: _singleMode,
                onSelectSingle: () => _setMode(true),
                onSelectPair: () => _setMode(false),
              ),

              SizedBox(height: spacing.l),

              // Data loading indicator
              dataState.when(
                data: (_) => const SizedBox.shrink(),
                loading: () => Padding(
                  padding: EdgeInsets.only(bottom: spacing.m),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Loading medication database...'),
                    ],
                  ),
                ),
                error: (error, _) => Padding(
                  padding: EdgeInsets.only(bottom: spacing.m),
                  child: Card(
                    color: AppColors.errorContainer,
                    child: Padding(
                      padding: EdgeInsets.all(spacing.m),
                      child: Text(
                        'Failed to load database: $error',
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  ),
                ),
              ),

              // Search fields
              DrugSearchField(
                controller: _drug1Controller,
                label: _singleMode ? 'Medication name' : 'Medication 1',
              ),

              if (!_singleMode) ...[
                SizedBox(height: spacing.m),
                DrugSearchField(
                  controller: _drug2Controller,
                  label: 'Medication 2',
                ),
              ],

              SizedBox(height: spacing.l),

              // Check button
              FilledButton.icon(
                onPressed: _loading ? null : _performCheck,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.search),
                label: Text(
                  _singleMode ? 'Check Interactions' : 'Check Combination',
                ),
              ),

              SizedBox(height: spacing.l),

              // Error message
              if (_errorMessage != null)
                Card(
                  color: AppColors.warningContainer,
                  child: Padding(
                    padding: EdgeInsets.all(spacing.m),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.warning),
                    ),
                  ),
                ),

              // Results
              if (_pairResult != null)
                InteractionResultCard(result: _pairResult!),

              if (_singleResult != null)
                SingleDrugResultCard(
                  result: _singleResult!,
                  onInteractionTap: _openTwoDrugCheckFromSingle,
                  expandedSections: _expandedSingleDrugSections,
                  onSectionExpansionChanged: _handleSingleDrugSectionToggle,
                ),

              SizedBox(height: spacing.xxl),

              // Disclaimer
              Text(
                AppConstants.disclaimer,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _drug1Controller.removeListener(_handleDrugInputChanged);
    _drug2Controller.removeListener(_handleDrugInputChanged);
    _drug1Controller.dispose();
    _drug2Controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _handleSingleDrugSectionToggle(SeverityLevel severity, bool expanded) {
    setState(() {
      if (expanded) {
        _expandedSingleDrugSections.add(severity);
      } else {
        _expandedSingleDrugSections.remove(severity);
      }
    });
  }

  void _handleDrugInputChanged() {
    if (_loading) return;
    if (_pairResult == null && _singleResult == null && _errorMessage == null) {
      return;
    }

    setState(() {
      _pairResult = null;
      _singleResult = null;
      _errorMessage = null;
    });
  }

  void _setMode(bool singleMode) {
    if (_singleMode == singleMode) return;

    setState(() {
      _singleMode = singleMode;
      _pairResult = null;
      _singleResult = null;
      _errorMessage = null;
    });
  }

  void _clearSearchState() {
    _drug1Controller.clear();
    _drug2Controller.clear();

    setState(() {
      _pairResult = null;
      _singleResult = null;
      _errorMessage = null;
      _expandedSingleDrugSections
        ..clear()
        ..add(SeverityLevel.high);
    });
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.singleMode,
    required this.onSelectSingle,
    required this.onSelectPair,
  });

  final bool singleMode;
  final VoidCallback onSelectSingle;
  final VoidCallback onSelectPair;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.outline),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeToggleButton(
              label: 'Two Medications',
              icon: Icons.compare_arrows_rounded,
              selected: !singleMode,
              onTap: onSelectPair,
            ),
          ),
          SizedBox(width: spacing.xs),
          Expanded(
            child: _ModeToggleButton(
              label: 'One Medication',
              icon: Icons.medication_rounded,
              selected: singleMode,
              onTap: onSelectSingle,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeToggleButton extends StatelessWidget {
  const _ModeToggleButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          color: selected ? AppColors.onPrimary : AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.outline,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.22),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : const [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color:
                      selected ? AppColors.onPrimary : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle,
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
