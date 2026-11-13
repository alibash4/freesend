import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:scroll_animator/scroll_animator.dart';

import 'package:free_send/core/format.dart';
import 'package:free_send/models/transfer_record.dart';
import 'package:free_send/state/app_state.dart';
import 'package:free_send/theme/app_icons.dart';
import 'package:free_send/theme/app_theme.dart';
import 'package:free_send/ui/shell.dart';
import 'package:free_send/ui/widgets/common.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final ScrollController _scrollController = AnimatedScrollController(
    animationFactory: const ChromiumEaseInOut(),
  );

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _clear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text(
          'This only removes the local list of past transfers. Received files '
          'stay on disk.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<AppState>().clearHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = context.watch<AppState>();
    final records = appState.history;

    final totalBytes = records.fold<int>(0, (sum, record) => sum + record.bytes);

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        Padding(
          padding: kPagePadding.copyWith(top: AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Text('History', style: theme.textTheme.headlineSmall),
              ),
              if (records.isNotEmpty)
                TextButton(
                  onPressed: () => _clear(context),
                  child: const Text('Clear'),
                ),
            ],
          ),
        ),
        Padding(
          padding: kPagePadding.copyWith(top: AppSpacing.xs),
          child: Text(
            records.isEmpty
                ? 'Nothing has moved yet.'
                : '${formatCount(records.length, 'transfer')} · '
                    '${formatBytes(totalBytes)} moved',
            style: theme.textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (records.isEmpty)
          const Padding(
            padding: kPagePadding,
            child: EmptyState(
              icon: AppIcons.history,
              title: 'No history',
              message:
                  'Completed and cancelled transfers are recorded here, on this '
                  'device only.',
            ),
          )
        else
          Padding(
            padding: kPagePadding,
            child: Column(
              children: [
                for (var i = 0; i < records.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, color: theme.colorScheme.hairline),
                  _RecordCard(record: records[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record});

  final TransferRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isSend = record.direction == TransferDirection.send;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: record.succeeded
                  ? AppColors.success.withValues(alpha: 0.12)
                  : scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isSend ? AppIcons.send : AppIcons.receive,
              size: 16,
              color: record.succeeded
                  ? AppColors.success
                  : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.peerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${isSend ? 'Sent' : 'Received'} · '
                  '${formatCount(record.fileCount, 'file')} · '
                  '${formatSpeed(record.averageBytesPerSecond)}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      formatTimestamp(record.timestamp),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    if (!record.succeeded)
                      StatusPill(
                        label: record.bytes > 0 ? 'Interrupted' : 'Failed',
                        color: scheme.error,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            formatBytes(record.bytes),
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
