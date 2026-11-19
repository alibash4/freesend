import 'package:material_ui/material_ui.dart';

import 'package:free_send/l10n/app_localizations.dart';
import 'package:free_send/theme/app_icons.dart';
import 'package:free_send/theme/app_theme.dart';
import 'package:free_send/ui/widgets/common.dart';

/// Advisory notice shown when a VPN is attached on a desktop.
///
/// Deliberately not a gate: many VPN clients leave local traffic alone, so this
/// explains the symptom and lets the user carry on.
class VpnWarning extends StatelessWidget {
  const VpnWarning({super.key});

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
              Icon(
                AppIcons.info,
                size: 17,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.vpnWarningTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(l10n.vpnWarningBody, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
