import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:scroll_animator/scroll_animator.dart';

import 'package:free_send/core/format.dart';
import 'package:free_send/l10n/app_localizations.dart';
import 'package:free_send/models/transfer_item.dart';
import 'package:free_send/models/transfer_record.dart';
import 'package:free_send/state/app_state.dart';
import 'package:free_send/state/receive_controller.dart';
import 'package:free_send/state/send_controller.dart';
import 'package:free_send/theme/app_icons.dart';
import 'package:free_send/theme/app_theme.dart';
import 'package:free_send/ui/kit/app_page_title.dart';
import 'package:free_send/ui/shell.dart';
import 'package:free_send/ui/widgets/common.dart';
import 'package:free_send/ui/widgets/peer_list.dart';

/// The transfer center: whatever is live right now, plus the local record.
/// It is deliberately a state view, not a second copy of the send/receive
/// flows, so the controls here operate the same controllers.
class TransfersScreen extends StatefulWidget {
  const TransfersScreen({super.key});

  @override
  State<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends State<TransfersScreen> {
  late final ScrollController _scrollController = AnimatedScrollController(
    animationFactory: const ChromiumEaseInOut(),
  );

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final send = context.watch<SendController>();
    final receive = context.watch<ReceiveController>();
    final appState = context.watch<AppState>();
    final records = appState.history;
    final l10n = AppLocalizations.of(context);
    final hasActive = send.isBusy ||
        receive.phase == ReceivePhase.transferring ||
        receive.phase == ReceivePhase.reviewing;

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        Padding(
          padding: kPagePadding.copyWith(top: AppSpacing.md),
          child: AppPageTitle(l10n.transfers),
        ),
        if (hasActive) ...[
          Padding(
            padding: kPagePadding.copyWith(top: AppSpacing.xs),
            child: Text(
              l10n.liveOnThisDevice,
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (send.isBusy)
            Padding(
              padding: kPagePadding,
              child: _SendTransferCard(controller: send),
            ),
          if (receive.phase == ReceivePhase.reviewing)
            Padding(
              padding: kPagePadding,
              child: _ReceiveOfferCard(controller: receive),
            ),
          if (receive.phase == ReceivePhase.transferring)
            Padding(
              padding: kPagePadding,
              child: _ReceiveTransferCard(controller: receive),
            ),
        ] else
          Padding(
            padding: kPagePadding,
             child: EmptyState(
               icon: AppIcons.zap,
               title: l10n.nothingTransferring,
               message: l10n.nothingTransferringMessage,
             ),
          ),
        Padding(
          padding: kPagePadding.copyWith(top: AppSpacing.xs),
          child: SectionHeader(
            title: l10n.recent,
            action: records.isEmpty
                ? null
                : Text(
                    l10n.transfersMoved(
                      records.length,
                      formatBytes(
                        records.fold<int>(0, (sum, r) => sum + r.bytes),
                      ),
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
          ),
        ),
        if (records.isEmpty)
          Padding(
            padding: kPagePadding,
             child: EmptyState(
               icon: AppIcons.history,
               title: l10n.noHistoryYetTitle,
               message: l10n.noHistoryYetMessage,
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
                  _RecordRow(record: records[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _SendTransferCard extends StatelessWidget {
  const _SendTransferCard({required this.controller});

  final SendController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusPill(
                label: controller.paused
                    ? l10n.paused
                    : controller.hasPeer
                        ? l10n.sendingTo(
                            controller.peerName ?? l10n.device,
                          )
                        : l10n.waitingForDevice,
                color: controller.paused
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.primary,
                icon: controller.paused ? AppIcons.stop : AppIcons.send,
              ),
              const Spacer(),
              if (controller.peerCount > 1)
                StatusPill(label: l10n.deviceCount(controller.peerCount)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ProgressRing(
            progress: controller.overallProgress,
            headline: '${(controller.overallProgress * 100).round()}%',
            caption:
                '${formatBytes(controller.sentBytes)} of ${formatBytes(controller.totalBytes)}',
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: l10n.speed,
                  value: formatSpeed(controller.speedBytesPerSecond),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: l10n.remaining,
                  value: formatEta(
                    controller.remainingBytes,
                    controller.speedBytesPerSecond,
                  ),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: l10n.files,
                  value: '${controller.items.length}',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (controller.peers.isNotEmpty) ...[
            PeerList(peers: controller.peers),
            const SizedBox(height: AppSpacing.lg),
          ],
          for (final item in controller.items) ...[
            if (item != controller.items.first)
              Divider(height: 1, color: theme.colorScheme.hairline),
            FileTile(
              name: item.name,
              size: item.size,
              progress: item.progress,
              subtitle: _statusLabel(l10n, item),
              trailing: item.status == TransferStatus.done
                  ? Icon(
                      AppIcons.check,
                      size: 16,
                      color: theme.colorScheme.accentText,
                    )
                  : null,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              if (controller.paused)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: controller.resumeTransfer,
                    icon: Icon(AppIcons.forward, size: 17),
                    label: Text(l10n.resume),
                  ),
                )
              else
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: controller.canPause
                        ? controller.pauseTransfer
                        : null,
                    icon: Icon(AppIcons.stop, size: 17),
                    label: Text(l10n.pause),
                  ),
                ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: controller.cancelSession,
                  icon: Icon(AppIcons.close, size: 17),
                  label: Text(l10n.stop),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _statusLabel(AppLocalizations l10n, TransferItem item) {
    return switch (item.status) {
      TransferStatus.done => l10n.statusSent(formatBytes(item.size)),
      TransferStatus.paused => l10n.statusPaused(
          formatBytes(item.transferred),
          formatBytes(item.size),
        ),
      TransferStatus.failed => l10n.failed,
      TransferStatus.active => l10n.statusActive(
          formatBytes(item.transferred),
          formatBytes(item.size),
        ),
      TransferStatus.pending => formatBytes(item.size),
    };
  }
}

class _ReceiveOfferCard extends StatelessWidget {
  const _ReceiveOfferCard({required this.controller});

  final ReceiveController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final manifest = controller.manifest;
    if (manifest == null) return const SizedBox.shrink();
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusPill(
            label: l10n.incomingOffer,
            icon: AppIcons.download,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            manifest.hostName,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 2),
          Text(
            '${l10n.fileCount(manifest.items.length)} · '
            '${formatBytes(manifest.totalBytes)} · ${l10n.reviewInReceive}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ReceiveTransferCard extends StatelessWidget {
  const _ReceiveTransferCard({required this.controller});

  final ReceiveController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusPill(
                label: controller.isPaused
                    ? l10n.pausedBySender
                    : l10n.receivingFrom(
                        controller.manifest?.hostName ?? l10n.device,
                      ),
                icon: controller.isPaused
                    ? AppIcons.stop
                    : AppIcons.receive,
              ),
              const Spacer(),
              if (controller.isPaused) const PulsingDots(),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ProgressRing(
            progress: controller.overallProgress,
            headline: '${(controller.overallProgress * 100).round()}%',
            caption:
                '${formatBytes(controller.receivedBytes)} of ${formatBytes(controller.totalBytes)}',
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: l10n.speed,
                  value: formatSpeed(controller.speedBytesPerSecond),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: l10n.remaining,
                  value: formatEta(
                    (controller.totalBytes - controller.receivedBytes)
                        .clamp(0, controller.totalBytes),
                    controller.speedBytesPerSecond,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final item in controller.receivedItems) ...[
            if (item != controller.receivedItems.first)
              Divider(height: 1, color: theme.colorScheme.hairline),
            FileTile(
              name: item.name,
              size: item.size,
              progress: item.progress,
              subtitle: switch (item.status) {
                TransferStatus.done =>
                  l10n.statusSaved(formatBytes(item.size)),
                TransferStatus.paused => l10n.statusPaused(
                    formatBytes(item.transferred),
                    formatBytes(item.size),
                  ),
                TransferStatus.failed => l10n.failed,
                TransferStatus.active => l10n.statusActive(
                    formatBytes(item.transferred),
                    formatBytes(item.size),
                  ),
                TransferStatus.pending => formatBytes(item.size),
              },
              trailing: item.status == TransferStatus.done
                  ? Icon(
                      AppIcons.check,
                      size: 16,
                      color: theme.colorScheme.accentText,
                    )
                  : null,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: controller.cancel,
            icon: Icon(AppIcons.stop, size: 17),
            label: Text(l10n.cancelTransfer),
          ),
        ],
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.record});

  final TransferRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isSend = record.direction.name == 'send';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: record.succeeded
                  ? AppColors.success.withValues(alpha: 0.12)
                  : theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isSend ? AppIcons.send : AppIcons.receive,
              size: 16,
              color: record.succeeded
                  ? AppColors.success
                  : theme.colorScheme.onSurfaceVariant,
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
                  '${formatTimestamp(record.timestamp)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
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

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}