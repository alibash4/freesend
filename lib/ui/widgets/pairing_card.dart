import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
            semanticsLabel: 'FreeSend pairing code',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Scan to pair',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          code.hasHotspot
              ? 'On the other device, open FreeSend, choose Receive, and scan '
                  'this. It joins the hotspot and connects on its own.'
              : 'On the other device, open FreeSend, choose Receive, and scan '
                  'this to connect without typing an address.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        if (onCopy != null) ...[
          const SizedBox(height: AppSpacing.xs),
          TextButton.icon(
            onPressed: onCopy,
            icon: Icon(AppIcons.copy, size: 16),
            label: const Text('Copy code'),
          ),
        ],
      ],
    );
  }
}
