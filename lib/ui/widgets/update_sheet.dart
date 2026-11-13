import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:scroll_animator/scroll_animator.dart';

import 'package:free_send/core/format.dart';
import 'package:free_send/services/update/update_info.dart';
import 'package:free_send/state/update_controller.dart';
import 'package:free_send/theme/app_icons.dart';
import 'package:free_send/theme/app_theme.dart';
import 'package:free_send/ui/widgets/common.dart';

/// Modal that shows the release notes and walks the user through installing.
///
/// Opened by the update controller when a newer release is found; the sheet
/// itself owns no state beyond what the controller exposes.
class UpdateSheet extends StatelessWidget {
  const UpdateSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const UpdateSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = context.watch<UpdateController>();
    final update = controller.update;

    // Long release notes scroll inside the sheet rather than stretching it.
    final body = <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              AppIcons.download,
              size: 20,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  update == null
                      ? 'Checking for updates'
                      : 'Free Send ${update.version} is available',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  update == null
                      ? 'Asking GitLab what is new.'
                      : _subtitle(controller, update),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
      if (update != null && update.changelog.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(title: 'What is new'),
        SurfaceCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            update.changelog,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
          ),
        ),
      ],
      if (controller.message != null) ...[
        const SizedBox(height: AppSpacing.md),
        Text(
          controller.message!,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      ],
      const SizedBox(height: AppSpacing.lg),
      _actions(context, controller),
    ];

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.6,
            ),
            child: AnimatedPrimaryScrollController(
              child: SingleChildScrollView(child: Column(children: body)),
            ),
          ),
        ],
      ),
    );
  }

  String _subtitle(UpdateController controller, UpdateInfo update) {
    if (update.sizeBytes > 0) {
      return '${formatBytes(update.sizeBytes)} · '
          'you are on ${controller.currentVersion}';
    }
    return 'You are on ${controller.currentVersion}';
  }

  Widget _actions(BuildContext context, UpdateController controller) {
    final theme = Theme.of(context);
    return switch (controller.phase) {
      UpdatePhase.checking => const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      UpdatePhase.downloading => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Downloading… ${(controller.progress * 100).round()}%',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: controller.progress,
                minHeight: 4,
              ),
            ),
          ],
        ),
      UpdatePhase.available => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: controller.download,
              icon: const Icon(AppIcons.download, size: 17),
              label: const Text('Download update'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Not now'),
            ),
          ],
        ),
      UpdatePhase.readyToInstall => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: () async {
                await controller.install();
                if (context.mounted) Navigator.of(context).pop();
              },
              icon: const Icon(AppIcons.checkCircle, size: 17),
              label: const Text('Install and restart'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later'),
            ),
          ],
        ),
      UpdatePhase.installing => const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      UpdatePhase.upToDate => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        ),
      UpdatePhase.failed => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: controller.checkManually,
              icon: const Icon(AppIcons.refresh, size: 17),
              label: const Text('Try again'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      UpdatePhase.idle => const SizedBox.shrink(),
    };
  }
}
