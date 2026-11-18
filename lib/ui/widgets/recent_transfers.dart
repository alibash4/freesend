import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'package:free_send/core/format.dart';
import 'package:free_send/l10n/app_localizations.dart';
import 'package:free_send/models/transfer_record.dart';
import 'package:free_send/state/app_state.dart';
import 'package:free_send/theme/app_icons.dart';
import 'package:free_send/theme/app_theme.dart';
import 'package:free_send/ui/kit/app_section_header.dart';
import 'package:free_send/ui/widgets/common.dart';

/// Home-page slice of the local history: the two most recent days of sent
/// transfers, with the first file name used as the row title.
class RecentTransfers extends StatelessWidget {
  const RecentTransfers({super.key});

  @override
  Widget build(BuildContext context) {
    final history = context.watch<AppState>().history;
    final l10n = AppLocalizations.of(context);
    final sent = history
        .where(
          (record) =>
              record.direction == TransferDirection.send && record.succeeded,
        )
        .toList();

    final byDay = <DateTime, List<TransferRecord>>{};
    for (final record in sent) {
      final local = record.timestamp.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      byDay.putIfAbsent(day, () => []).add(record);
    }

    final days = byDay.entries.toList()..sort((a, b) => b.key.compareTo(a.key));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: l10n.recentlyTransferred),
        if (days.isEmpty)
          Padding(
            padding: EdgeInsets.only(top: AppSpacing.xs),
            child: Center(
              child: EmptyState(
                icon: AppIcons.history,
                title: l10n.nothingSentYet,
                message: l10n.nothingSentMessage,
              ),
            ),
          )
        else
          for (final day in days.take(2)) ...[
            _DayHeading(date: day.key),
            for (var i = 0; i < day.value.length; i++) ...[
              _RecentTransferRow(record: day.value[i]),
              if (i < day.value.length - 1)
                Container(
                    height: 1, color: Theme.of(context).colorScheme.hairline),
            ],
          ],
      ],
    );
  }
}

class _DayHeading extends StatelessWidget {
  const _DayHeading({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = formatTimestamp(date, AppLocalizations.of(context));
    var comma = label.indexOf(',');
    final arabicComma = label.indexOf('،');
    if (arabicComma != -1 && (comma == -1 || arabicComma < comma)) {
      comma = arabicComma;
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
      child: Text(
        comma == -1 ? label : label.substring(0, comma),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _RecentTransferRow extends StatelessWidget {
  const _RecentTransferRow({required this.record});

  final TransferRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final names = record.fileNames;
    final title = names.isEmpty
        ? l10n.fileCount(record.fileCount)
        : names.length == 1
            ? names.first
            : '${names.first} +${record.fileCount - 1}';
    final subtitle = '${record.peerName} · ${formatBytes(record.bytes)} · '
        '${_timeOfDay(record.timestamp)}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(AppIcons.send, size: 18, color: scheme.accentText),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _timeOfDay(DateTime time) {
  final local = time.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
