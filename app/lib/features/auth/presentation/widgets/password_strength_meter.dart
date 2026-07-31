import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';

/// The four rules `Validators.password` enforces, as data.
///
/// Deriving the meter from the same list the validator checks is the point of
/// this type. A meter that scores a password by its own rules will sooner or
/// later show four green ticks on something the validator then rejects on
/// submit, and the user has no way to tell which of the two is lying.
enum PasswordRule {
  minLength('Minimal 8 karakter'),
  lowercase('Huruf kecil'),
  uppercase('Huruf besar'),
  digit('Angka');

  const PasswordRule(this.label);

  /// Shown in the checklist. Phrased as the requirement, not as a complaint,
  /// so the list reads the same whether or not it is satisfied.
  final String label;

  bool isMetBy(String value) => switch (this) {
        PasswordRule.minLength => value.length >= 8,
        PasswordRule.lowercase => RegExp(r'[a-z]').hasMatch(value),
        PasswordRule.uppercase => RegExp(r'[A-Z]').hasMatch(value),
        PasswordRule.digit => RegExp(r'[0-9]').hasMatch(value),
      };
}

/// Live feedback on a new password, while it is being typed.
///
/// Register enforces length, case and a digit, and used to say so only by
/// failing on submit - after which the user had to infer which of four rules
/// they had missed from a single error line. The rules are cheap to show and
/// impossible to guess, so they are shown.
///
/// Renders nothing for an empty field: an untouched form should not open
/// covered in unmet requirements.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final met = PasswordRule.values.where((r) => r.isMetBy(password)).length;
    final (label, color) = switch (met) {
      4 => ('Kuat', AppColors.success),
      3 => ('Cukup', AppColors.warning),
      _ => ('Lemah', AppColors.error),
    };

    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.spacing12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // One segment per rule, so the bar and the checklist below it
              // are the same measurement shown twice - a filled segment always
              // has a ticked rule to explain it.
              for (var i = 0; i < PasswordRule.values.length; i++) ...[
                if (i > 0) const SizedBox(width: AppDimensions.spacing4),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: AppDimensions.spacing4,
                    decoration: BoxDecoration(
                      color: i < met ? color : AppColors.border,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusRound),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: AppDimensions.spacing12),
              Text(
                label,
                style: AppTextStyles.labelMedium.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing8),
          Wrap(
            spacing: AppDimensions.spacing12,
            runSpacing: AppDimensions.spacing4,
            children: [
              for (final rule in PasswordRule.values)
                _RuleChip(rule: rule, isMet: rule.isMetBy(password)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RuleChip extends StatelessWidget {
  const _RuleChip({required this.rule, required this.isMet});

  final PasswordRule rule;
  final bool isMet;

  @override
  Widget build(BuildContext context) {
    final color = isMet ? AppColors.success : AppColors.textTertiary;

    return Semantics(
      // The tick is the whole message here, and an icon carries no text. Said
      // aloud, an unlabelled checklist is four requirements with no indication
      // of which are done.
      label: '${rule.label}: ${isMet ? 'terpenuhi' : 'belum terpenuhi'}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMet ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: AppDimensions.iconSmall,
            color: color,
          ),
          const SizedBox(width: AppDimensions.spacing4),
          Text(
            rule.label,
            style: AppTextStyles.caption.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
