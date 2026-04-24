import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../categories/domain/entities/category.dart';

/// Represents the user's category selection state
sealed class CategorySelection {
  const CategorySelection();
}

/// User selected an existing category from the list
class ExistingCategory extends CategorySelection {
  final Category category;
  const ExistingCategory(this.category);
}

/// User typed a new category name not in the list
class NewCategoryName extends CategorySelection {
  final String name;
  const NewCategoryName(this.name);
}

/// No category selected
class NoCategory extends CategorySelection {
  const NoCategory();
}

/// A hybrid autocomplete field that lets users select an existing category
/// or type a new category name to create one on-the-fly.
class CategoryAutocompleteField extends StatefulWidget {
  const CategoryAutocompleteField({
    super.key,
    required this.categories,
    required this.onChanged,
    this.initialCategory,
  });

  final List<Category> categories;
  final Category? initialCategory;
  final ValueChanged<CategorySelection> onChanged;

  @override
  State<CategoryAutocompleteField> createState() =>
      _CategoryAutocompleteFieldState();
}

class _CategoryAutocompleteFieldState
    extends State<CategoryAutocompleteField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialCategory?.name ?? '',
    );
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(CategoryAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Pre-populate when initialCategory becomes available (edit mode)
    if (!_initialized &&
        widget.initialCategory != null &&
        oldWidget.initialCategory == null) {
      _controller.text = widget.initialCategory!.name;
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      widget.onChanged(const NoCategory());
      return;
    }

    // Check if it matches an existing category (case-insensitive)
    final match = widget.categories
        .where((c) => c.name.toLowerCase() == trimmed.toLowerCase())
        .firstOrNull;

    if (match != null) {
      widget.onChanged(ExistingCategory(match));
    } else {
      widget.onChanged(NewCategoryName(trimmed));
    }
  }

  void _selectCategory(Category category) {
    _controller.text = category.name;
    _focusNode.unfocus();
    widget.onChanged(ExistingCategory(category));
  }

  void _selectNewCategory(String name) {
    _controller.text = name;
    _focusNode.unfocus();
    widget.onChanged(NewCategoryName(name));
  }

  void _clear() {
    _controller.clear();
    widget.onChanged(const NoCategory());
  }

  List<Category> _filterCategories(String query) {
    if (query.trim().isEmpty) return widget.categories;
    final lower = query.toLowerCase();
    return widget.categories
        .where((c) => c.name.toLowerCase().contains(lower))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<Category>(
      textEditingController: _controller,
      focusNode: _focusNode,
      optionsBuilder: (textEditingValue) {
        return _filterCategories(textEditingValue.text);
      },
      displayStringForOption: (category) => category.name,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          onChanged: _onTextChanged,
          textCapitalization: TextCapitalization.words,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            labelText: 'Kategori',
            hintText: 'Pilih atau ketik kategori baru',
            prefixIcon: const Icon(Icons.category_outlined),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: _clear,
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacing16,
              vertical: AppDimensions.spacing12,
            ),
            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusMedium),
              borderSide:
                  const BorderSide(color: AppColors.border, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusMedium),
              borderSide:
                  const BorderSide(color: AppColors.border, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusMedium),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 2),
            ),
            labelStyle: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final query = _controller.text.trim();
        final hasExactMatch = widget.categories
            .any((c) => c.name.toLowerCase() == query.toLowerCase());
        final showCreateOption = query.isNotEmpty && !hasExactMatch;

        return Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Material(
              elevation: 4,
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusMedium),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMedium),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    children: [
                      ...options.map((category) {
                        return ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.label_outline,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                          title: Text(
                            category.name,
                            style: AppTextStyles.bodyMedium,
                          ),
                          onTap: () {
                            _selectCategory(category);
                          },
                        );
                      }),
                      if (showCreateOption)
                        ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.add_circle_outline,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          title: Text(
                            '+ Buat "$query"',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onTap: () {
                            _selectNewCategory(query);
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
