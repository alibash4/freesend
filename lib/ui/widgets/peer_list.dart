import 'package:material_ui/material_ui.dart';

import 'package:free_send/core/format.dart';
import 'package:free_send/l10n/app_localizations.dart';
import 'package:free_send/models/peer_info.dart';
import 'package:free_send/models/transfer_item.dart';
import 'package:free_send/theme/app_icons.dart';
import 'package:free_send/theme/app_theme.dart';
import 'package:free_send/ui/widgets/common.dart';

/// Connected receivers in a group session, with independent progress.
class PeerList extends StatelessWidget {
  const PeerList({super.key, required this.peers});

  final List<PeerInfo> peers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l10n.receivers, style: theme.textTheme.titleSmall),
            const Spacer(),
            Text(
              l10n.deviceCount(peers.length),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final peer in peers) ...[
          if (peer != peers.first)
            Divider(height: 1, color: theme.colorScheme.hairline),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        peer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${(peer.progress * 100).round()}%',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: peer.progress,
                    minHeight: 4,
                    backgroundColor: theme.colorScheme.surfaceContainerHigh,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.peerProgress(
                          formatBytes(peer.transferred),
                          formatBytes(peer.totalBytes),
                          '${peer.completedFiles}',
                          '${peer.selectedIds.length}',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    _PeerState(peer: peer),
                  ],
                ),
                if (peer.currentFile != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    l10n.sendingFile(peer.currentFile ?? ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PeerState extends StatelessWidget {
  const _PeerState({required this.peer});

  final PeerInfo peer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final label = switch (peer.status) {
      TransferStatus.done => l10n.done,
      TransferStatus.failed => l10n.failedTag,
      TransferStatus.active =>
        peer.currentFile == null ? l10n.sendingTag : l10n.activeTag,
      TransferStatus.paused => l10n.paused,
      TransferStatus.pending => l10n.connectingTag,
    };
    final color = switch (peer.status) {
      TransferStatus.done => AppColors.success,
      TransferStatus.failed => theme.colorScheme.error,
      TransferStatus.active => theme.colorScheme.primary,
      TransferStatus.paused => theme.colorScheme.onSurfaceVariant,
      TransferStatus.pending => theme.colorScheme.onSurfaceVariant,
    };
    return StatusPill(
      label: label,
      icon: peer.status == TransferStatus.failed
          ? AppIcons.alert
          : peer.status == TransferStatus.done
              ? AppIcons.check
              : AppIcons.device,
      color: color,
    );
  }
}
