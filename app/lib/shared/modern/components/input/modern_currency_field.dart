import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../utils/modern_variants.dart';

/// A Modern-styled currency input field for Indonesian Rupiah
///
/// Example:
/// ```dart
/// ModernCurrencyField(
///   label: 'Harga Jual',
///   hint: '0',
///   onChanged: (value) => print('Value: $value'),
/// )
/// ```
class ModernCurrencyField extends StatefulWidget {
  const ModernCurrencyField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint = '0',
    this.helperText,
    this.errorText,
    this.variant = ModernInputVariant.outline,
    this.size = ModernSize.medium,
    this.currencySymbol = 'Rp',
    this.enabled = true,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.textInputAction,
    this.initialValue,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String hint;
  final String? helperText;
  final String? errorText;
  final ModernInputVariant variant;
  final ModernSize size;
  final String currencySymbol;
  final bool enabled;
  final bool autofocus;
  final ValueChanged<int>? onChanged;
  final ValueChanged<int>? onSubmitted;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final int? initialValue;

  @override
  State<ModernCurrencyField> createState() => _ModernCurrencyFieldState();
}

class _ModernCurrencyFieldState extends State<ModernCurrencyField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    if (widget.initialValue != null && _controller.text.isEmpty) {
      final formatted = _CurrencyInputFormatter()._formatNumber(widget.initialValue!);
      _controller.text = formatted;
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  int _parseValue(String text) {
    final cleanText = text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(cleanText) ?? 0;
  }

  void _onChanged(String value) {
    final intValue = _parseValue(value);
    widget.onChanged?.call(intValue);
  }

  bool get _hasError => widget.errorText != null && widget.errorText!.isNotEmpty;

  InputDecoration get _decoration {
    return InputDecoration(
      labelText: widget.label,
      hintText: widget.hint,
      helperText: widget.helperText,
      errorText: widget.errorText,
      prefixText: '${widget.currencySymbol} ',
      prefixStyle: AppTextStyles.priceMedium.copyWith(
        color: _hasError ? AppColors.error : AppColors.textSecondary,
      ),
      filled: widget.variant == ModernInputVariant.filled,
      fillColor: widget.variant == ModernInputVariant.filled
          ? AppColors.surfaceVariant
          : null,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing16,
        vertical: AppDimensions.spacing12,
      ),
      border: _getBorder(hasError: false, focused: false),
      enabledBorder: _getBorder(hasError: false, focused: false),
      focusedBorder: _getBorder(hasError: false, focused: true),
      errorBorder: _getBorder(hasError: true, focused: false),
      focusedErrorBorder: _getBorder(hasError: true, focused: true),
      disabledBorder: _getDisabledBorder(),
      labelStyle: AppTextStyles.bodyMedium.copyWith(
        color: _hasError ? AppColors.error : AppColors.textSecondary,
      ),
      hintStyle: AppTextStyles.priceMedium.copyWith(
        color: AppColors.textTertiary,
      ),
      helperStyle: AppTextStyles.bodySmall.copyWith(
        color: AppColors.textSecondary,
      ),
      errorStyle: AppTextStyles.bodySmall.copyWith(
        color: AppColors.error,
      ),
    );
  }

  InputBorder _getBorder({required bool hasError, required bool focused}) {
    final color = hasError
        ? AppColors.error
        : focused
            ? AppColors.primary
            : AppColors.border;
    final width = focused ? 2.0 : 1.0;

    switch (widget.variant) {
      case ModernInputVariant.outline:
      case ModernInputVariant.filled:
        return OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          borderSide: BorderSide(color: color, width: width),
        );
      case ModernInputVariant.underline:
        return UnderlineInputBorder(
          borderSide: BorderSide(color: color, width: width),
        );
    }
  }

  InputBorder _getDisabledBorder() {
    switch (widget.variant) {
      case ModernInputVariant.outline:
      case ModernInputVariant.filled:
        return OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        );
      case ModernInputVariant.underline:
        return const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.border, width: 1),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      keyboardType: TextInputType.number,
      textInputAction: widget.textInputAction ?? TextInputAction.done,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        _CurrencyInputFormatter(),
      ],
      onChanged: _onChanged,
      onFieldSubmitted: (value) {
        widget.onSubmitted?.call(_parseValue(value));
      },
      validator: widget.validator,
      style: AppTextStyles.priceMedium,
      decoration: _decoration,
    );
  }
}

/// Input formatter for Indonesian currency format (thousands separator with dot)
class _CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final cleanText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final value = int.tryParse(cleanText) ?? 0;

    if (value == 0) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final formatted = _formatNumber(value);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatNumber(int number) {
    final chars = number.toString().split('').reversed.toList();
    final result = <String>[];
    for (var i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) {
        result.add('.');
      }
      result.add(chars[i]);
    }
    return result.reversed.join();
  }
}
