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

  bool _singleMode = false;
  bool _loading = false;
  String? _errorMessage;
  InteractionResult? _pairResult;
  SingleDrugResult? _singleResult;

  @override
  void initState() {
    super.initState();
    // Trigger CSV data loading
    Future.microtask(() => ref.read(drugDataLoadedProvider));
  }

  Future<void> _performCheck() async {
    final d1 = _drug1Controller.text.trim();
    final d2 = _drug2Controller.text.trim();

    if (_singleMode && d1.isEmpty) {
      setState(() => _errorMessage = 'Please enter a drug name');
      return;
    }
    if (!_singleMode && (d1.isEmpty || d2.isEmpty)) {
      setState(() => _errorMessage = 'Please enter both drug names');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
      _pairResult = null;
      _singleResult = null;
    });

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

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final dataState = ref.watch(drugDataLoadedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Interaction Checker'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(spacing.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mode toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('Two Drugs'),
                    selected: !_singleMode,
                    onSelected: (_) => setState(() => _singleMode = false),
                  ),
                  SizedBox(width: spacing.m),
                  ChoiceChip(
                    label: const Text('One Drug'),
                    selected: _singleMode,
                    onSelected: (_) => setState(() => _singleMode = true),
                  ),
                ],
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
                      Text('Loading drug database...'),
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
                label: _singleMode ? 'Drug name' : 'Drug 1',
              ),

              if (!_singleMode) ...[
                SizedBox(height: spacing.m),
                DrugSearchField(
                  controller: _drug2Controller,
                  label: 'Drug 2',
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
                SingleDrugResultCard(result: _singleResult!),

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
    _drug1Controller.dispose();
    _drug2Controller.dispose();
    super.dispose();
  }
}
