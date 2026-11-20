import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:free_send/l10n/app_localizations.dart';
import 'package:free_send/services/app_logger.dart';
import 'package:free_send/services/pairing_code.dart';
import 'package:free_send/theme/app_icons.dart';
import 'package:free_send/theme/app_theme.dart';

/// Full-screen QR reader. Pops the parsed [PairingCode] as soon as a FreeSend
/// payload is recognised, or null when the user backs out.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, this.onDenied});

  /// Fires when camera access is refused, so the caller can leave the flow
  /// instead of landing back on a dead scanner.
  final VoidCallback? onDenied;

  /// The camera plugin ships an implementation for Android and macOS only.
  /// Windows and Linux offer the typed-in path instead of a dead button.
  static bool get isSupported => Platform.isAndroid || Platform.isMacOS;

  /// Opens the scanner right away: the page appears first and the system
  /// camera prompt fires from inside it, so a refusal can close the page
  /// smoothly back to wherever the user came from.
  static Future<PairingCode?> open(
    BuildContext context, {
    VoidCallback? onDenied,
  }) {
    if (!context.mounted) return Future<PairingCode?>.value();
    return Navigator.of(context).push<PairingCode>(
      MaterialPageRoute(
        builder: (_) => ScanScreen(onDenied: onDenied),
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
  bool _dismissed = false;
  bool _cameraReady = false;

  /// Camera can never be requested again (denied with "don't ask again" or
  /// restricted): show the settings card instead of the scanner.
  bool _blocked = false;

  @override
  void initState() {
    super.initState();
    unawaited(_ensureCamera());
  }

  /// The page is already on screen when this runs, so the system prompt
  /// appears over the scanner itself. A refusal closes the page quietly;
  /// a permanent refusal gets a settings card instead.
  Future<void> _ensureCamera() async {
    if (!Platform.isAndroid) {
      // macOS raises its own prompt on first camera access.
      if (mounted) setState(() => _cameraReady = true);
      return;
    }
    var status = await Permission.camera.status;
    AppLog.info('scan', 'camera permission is ${status.name}');
    if (status.isPermanentlyDenied || status.isRestricted) {
      if (mounted) setState(() => _blocked = true);
      return;
    }
    if (!status.isGranted) {
      status = await Permission.camera.request();
      AppLog.info('scan', 'camera request answered ${status.name}');
    }
    if (!mounted) return;
    if (status.isGranted) {
      setState(() => _cameraReady = true);
      return;
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      setState(() => _blocked = true);
      return;
    }
    widget.onDenied?.call();
    Navigator.of(context).maybePop();
  }

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
        title: Text(AppLocalizations.of(context).scanPairingCode),
      ),
      body: _blocked
          ? _buildBlocked(context)
          : Stack(
              fit: StackFit.expand,
              children: [
                if (_cameraReady)
                  MobileScanner(
                    onDetect: _onDetect,
                    fit: BoxFit.cover,
                    errorBuilder: _buildError,
                    placeholderBuilder: (context) => const ColoredBox(
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
                              ? AppLocalizations.of(context).scanWrongCode
                              : AppLocalizations.of(context).scanHint,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
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
  ) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    final detail = error.errorDetails?.message;
    final l10n = AppLocalizations.of(context);
    if (denied && !_dismissed) {
      // Permission was lost after the check: leave quietly instead of
      // parking the user on a dead camera page.
      _dismissed = true;
      widget.onDenied?.call();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
      return const SizedBox.shrink();
    }
    if (denied) return _blockedCard(context, l10n);
    return ColoredBox(
      color: AppColors.ink,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                AppIcons.cameraOff,
                size: 30,
                color: AppColors.neutral400,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.cameraFailed,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.neutral0,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                detail ?? l10n.cameraBusyBody,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.neutral300,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(AppIcons.address, size: 16),
                label: Text(l10n.enterCodeInstead),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shown when the camera can never be prompted for again: explains why and
  /// offers the one action that can fix it, with no scanner UI behind it.
  Widget _buildBlocked(BuildContext context) =>
      _blockedCard(context, AppLocalizations.of(context));

  Widget _blockedCard(BuildContext context, AppLocalizations l10n) {
    return ColoredBox(
      color: AppColors.ink,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                AppIcons.cameraOff,
                size: 30,
                color: AppColors.neutral400,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.cameraOff,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.neutral0,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.cameraDeniedBody,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.neutral300,
                    ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: openAppSettings,
                icon: Icon(AppIcons.settings, size: 17),
                label: Text(l10n.openSettings),
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
