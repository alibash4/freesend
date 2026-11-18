import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:scroll_animator/scroll_animator.dart';

import 'package:free_send/core/format.dart';
import 'package:free_send/l10n/app_localizations.dart';
import 'package:free_send/models/transfer_record.dart';
import 'package:free_send/state/app_state.dart';
import 'package:free_send/theme/app_icons.dart';
import 'package:free_send/theme/app_theme.dart';
import 'package:free_send/ui/kit/app_page_title.dart';
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
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearHistoryTitle),
        content: Text(l10n.clearHistoryBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.clearHistoryConfirm),
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
    final l10n = AppLocalizations.of(context);

    final totalBytes =
        records.fold<int>(0, (sum, record) => sum + record.bytes);

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        Padding(
          padding: kPagePadding.copyWith(top: AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: AppPageTitle(l10n.history),
              ),
              if (records.isNotEmpty)
                TextButton(
                  onPressed: () => _clear(context),
                  child: Text(l10n.clear),
                ),
            ],
          ),
        ),
        Padding(
          padding: kPagePadding.copyWith(top: AppSpacing.xs),
          child: Text(
            records.isEmpty
                ? l10n.nothingMoved
                : l10n.transfersMoved(records.length, formatBytes(totalBytes)),
            style: theme.textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (records.isEmpty)
          Padding(
            padding: kPagePadding,
            child: EmptyState(
              icon: AppIcons.history,
              title: l10n.noHistoryTitle,
              message: l10n.noHistoryMessage,
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
    final l10n = AppLocalizations.of(context);
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
                  '${isSend ? l10n.sent : l10n.received} · '
                  '${l10n.fileCount(record.fileCount)} · '
                  '${formatSpeed(record.averageBytesPerSecond)}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      formatTimestamp(record.timestamp, l10n),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    if (!record.succeeded)
                      StatusPill(
                        label:
                            record.bytes > 0 ? l10n.interrupted : l10n.failed,
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
