import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/app_dimensions.dart';
import '../../../../shared/modern/modern.dart';
import '../../../../config/routes/app_router.dart';

/// Main Dev Tools screen with navigation to dev features.
///
/// IMPORTANT: This is for development use only.
class DevToolsScreen extends StatelessWidget {
  const DevToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar.withActions(
        title: 'Dev Tools',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Warning banner
            Container(
              padding: const EdgeInsets.all(AppDimensions.spacing16),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                border: Border.all(color: Colors.amber),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.amber),
                  const SizedBox(width: AppDimensions.spacing12),
                  Expanded(
                    child: Text(
                      'Development tools only. Do not use in production.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.amber.shade800,
                          ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppDimensions.spacing24),

            // Dev Tools Grid
            _DevToolCard(
              icon: Icons.storage,
              title: 'Seed Data',
              description: 'Seed sample products and transactions for testing',
              color: Colors.pink,
              onTap: () => context.go(AppRoutes.devSeed),
            ),

            const SizedBox(height: AppDimensions.spacing16),

            _DevToolCard(
              icon: Icons.palette,
              title: 'Design System',
              description: 'Preview all UI components and design tokens',
              color: Colors.purple,
              onTap: () => context.go(AppRoutes.designSystem),
            ),

            const SizedBox(height: AppDimensions.spacing16),

            _DevToolCard(
              icon: Icons.info_outline,
              title: 'App Info',
              description: 'View app version, build info, and diagnostics',
              color: Colors.blue,
              onTap: () {
                ModernToast.info(context, 'Coming soon...');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DevToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _DevToolCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ModernCard.outlined(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacing16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: AppDimensions.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
