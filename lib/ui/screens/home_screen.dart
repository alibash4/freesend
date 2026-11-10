import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:free_send/core/format.dart';
import 'package:free_send/core/platform_env.dart';
import 'package:free_send/models/transfer_record.dart';
import 'package:free_send/state/app_state.dart';
import 'package:free_send/theme/app_icons.dart';
import 'package:free_send/theme/app_theme.dart';
import 'package:free_send/ui/screens/receive_screen.dart';
import 'package:free_send/ui/screens/send_screen.dart';
import 'package:free_send/ui/shell.dart';
import 'package:free_send/ui/widgets/brand_mark.dart';
import 'package:free_send/ui/widgets/common.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = context.watch<AppState>();
    final recent = appState.history.take(3).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        Padding(
          padding: kPagePadding.copyWith(top: AppSpacing.md),
          child: Row(
            children: [
              const BrandMark(),
              const SizedBox(width: AppSpacing.md),
              // The title takes what is left; on a narrow page it wraps rather
              // than pushing past the edge.
              const Expanded(child: BrandTitle(subtitle: true)),
            ],
          ),
        ),
        Padding(
          padding: kPagePadding.copyWith(top: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Move files over the link, not the internet.',
                style: theme.textTheme.headlineMedium?.copyWith(
                  height: 1.15,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Free Send pairs two devices on a direct Wi-Fi hotspot and '
                'streams files between them at link speed. Nothing is uploaded.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: kPagePadding.copyWith(top: AppSpacing.lg),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                ActionCard(
                  title: 'Send',
                  description: PlatformEnv.canCreateHotspot
                      ? 'Create a hotspot and share the files you pick.'
                      : 'Share over your current network from this device.',
                  icon: AppIcons.send,
                  highlighted: true,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const SendScreen()),
                  ),
                  trailing: Icon(
                    AppIcons.forward,
                    size: 16,
                    color: theme.colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.55,
                    ),
                  ),
                ),
                ActionCard(
                  title: 'Receive',
                  description: 'Find a nearby session and pull files to disk.',
                  icon: AppIcons.receive,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ReceiveScreen(),
                    ),
                  ),
                ),
              ];
              if (constraints.maxWidth > 520) {
                // The cards are height-independent in a Row; stretch only
                // makes sense when the Row has a bounded height.
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: cards[1]),
                    ],
                  ),
                );
              }
              return Column(
                children: [
                  cards[0],
                  const SizedBox(height: AppSpacing.md),
                  cards[1],
                ],
              );
            },
          ),
        ),
        Padding(
          padding: kPagePadding.copyWith(top: AppSpacing.xl),
          child: const _HowItWorks(),
        ),
        Padding(
          padding: kPagePadding.copyWith(top: AppSpacing.xl),
          child: SectionHeader(
            title: 'Recent activity',
            action: recent.isEmpty
                ? null
                : Text(
                    formatCount(appState.history.length, 'transfer'),
                    style: theme.textTheme.bodySmall,
                  ),
          ),
        ),
        if (recent.isEmpty)
          const Padding(
            padding: kPagePadding,
            child: EmptyState(
              icon: AppIcons.inbox,
              title: 'No transfers yet',
              message:
                  'Your completed and cancelled transfers will appear here.',
            ),
          )
        else
          Padding(
            padding: kPagePadding,
            child: Column(
              children: [
                for (var i = 0; i < recent.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: theme.colorScheme.hairline,
                    ),
                  _RecentRow(record: recent[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    const steps = [
      (AppIcons.hotspot, 'Connect', 'One side opens a hotspot'),
      (AppIcons.zap, 'Stream', 'Files cross the local link'),
      (AppIcons.checkCircle, 'Done', 'Saved straight to disk'),
    ];
    final theme = Theme.of(context);
    // Three steps, set straight on the page: no panel, just an accent glyph
    // and a hairline between the columns.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Container(
              width: 1,
              height: 52,
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              color: theme.colorScheme.hairline,
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  steps[i].$1,
                  size: 18,
                  color: theme.colorScheme.accentText,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  steps[i].$2,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  steps[i].$3,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.record});

  final TransferRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isSend = record.direction == TransferDirection.send;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              isSend ? AppIcons.send : AppIcons.receive,
              size: 15,
              color: record.succeeded ? scheme.accentText : scheme.error,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${isSend ? 'Sent to' : 'Received from'} ${record.peerName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatCount(record.fileCount, 'file')} · '
                  '${formatTimestamp(record.timestamp)}',
                  style: theme.textTheme.bodySmall,
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
