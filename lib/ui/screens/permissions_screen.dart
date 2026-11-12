import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'package:free_send/services/permissions/app_permissions.dart';
import 'package:free_send/state/app_state.dart';
import 'package:free_send/theme/app_icons.dart';
import 'package:free_send/theme/app_theme.dart';
import 'package:free_send/ui/widgets/common.dart';

/// First-launch runtime permission gate for Android and iOS.
///
/// The user can allow the permissions or continue without them; Free Send
/// still works for manual-address transfers and the file picker when the OS
/// denies the discovery/camera grants.
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  Map<Permission, PermissionStatus> _statuses = const {};
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    if (AppPermissions.isMobile) _refresh();
  }

  Future<void> _refresh() async {
    final statuses = <Permission, PermissionStatus>{};
    for (final permission in AppPermissions.required) {
      statuses[permission] = await permission.status;
    }
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
    final android = Platform.isAndroid;
    final allGranted = _statuses.isNotEmpty &&
        _statuses.values.every(
          (status) => status.isGranted || status.isLimited,
        );
    final permanentlyDenied = _statuses.values.any(
      (status) => status.isPermanentlyDenied || status.isRestricted,
    );

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                AppIcons.device,
                color: theme.colorScheme.onPrimaryContainer,
                size: 24,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Before you start',
              style: theme.textTheme.displaySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Free Send needs access to the local link and camera to find '
              'nearby devices and scan pairing codes. Nothing leaves your '
              'network.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            if (android) ...[
              _PermissionRow(
                icon: AppIcons.wifi,
                title: 'Location / nearby devices',
                body: 'Required by Android to create or join a hotspot and '
                    'discover other Free Send devices.',
                status: _statusFor(Permission.locationWhenInUse),
              ),
              const SizedBox(height: AppSpacing.md),
              _PermissionRow(
                icon: AppIcons.device,
                title: 'Nearby Wi-Fi devices',
                body: 'Used on Android 13 and newer for device discovery.',
                status: _statusFor(Permission.nearbyWifiDevices),
              ),
              const SizedBox(height: AppSpacing.md),
            ] else ...[
              _PermissionRow(
                icon: AppIcons.device,
                title: 'Local network',
                body: AppPermissions.localNetworkNote,
                status: null,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            _PermissionRow(
              icon: AppIcons.scan,
              title: 'Camera',
              body: 'Only used to scan a pairing QR code. You can still pair '
                  'by typing or pasting the code.',
              status: _statusFor(Permission.camera),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (allGranted)
              SurfaceCard(
                tint: AppColors.success.withValues(alpha: 0.08),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    const Icon(
                      AppIcons.checkCircle,
                      size: 18,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Permissions granted. Free Send is ready.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Text(
                'You can change these later in the system settings.',
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: _requesting
                  ? null
                  : (allGranted ? _finish : _request),
              icon: _requesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(AppIcons.check, size: 17),
              label: Text(
                _requesting
                    ? 'Requesting…'
                    : allGranted
                        ? 'Continue'
                        : 'Allow permissions',
              ),
            ),
            if (permanentlyDenied) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: _openSettings,
                icon: const Icon(AppIcons.settings, size: 17),
                label: const Text('Open system settings'),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: _finish,
              child: Text(allGranted ? 'Continue' : 'Continue without'),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Desktop builds do not need this screen: local sockets, the tray, '
              'and the file picker already work.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
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
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: tint),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (status != null)
                    Text(
                      granted
                          ? 'Allowed'
                          : denied
                              ? 'Blocked'
                              : 'Not asked',
                      style: theme.textTheme.labelSmall?.copyWith(color: tint),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(body, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}