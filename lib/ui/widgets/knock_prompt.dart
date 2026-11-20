import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'package:free_send/core/format.dart';
import 'package:free_send/l10n/app_localizations.dart';
import 'package:free_send/services/transfer/doorbell.dart';
import 'package:free_send/state/app_state.dart';
import 'package:free_send/state/receive_controller.dart';
import 'package:free_send/ui/kit/tokens.dart';
import 'package:free_send/ui/widgets/common.dart';

/// The sender-consent prompt, shown app-wide so a knock is answered no matter
/// which tab the user is on. Resolves once the user answers (or the dialog is
/// dismissed, which counts as a decline).
Future<void> presentKnockConsent(
  BuildContext context,
  ReceiveController controller,
  Knock knock,
) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(l10n.knockAcceptTitle(knock.senderName)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${l10n.fileCount(knock.fileCount)} · '
            '${formatBytes(knock.totalBytes)}',
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.knockNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          style: clickCursorStyle,
          onPressed: () {
            context.read<AppState>().tick();
            Navigator.of(context).pop(false);
          },
          child: Text(l10n.decline),
        ),
        FilledButton(
          style: clickCursorStyle,
          onPressed: () {
            context.read<AppState>().tick();
            Navigator.of(context).pop(true);
          },
          child: Text(l10n.accept),
        ),
      ],
    ),
  );
  await controller.answerKnock(confirmed ?? false, knock);
}
