import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_dimensions.dart';
import '../../../../config/theme/app_text_styles.dart';
import '../../../../shared/modern/modern.dart';
import '../providers/setup_checklist_provider.dart';

/// "Lengkapi tokomu - 2/4", on the dashboard.
///
/// The other half of onboarding. The wizard blocks on the one thing the app
/// cannot run without - a named shop - and everything else lands here, where
/// it can be done in any order, on any day, or never. A wizard long enough to
/// cover all of it is a wizard people abandon.
///
/// Renders nothing at all when there is nothing left to do, or once dismissed:
/// a permanently ticked checklist is clutter on the screen the user sees most.
class SetupChecklistCard extends ConsumerWidget {
  const SetupChecklistCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(setupChecklistDismissedProvider)) {
      return const SizedBox.shrink();
    }

    return ref.watch(setupChecklistProvider).maybeWhen(
          // No skeleton and no error state: this is a nudge, not content. A
          // dashboard that flashes a placeholder card on every load is worse
          // than one where the nudge simply appears a moment late.
          data: (checklist) => checklist.isComplete
              ? const SizedBox.shrink()
              : _Card(checklist: checklist),
          orElse: () => const SizedBox.shrink(),
        );
  }
}

class _Card extends ConsumerWidget {
  const _Card({required this.checklist});

  final SetupChecklist checklist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacing24),
      child: ModernCard.elevated(
        padding: const EdgeInsets.all(AppDimensions.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Lengkapi tokomu',
                    style: AppTextStyles.h4,
                  ),
                ),
                ModernBadge.info(
                  label: '${checklist.doneCount}/${checklist.items.length}',
                ),
                const SizedBox(width: AppDimensions.spacing4),
                ModernIconButton(
                  icon: Icons.close_rounded,
                  size: ModernSize.small,
                  tooltip: 'Sembunyikan',
                  onPressed: () => ref
                      .read(setupChecklistDismissedProvider.notifier)
                      .dismiss(),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacing4),
            Text(
              'Beberapa langkah kecil supaya toko Anda siap sepenuhnya',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimensions.spacing12),
            for (final item in checklist.items)
              _ChecklistRow(
                item: item,
                onTap: () => context.go(item.route),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.item, required this.onTap});

  final SetupChecklistItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = item.isDone;

    return ModernListTile(
      // A done row stays tappable: "tambah 5 produk" being ticked is not a
      // reason to stop someone adding a sixth.
      onTap: onTap,
      leading: Icon(
        done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
        color: done ? AppColors.success : AppColors.textSecondary,
      ),
      title: Text(
        item.label,
        style: done
            ? AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                decoration: TextDecoration.lineThrough,
              )
            : AppTextStyles.bodyMedium,
      ),
      trailing: done
          ? null
          : const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
    );
  }
}
