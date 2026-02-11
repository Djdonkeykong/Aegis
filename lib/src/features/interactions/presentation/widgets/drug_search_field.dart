import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers/interaction_providers.dart';

class DrugSearchField extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final String label;

  const DrugSearchField({
    super.key,
    required this.controller,
    required this.label,
  });

  @override
  ConsumerState<DrugSearchField> createState() => _DrugSearchFieldState();
}

class _DrugSearchFieldState extends ConsumerState<DrugSearchField> {
  List<String> _suggestions = [];
  bool _showSuggestions = false;

  void _onChanged(String value) {
    if (value.isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }
    final suggestions = ref.read(drugSuggestionsProvider(value));
    setState(() {
      _suggestions = suggestions;
      _showSuggestions = suggestions.isNotEmpty;
    });
  }

  void _selectSuggestion(String suggestion) {
    widget.controller.text = suggestion;
    setState(() {
      _suggestions = [];
      _showSuggestions = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          onChanged: _onChanged,
          decoration: InputDecoration(
            labelText: widget.label,
            prefixIcon: const Icon(Icons.medication_outlined),
            suffixIcon: widget.controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      widget.controller.clear();
                      _onChanged('');
                    },
                  )
                : null,
          ),
        ),
        if (_showSuggestions)
          Container(
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ListTile(
                  dense: true,
                  title: Text(suggestion),
                  leading: const Icon(Icons.medication, size: 18),
                  onTap: () => _selectSuggestion(suggestion),
                );
              },
            ),
          ),
      ],
    );
  }
}
