import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'package:free_send/l10n/app_localizations.dart';
import 'package:free_send/services/permissions/app_permissions.dart';
import 'package:free_send/state/app_state.dart';
import 'package:free_send/theme/app_icons.dart';
import 'package:free_send/theme/app_theme.dart';
import 'package:free_send/ui/widgets/common.dart';

/// First-launch runtime permission gate for Android.
///
/// The user can allow the permissions or continue without them; FreeSend
/// still works for manual-address transfers and the file picker when the OS
/// denies the discovery/camera grants.
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  Map<Permission, PermissionStatus> _statuses = const {};
  int? _sdkInt;
  bool _requesting = false;


  @override
  void initState() {
    super.initState();
    if (AppPermissions.isMobile) _refresh();
  }

  Future<void> _refresh() async {
    final permissions = await AppPermissions.required;
    final statuses = <Permission, PermissionStatus>{};
    for (final permission in permissions) {
      statuses[permission] = await permission.status;
    }
    _sdkInt = await AppPermissions.androidSdkInt;
    if (mounted) setState(() => _statuses = statuses);
  }

  Future<void> _request() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    final statuses = await AppPermissions.request();
    if (!mounted) return;
    setState(() {
      _statuses = statuses;
      _requesting = false;
    });
    final granted = statuses.values.every(
      (status) => status.isGranted || status.isLimited,
    );
    if (granted) await _finish();
  }

  Future<void> _openSettings() async {
    await AppPermissions.openSettings();
    if (mounted) await _refresh();
  }

  Future<void> _finish() async {
    await context.read<AppState>().setPermissionsPrompted(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final android = Platform.isAndroid;
    final allGranted = _statuses.isNotEmpty &&
        _statuses.values.every(
          (status) => status.isGranted || status.isLimited,
        );
    final permanentlyDenied = _statuses.values.any(
      (status) => status.isPermanentlyDenied || status.isRestricted,
    );
    final showApi33 = !Platform.isAndroid || (_sdkInt ?? 33) >= 33;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md).copyWith(
            top: AppSpacing.xl,
            bottom: AppSpacing.xl,
          ),
          children: [
            Text(
              l10n.permTitle,
              textAlign: TextAlign.center,
              style: AppTypography.pageTitle.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.xl * 1.5),
            if (android) ...[
              _PermissionRow(
                icon: Icons.place_outlined,
                title: l10n.permLocationTitle,
                body: l10n.permLocationBody,
                status: _statusFor(Permission.locationWhenInUse),
              ),
              if (showApi33) ...[
                const SizedBox(height: AppSpacing.md),
                _PermissionRow(
                  icon: AppIcons.device,
                  title: l10n.permNearbyTitle,
                  body: l10n.permNearbyBody,
                  status: _statusFor(Permission.nearbyWifiDevices),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
            ] else ...[
              _PermissionRow(
                icon: AppIcons.device,
                title: l10n.permLocalNetworkTitle,
                body: AppPermissions.localNetworkNote,
                status: null,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (showApi33)
              _PermissionRow(
                icon: AppIcons.bell,
                title: l10n.permNotificationsTitle,
                body: l10n.permNotificationsBody,
                status: _statusFor(Permission.notification),
              ),
            const SizedBox(height: AppSpacing.md),
            if (showApi33)
              _PermissionRow(
                icon: AppIcons.image,
                title: l10n.permMediaTitle,
                body: l10n.permMediaBody,
                status: _statusFor(Permission.photos),
              ),
            const SizedBox(height: AppSpacing.md),
            _PermissionRow(
              icon: AppIcons.camera,
              title: l10n.permCameraTitle,
              body: l10n.permCameraBody,
              status: _statusFor(Permission.camera),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (allGranted)
              Text(
                l10n.permAllSet,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.success,
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: FilledButton(
                onPressed: _requesting
                    ? null
                    : (allGranted ? _finish : _request),
                child: _requesting
                    ? const SpinnerIcon(size: 16)
                    : Text(
                        allGranted ? l10n.permContinue : l10n.permAllow,
                      ),
              ),
            ),
            if (permanentlyDenied) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: _openSettings,
                icon: Icon(AppIcons.settings, size: 17),
                label: Text(l10n.permOpenSettings),
              ),
            ],

          ],
        ),
      ),
    );
  }

  PermissionStatus? _statusFor(Permission permission) =>
      _statuses[permission];
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.body,
    required this.status,
  });

  final IconData icon;
  final String title;
  final String body;
  final PermissionStatus? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final granted = status != null &&
        (status!.isGranted || status!.isLimited);
    final denied = status != null &&
        (status!.isDenied || status!.isPermanentlyDenied);
    final tint = granted
        ? AppColors.success
        : denied
            ? theme.colorScheme.error
            : theme.colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
                granted
                    ? l10n.permAllowed
                    : denied
                        ? l10n.permBlocked
                        : l10n.permNotAsked,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 12,
                  color: tint,
                ),
              ),
        ),
      ],
    );
  }
}
