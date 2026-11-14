import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:scroll_animator/scroll_animator.dart';

import 'package:free_send/core/format.dart';
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
    final hasActive = send.isBusy ||
        receive.phase == ReceivePhase.transferring ||
        receive.phase == ReceivePhase.reviewing;

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        Padding(
          padding: kPagePadding.copyWith(top: AppSpacing.md),
          child: const AppPageTitle('Transfers'),
        ),
        if (hasActive) ...[
          Padding(
            padding: kPagePadding.copyWith(top: AppSpacing.xs),
            child: Text(
              'Live on this device',
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
              title: 'Nothing transferring',
              message:
                  'Start a send or receive and the live transfer, its queue, '
                  'and its controls will appear here.',
            ),
          ),
        Padding(
          padding: kPagePadding.copyWith(top: AppSpacing.xs),
          child: SectionHeader(
            title: 'Recent',
            action: records.isEmpty
                ? null
                : Text(
                    '${formatCount(records.length, 'transfer')} · '
                    '${formatBytes(records.fold<int>(0, (sum, r) => sum + r.bytes))}',
                    style: theme.textTheme.bodySmall,
                  ),
          ),
        ),
        if (records.isEmpty)
          Padding(
            padding: kPagePadding,
             child: EmptyState(
               icon: AppIcons.history,
              title: 'No history yet',
              message:
                  'Finished and cancelled transfers are recorded here, on this '
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
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusPill(
                label: controller.paused
                    ? 'Paused'
                    : controller.hasPeer
                        ? 'Sending to ${controller.peerName ?? 'device'}'
                        : 'Waiting for a device',
                color: controller.paused
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.primary,
                icon: controller.paused ? AppIcons.stop : AppIcons.send,
              ),
              const Spacer(),
              if (controller.peerCount > 1)
                StatusPill(label: '${controller.peerCount} devices'),
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
                  label: 'Speed',
                  value: formatSpeed(controller.speedBytesPerSecond),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Remaining',
                  value: formatEta(
                    controller.remainingBytes,
                    controller.speedBytesPerSecond,
                  ),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Files',
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
              subtitle: _statusLabel(item),
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
                    label: const Text('Resume'),
                  ),
                )
              else
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: controller.canPause
                        ? controller.pauseTransfer
                        : null,
                    icon: Icon(AppIcons.stop, size: 17),
                    label: const Text('Pause'),
                  ),
                ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: controller.cancelSession,
                  icon: Icon(AppIcons.close, size: 17),
                  label: const Text('Stop'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _statusLabel(TransferItem item) {
    return switch (item.status) {
      TransferStatus.done =>
        '${formatBytes(item.size)} · sent',
      TransferStatus.paused =>
        '${formatBytes(item.transferred)} of ${formatBytes(item.size)} · paused',
      TransferStatus.failed => 'Failed',
      TransferStatus.active =>
        '${formatBytes(item.transferred)} of ${formatBytes(item.size)}',
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
    final manifest = controller.manifest;
    if (manifest == null) return const SizedBox.shrink();
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusPill(
            label: 'Incoming offer',
            icon: AppIcons.download,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            manifest.hostName,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 2),
          Text(
            '${formatCount(manifest.items.length, 'file')} · '
            '${formatBytes(manifest.totalBytes)} · review in Receive',
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
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusPill(
                label: controller.isPaused
                    ? 'Paused by sender'
                    : 'Receiving from ${controller.manifest?.hostName ?? 'device'}',
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
                  label: 'Speed',
                  value: formatSpeed(controller.speedBytesPerSecond),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Remaining',
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
                  '${formatBytes(item.size)} · saved',
                TransferStatus.paused =>
                  '${formatBytes(item.transferred)} of ${formatBytes(item.size)} · paused',
                TransferStatus.failed => 'Failed',
                TransferStatus.active =>
                  '${formatBytes(item.transferred)} of ${formatBytes(item.size)}',
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
            label: const Text('Cancel transfer'),
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
                  '${isSend ? 'Sent' : 'Received'} · '
                  '${formatCount(record.fileCount, 'file')} · '
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