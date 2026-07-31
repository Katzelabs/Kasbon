import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_dimensions.dart';
import '../../../../shared/modern/modern.dart';
import '../providers/customer_names_provider.dart';

/// A customer name field that suggests names the shop has already used.
///
/// The suggestions are the feature. Typed freely, `customer_name` fragments
/// within weeks - "Bu Sri", "bu sri", "Bu Sri " - and each spelling is its own
/// customer to every query that groups by it. Offering what already exists is
/// cheaper than reconciling it later, which is why this ships with the field
/// rather than after it.
///
/// Modelled on `CategoryAutocompleteField`, which solves the same problem for
/// category names. Not reused: that one is typed to `Category` and returns a
/// sealed `CategorySelection` describing whether the text names an existing
/// row, a new one, or nothing. A customer name has no row and no such
/// distinction - every value is just text - so sharing the widget would mean
/// generalising it past what either caller needs.
class CustomerNameField extends ConsumerStatefulWidget {
  const CustomerNameField({
    super.key,
    required this.controller,
    this.label = 'Nama Pelanggan (opsional)',
    this.errorText,
    this.autofocus = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  @override
  ConsumerState<CustomerNameField> createState() => _CustomerNameFieldState();
}

class _CustomerNameFieldState extends ConsumerState<CustomerNameField> {
  final FocusNode _focusNode = FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    setState(() => _hasFocus = _focusNode.hasFocus);
  }

  /// Names worth offering for what is typed so far.
  ///
  /// Filtered here rather than by re-querying per keystroke. The whole list is
  /// a handful of strings a warung has actually used, so a round trip per
  /// character would spend a slow connection to narrow something already in
  /// memory.
  List<String> _matching(List<String> all) {
    final typed = widget.controller.text.trim().toLowerCase();

    final matches = typed.isEmpty
        ? all
        : all
            .where((name) => name.toLowerCase().contains(typed))
            .toList(growable: false);

    // An exact match needs no suggesting - the cashier has already typed it,
    // and a one-item list under the field is just something to dismiss.
    if (matches.length == 1 && matches.first.toLowerCase() == typed) {
      return const [];
    }

    return matches.take(_maxVisibleSuggestions).toList(growable: false);
  }

  static const int _maxVisibleSuggestions = 4;

  void _accept(String name) {
    widget.controller.text = name;
    widget.controller.selection = TextSelection.collapsed(offset: name.length);
    widget.onChanged?.call(name);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final names = ref.watch(customerNamesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ModernTextField(
          controller: widget.controller,
          focusNode: _focusNode,
          label: widget.label,
          errorText: widget.errorText,
          autofocus: widget.autofocus,
          leading: const Icon(Icons.person_outline),
          textCapitalization: TextCapitalization.words,
          // Enter must not reach the dialog's shortcut and commit the sale
          // while the cashier is halfway through a name.
          textInputAction: TextInputAction.done,
          onChanged: (value) {
            setState(() {});
            widget.onChanged?.call(value);
          },
        ),

        // Suggestions only while the field is being used. A list hanging under
        // an unfocused field in a dialog this tight is noise, and it would push
        // the Bayar button down for a cashier who has already moved on.
        if (_hasFocus)
          names.maybeWhen(
            data: (all) {
              final matches = _matching(all);
              if (matches.isEmpty) return const SizedBox.shrink();
              return _SuggestionList(names: matches, onSelected: _accept);
            },
            // No spinner and no error state. This is a hint, not content: if
            // the names cannot be fetched the cashier types the name, exactly
            // as they did before this field existed.
            orElse: () => const SizedBox.shrink(),
          ),
      ],
    );
  }
}

/// The suggestion chips under the field.
///
/// Wrapped in a [TapRegion] sharing the text field's group, which is what makes
/// the chips tappable at all.
///
/// A TextField unfocuses on pointer-DOWN outside itself - on desktop and web;
/// android and iOS do nothing, which is why this looked fine on a phone. The
/// list is mounted only while the field has focus, so pressing a chip used to
/// unfocus the field, rebuild without the list, and destroy the chip before the
/// pointer came back up. The tap landed on nothing and the name was never
/// filled in.
///
/// `groupId: EditableText` is the default group every TextField registers
/// under, so a press in here reads as inside the field rather than outside it,
/// and no unfocus fires. Tapping anywhere genuinely outside still dismisses as
/// before, and choosing a name still unfocuses deliberately in `_accept`.
class _SuggestionList extends StatelessWidget {
  const _SuggestionList({required this.names, required this.onSelected});

  final List<String> names;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      groupId: EditableText,
      child: Padding(
        padding: const EdgeInsets.only(top: AppDimensions.spacing8),
        child: Wrap(
          spacing: AppDimensions.spacing8,
          runSpacing: AppDimensions.spacing8,
          children: [
            for (final name in names)
              ModernChip(
                label: name,
                size: ModernSize.small,
                // onSelected, not onTap: a chip here is a shortcut that fills
                // the field, so the selected state it reports is transient and
                // ignored - the text field is the source of truth.
                onSelected: (_) => onSelected(name),
              ),
          ],
        ),
      ),
    );
  }
}
