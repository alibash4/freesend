import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:free_send/l10n/app_localizations.dart';
import 'package:free_send/services/pairing_code.dart';
import 'package:free_send/theme/app_icons.dart';
import 'package:free_send/theme/app_theme.dart';

/// The sender's side of QR pairing: one code that carries the hotspot name,
/// password and listener address, so the other device joins and connects in a
/// single scan.
///
/// The code sits directly on the page — everything a scanner needs is the QR
/// itself, so there is no card around it.
class PairingCard extends StatelessWidget {
  const PairingCard({super.key, required this.code, this.onCopy});

  final PairingCode code;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        // Always dark-on-white, even in dark mode: scanners need the contrast
        // more than the theme does.
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.neutral0,
            borderRadius: BorderRadius.circular(AppRadii.field),
          ),
          child: QrImageView(
            data: code.encode(),
            size: 172,
            padding: EdgeInsets.zero,
            backgroundColor: AppColors.neutral0,
            errorCorrectionLevel: QrErrorCorrectLevel.M,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: AppColors.ink,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: AppColors.ink,
            ),
            semanticsLabel: l10n.qrCodeSemantics,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.scanToPair,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          code.hasHotspot ? l10n.pairingHotspotHint : l10n.pairingNoHotspotHint,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        if (onCopy != null) ...[
          const SizedBox(height: AppSpacing.xs),
          TextButton.icon(
            onPressed: onCopy,
            icon: Icon(AppIcons.copy, size: 16),
            label: Text(l10n.copyCode),
          ),
        ],
      ],
    );
  }
}
