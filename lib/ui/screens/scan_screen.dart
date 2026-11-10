import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:free_send/services/pairing_code.dart';
import 'package:free_send/theme/app_icons.dart';
import 'package:free_send/theme/app_theme.dart';

/// Full-screen QR reader. Pops the parsed [PairingCode] as soon as a Free Send
/// payload is recognised, or null when the user backs out.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  /// The camera plugin ships an implementation for Android and macOS only.
  /// Windows and Linux offer the typed-in path instead of a dead button.
  static bool get isSupported => Platform.isAndroid || Platform.isMacOS;

  static Future<PairingCode?> open(BuildContext context) {
    return Navigator.of(context).push<PairingCode>(
      MaterialPageRoute(
        builder: (_) => const ScanScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _handled = false;
  bool _unrecognised = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;
      final code = PairingCode.tryParse(raw);
      if (code == null) {
        // Someone else's QR code: keep scanning and say why nothing happened.
        if (!_unrecognised && mounted) {
          setState(() => _unrecognised = true);
        }
        continue;
      }
      if (!mounted) return;
      _handled = true;
      Navigator.of(context).pop(code);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.neutral0,
        title: const Text('Scan pairing code'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            onDetect: _onDetect,
            fit: BoxFit.cover,
            errorBuilder: _buildError,
            placeholderBuilder: (context, _) => const ColoredBox(
              color: AppColors.ink,
              child: Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: AppColors.neutral0,
                  ),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.ink.withValues(alpha: 0.6),
                    AppColors.ink.withValues(alpha: 0.05),
                    AppColors.ink.withValues(alpha: 0.75),
                  ],
                  stops: const [0, 0.45, 1],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const Spacer(),
                const _Reticle(),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    0,
                    AppSpacing.xl,
                    AppSpacing.xl,
                  ),
                  child: Text(
                    _unrecognised
                        ? 'That code is not from Free Send. Point the camera at '
                            'the code on the sending device.'
                        : 'Point the camera at the code on the sending device.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.neutral0,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(
    BuildContext context,
    MobileScannerException error,
    Widget? _,
  ) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    final detail = error.errorDetails?.message;
    return ColoredBox(
      color: AppColors.ink,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                AppIcons.cameraOff,
                size: 30,
                color: AppColors.neutral400,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                denied ? 'Camera access is off' : 'The camera could not start',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.neutral0,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                denied
                    ? 'Free Send needs the camera only to read the pairing code. '
                        'Allow it in system settings, or type the code instead.'
                    : detail ??
                        'Another app may be using the camera. You can also type '
                            'the code instead.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.neutral300,
                    ),
              ),
              if (denied) ...[
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: openAppSettings,
                  icon: const Icon(AppIcons.settings, size: 17),
                  label: const Text('Open settings'),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(AppIcons.address, size: 16),
                label: const Text('Enter the code instead'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Four corner brackets framing the area the user should aim with.
class _Reticle extends StatelessWidget {
  const _Reticle();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 240,
      child: CustomPaint(painter: _ReticlePainter()),
    );
  }
}

class _ReticlePainter extends CustomPainter {
  static const _length = 30.0;
  static const _stroke = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final r = Rect.fromLTWH(0, 0, size.width, size.height);
    final path = Path()
      ..moveTo(r.left, r.top + _length)
      ..lineTo(r.left, r.top)
      ..lineTo(r.left + _length, r.top)
      ..moveTo(r.right - _length, r.top)
      ..lineTo(r.right, r.top)
      ..lineTo(r.right, r.top + _length)
      ..moveTo(r.right, r.bottom - _length)
      ..lineTo(r.right, r.bottom)
      ..lineTo(r.right - _length, r.bottom)
      ..moveTo(r.left + _length, r.bottom)
      ..lineTo(r.left, r.bottom)
      ..lineTo(r.left, r.bottom - _length);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
