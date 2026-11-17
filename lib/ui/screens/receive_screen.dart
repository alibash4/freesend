import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:scroll_animator/scroll_animator.dart';

import 'package:free_send/core/format.dart';
import 'package:free_send/core/platform_env.dart';
import 'package:free_send/models/transfer_item.dart';
import 'package:free_send/services/discovery_service.dart';
import 'package:free_send/services/pairing_code.dart';
import 'package:free_send/state/receive_controller.dart';
import 'package:free_send/l10n/app_localizations.dart';
import 'package:free_send/theme/app_icons.dart';
import 'package:free_send/theme/app_theme.dart';
import 'package:free_send/ui/screens/scan_screen.dart';
import 'package:free_send/services/permissions/transfer_setup.dart';
import 'package:free_send/ui/screens/setup_screen.dart';
import 'package:free_send/ui/shell.dart';
import 'package:free_send/ui/widgets/common.dart';
import 'package:free_send/ui/widgets/scan_radar.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  late final ScrollController _scrollController = AnimatedScrollController(
    animationFactory: const ChromiumEaseInOut(),
  );

  /// Null while the grant check is in flight. False opens the setup screen.
  bool? _setupReady;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _enter());
  }

  Future<void> _enter() async {
    final ready = !TransferSetup.applies || await TransferSetup.isReady;
    if (!mounted) return;
    setState(() => _setupReady = ready);
    if (!ready) return;
    _beginScanning();
  }

  void _beginScanning() {
    final controller = context.read<ReceiveController>();
    if (controller.phase == ReceivePhase.idle) {
      controller.startScanning();
    }
  }

  void _leave() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _openJoinSheet(ReceiveController controller) async {
    final details = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _JoinHotspotSheet(),
    );
    if (details == null) return;
    await controller.joinHotspot(details.$1, details.$2);
  }

  /// Scans the sender's code, then joins its hotspot and connects in one go.
  Future<void> _openScanner(ReceiveController controller) async {
    if (!ScanScreen.isSupported) {
      await _enterCode(controller);
      return;
    }
    final code = await ScanScreen.open(context);
    if (code == null) return;
    await controller.pairWith(code);
  }

  /// Pasting is the path for devices without a camera and for codes sent over
  /// a chat app instead of being shown on screen.
  Future<void> _enterCode(ReceiveController controller) async {
    final raw = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _CodeSheet(),
    );
    if (raw == null) return;
    final code = PairingCode.tryParse(raw);
    if (code == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('That is not a FreeSend pairing code.'),
          ),
        );
      return;
    }
    await controller.pairWith(code);
  }

  Future<void> _openManualConnect(ReceiveController controller) async {
    final target = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _ManualConnectSheet(),
    );
    if (target == null) return;
    final parts = target.split(':');
    final host = parts.first.trim();
    final port = parts.length > 1
        ? int.tryParse(parts[1].trim()) ?? 47811
        : 47811;
    await controller.connectToAddress(host, port);
  }

  @override
  Widget build(BuildContext context) {
    if (_setupReady != true) {
      if (_setupReady == false) {
        return SetupScreen(
          title: AppLocalizations.of(context).setupBeforeReceive,
          onLeave: _leave,
          onReady: () {
            setState(() => _setupReady = true);
            _beginScanning();
          },
        );
      }
      return Scaffold(backgroundColor: Theme.of(context).colorScheme.surface);
    }
    final controller = context.watch<ReceiveController>();
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onBack?.call();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.receiveTitle),
          leading: IconButton(
            icon: Icon(AppIcons.back),
            onPressed: () => widget.onBack?.call(),
          ),
        actions: [
          if (ScanScreen.isSupported &&
              (controller.phase == ReceivePhase.idle ||
                  controller.phase == ReceivePhase.scanning))
            IconButton(
              tooltip: l10n.scanPairingCode,
              onPressed: () => _openScanner(controller),
              icon: Icon(AppIcons.scan),
            ),
          if (controller.phase == ReceivePhase.scanning)
            IconButton(
              tooltip: l10n.rescan,
              onPressed: controller.startScanning,
              icon: Icon(AppIcons.refresh),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          children: [
            Padding(
              padding: kPagePadding,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: switch (controller.phase) {
                  ReceivePhase.idle ||
                  ReceivePhase.scanning ||
                  ReceivePhase.joining =>
                    _ScanView(
                      key: const ValueKey('scan'),
                      controller: controller,
                      onJoin: () => _openJoinSheet(controller),
                      onManual: () => _openManualConnect(controller),
                      onScan: () => _openScanner(controller),
                      onPaste: () => _enterCode(controller),
                    ),
                  ReceivePhase.reviewing => _ReviewView(
                      key: const ValueKey('review'),
                      controller: controller,
                    ),
                  ReceivePhase.transferring => _ProgressView(
                      key: const ValueKey('progress'),
                      controller: controller,
                    ),
                  ReceivePhase.completed => _DoneView(
                      key: const ValueKey('done'),
                      controller: controller,
                      onDone: () async {
                        await controller.reset();
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                  ReceivePhase.failed || ReceivePhase.cancelled => _ErrorView(
                      key: const ValueKey('error'),
                      controller: controller,
                      onRetry: () async {
                        await controller.reset();
                        if (context.mounted) await controller.startScanning();
                      },
                    ),
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }
}

class _ScanView extends StatelessWidget {
  const _ScanView({
    super.key,
    required this.controller,
    required this.onJoin,
    required this.onManual,
    required this.onScan,
    required this.onPaste,
  });

  final ReceiveController controller;
  final VoidCallback onJoin;
  final VoidCallback onManual;
  final VoidCallback onScan;
  final VoidCallback onPaste;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final sessions = controller.sessions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.nearbySessions,
                style: theme.textTheme.headlineSmall,
              ),
            ),
            if (controller.phase == ReceivePhase.joining)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const PulsingDots(),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          controller.isScanning
              ? l10n.listeningHotspot
              : l10n.scanningPaused,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: ScanRadar(
            sessions: sessions,
            active: controller.phase == ReceivePhase.scanning &&
                controller.isScanning,
            sweepColor: scheme.primary,
            ringColor: scheme.surfaceContainerHigh,
            blipColor: scheme.primary,
            size: 220,
            seed: controller.link.index,
          ),
        ),
        if (PlatformEnv.isDesktop) ...[
          const SizedBox(height: AppSpacing.md),
          LinkPicker(
            link: controller.link,
            onChanged: controller.setLink,
          ),
        ],
        if (controller.hotspotNotice != null) ...[
          const SizedBox(height: AppSpacing.md),
          SurfaceCard(
            tint: theme.colorScheme.primaryContainer,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  AppIcons.wifi,
                  size: 16,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    controller.hotspotNotice!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (controller.errorMessage != null) ...[
          const SizedBox(height: AppSpacing.md),
          SurfaceCard(
            tint: theme.colorScheme.error.withValues(alpha: 0.08),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              controller.errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: TextButton.icon(
            onPressed: ScanScreen.isSupported ? onScan : onPaste,
            icon: Icon(AppIcons.qr, size: 16),
            label: Text(
              ScanScreen.isSupported
                  ? 'Connect by scanning QR code instead'
                  : 'Connect by code instead',
            ),
          ),
        ),
        if (sessions.isEmpty)
          EmptyState(
            icon: AppIcons.radar,
            title: 'No sessions found',
            message: 'Scan the pairing code shown on the sending device — it '
                'joins the hotspot and connects for you.',
            action: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: ScanScreen.isSupported ? onScan : onPaste,
                    icon: Icon(
                      ScanScreen.isSupported
                          ? AppIcons.scan
                          : AppIcons.paste,
                      size: 17,
                    ),
                    label: Text(
                      ScanScreen.isSupported ? 'Scan code' : 'Enter code',
                    ),
                  ),
                ),
                if (ScanScreen.isSupported) ...[
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onPaste,
                      icon: Icon(AppIcons.paste, size: 16),
                      label: const Text('Enter code'),
                    ),
                  ),
                ],
                if (PlatformEnv.canJoinHotspot) ...[
                  const SizedBox(height: AppSpacing.xs),
                  TextButton.icon(
                    onPressed: onJoin,
                    icon: Icon(AppIcons.wifi, size: 16),
                    label: const Text('Join a hotspot'),
                  ),
                ],
              ],
            ),
          )
        else
          Column(
            children: [
              for (final session in sessions) ...[
                _SessionCard(
                  session: session,
                  onTap: () => controller.connectToSession(session),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
          ],
        ),
        if (controller.canResume) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(
                AppIcons.history,
                size: 14,
                color: theme.colorScheme.accentText,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Partial files resume where they stopped '
                  '(${formatBytes(controller.resumedBytes)})',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.accentText,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (PlatformEnv.canJoinHotspot && sessions.isNotEmpty) ...[
          OutlinedButton.icon(
            onPressed: onJoin,
            icon: Icon(AppIcons.wifi, size: 17),
            label: const Text('Join another hotspot'),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        if (sessions.isNotEmpty)
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              TextButton.icon(
                onPressed: ScanScreen.isSupported ? onScan : null,
                icon: Icon(AppIcons.scan, size: 16),
                label: const Text('Scan code'),
              ),
              TextButton.icon(
                onPressed: onPaste,
                icon: Icon(AppIcons.paste, size: 16),
                label: const Text('Enter code'),
              ),
              TextButton.icon(
                onPressed: onManual,
                icon: Icon(AppIcons.address, size: 16),
                label: const Text('Connect by address'),
              ),
            ],
          )
        else
          TextButton.icon(
            onPressed: onManual,
            icon: Icon(AppIcons.address, size: 16),
            label: const Text('Connect by address'),
          ),
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.onTap});

  final DiscoveredSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.softFill,
      borderRadius: BorderRadius.circular(AppRadii.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  AppIcons.device,
                  size: 18,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.deviceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatCount(session.fileCount, 'file')} · '
                      '${formatBytes(session.totalBytes)} · ${session.ip}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                AppIcons.chevronRight,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewView extends StatelessWidget {
  const _ReviewView({super.key, required this.controller});

  final ReceiveController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final manifest = controller.manifest!;
    final selectedCount = controller.selectedIds.length;
    final allSelected = selectedCount == manifest.items.length && selectedCount > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(manifest.hostName, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Offering ${formatCount(manifest.items.length, 'file')} · '
          '${formatBytes(manifest.totalBytes)}',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Text('Choose what to receive', style: theme.textTheme.titleMedium),
            const Spacer(),
            TextButton(
              onPressed: () => controller.selectAll(value: !allSelected),
              child: Text(allSelected ? 'Clear all' : 'Select all'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Column(
          children: [
            for (var i = 0; i < manifest.items.length; i++) ...[
              if (i > 0)
                Divider(height: 1, color: theme.colorScheme.hairline),
              CheckboxListTile(
                value: controller.selectedIds.contains(manifest.items[i].id),
                onChanged: (_) =>
                    controller.toggleSelection(manifest.items[i].id),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.trailing,
                dense: true,
                title: Text(
                  manifest.items[i].name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  formatBytes(manifest.items[i].size),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Icon(
              AppIcons.folder,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Saving to ${controller.saveLocation}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
        if (controller.encrypted) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(AppIcons.lock, size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Encrypted session'
                  '${controller.securityCode == null ? '' : ' · ${controller.securityCode}'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          onPressed: selectedCount == 0 ? null : controller.beginReceive,
          icon: Icon(AppIcons.download, size: 17),
          label: Text(
            selectedCount == 0
                ? 'Select files to receive'
                : 'Receive $selectedCount · ${formatBytes(controller.selectedBytes)}',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: controller.cancel,
          child: const Text('Back to sessions'),
        ),
      ],
    );
  }
}

class _ProgressView extends StatelessWidget {
  const _ProgressView({super.key, required this.controller});

  final ReceiveController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (controller.encrypted)
          StatusPill(
            label: 'Encrypted',
            icon: AppIcons.lock,
            color: theme.colorScheme.primary,
          ),
        if (controller.anyPaused) ...[
          StatusPill(
            label: controller.pausedByMe ? 'Paused by you' : 'Paused by sender',
            icon: AppIcons.pause,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Center(
          child: ProgressRing(
            progress: controller.overallProgress,
            headline: '${(controller.overallProgress * 100).round()}%',
            caption: '${formatBytes(controller.receivedBytes)} of '
                '${formatBytes(controller.totalBytes)}',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: _Metric(
                label: 'From',
                value: controller.manifest?.hostName ?? 'Nearby device',
              ),
            ),
            Expanded(
              child: _Metric(
                label: 'Speed',
                value: formatSpeed(controller.speedBytesPerSecond),
              ),
            ),
            Expanded(
              child: _Metric(
                label: 'Remaining',
                value: formatEta(
                  (controller.totalBytes - controller.receivedBytes)
                      .clamp(0, controller.totalBytes),
                  controller.speedBytesPerSecond,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Files', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Column(
          children: [
            for (var i = 0; i < controller.receivedItems.length; i++) ...[
              if (i > 0)
                Divider(height: 1, color: theme.colorScheme.hairline),
              FileTile(
                name: controller.receivedItems[i].name,
                size: controller.receivedItems[i].size,
                progress: controller.receivedItems[i].progress,
                subtitle: switch (controller.receivedItems[i].status) {
                  TransferStatus.done =>
                    '${formatBytes(controller.receivedItems[i].size)} · saved',
                  TransferStatus.paused =>
                    '${formatBytes(controller.receivedItems[i].transferred)} of '
                        '${formatBytes(controller.receivedItems[i].size)} · paused',
                  TransferStatus.failed => 'Failed',
                  TransferStatus.active ||
                  TransferStatus.pending =>
                    '${formatBytes(controller.receivedItems[i].transferred)} of '
                        '${formatBytes(controller.receivedItems[i].size)}',
                },
                trailing: controller.receivedItems[i].done
                    ? Icon(
                        AppIcons.check,
                        size: 16,
                        color: theme.colorScheme.accentText,
                      )
                    : null,
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: controller.pausedByMe
                    ? controller.resume
                    : controller.pause,
                icon: Icon(
                  controller.pausedByMe ? AppIcons.play : AppIcons.pause,
                  size: 17,
                ),
                label: Text(controller.pausedByMe ? 'Resume' : 'Pause'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: controller.cancel,
                icon: Icon(AppIcons.stop, size: 17),
                label: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DoneView extends StatelessWidget {
  const _DoneView({
    super.key,
    required this.controller,
    required this.onDone,
  });

  final ReceiveController controller;
  final Future<void> Function() onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final record = controller.lastRecord;
    return Column(
      children: [
        const SizedBox(height: AppSpacing.lg),
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            AppIcons.check,
            size: 30,
            color: AppColors.success,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Files received', style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          record == null
              ? ''
              : '${formatCount(record.fileCount, 'file')} · '
                  '${formatBytes(record.bytes)} · '
                  '${formatSpeed(record.averageBytesPerSecond)} average',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Icon(
              AppIcons.folder,
              size: 15,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                controller.saveLocation,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                textAlign: TextAlign.center,
              ),
            ),
            if (!Platform.isAndroid)
              TextButton(
                onPressed: () => _revealFolder(controller.saveLocation),
                child: const Text('Open'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(onPressed: () => onDone(), child: const Text('Done')),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: () async {
            await controller.reset();
            if (!context.mounted) return;
            await controller.startScanning();
          },
          child: const Text('Receive more'),
        ),
      ],
    );
  }

  void _revealFolder(String path) {
    try {
      if (Platform.isWindows) {
        Process.run('explorer', [path]);
      } else if (Platform.isMacOS) {
        Process.run('open', [path]);
      } else if (Platform.isLinux) {
        Process.run('xdg-open', [path]);
      }
    } on Object {
      // Opening a file manager is a convenience, never a failure.
    }
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    super.key,
    required this.controller,
    required this.onRetry,
  });

  final ReceiveController controller;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cancelled = controller.phase == ReceivePhase.cancelled;
    final failed = controller.receivedItems
        .where((item) =>
            !item.done && controller.selectedIds.contains(item.id))
        .length;
    return Column(
      children: [
        const SizedBox(height: AppSpacing.lg),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: theme.colorScheme.error.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            cancelled ? AppIcons.stop : AppIcons.unlink,
            size: 30,
            color: theme.colorScheme.error,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          cancelled ? 'Transfer cancelled' : 'Could not connect',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        if (controller.errorMessage != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            controller.errorMessage!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        if (failed > 0 && !cancelled) ...[
          FilledButton.icon(
            onPressed: controller.retryFailed,
            icon: Icon(AppIcons.refresh, size: 17),
            label: Text('Retry $failed file${failed == 1 ? '' : 's'}'),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        FilledButton(onPressed: () => onRetry(), child: const Text('Scan again')),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _JoinHotspotSheet extends StatefulWidget {
  const _JoinHotspotSheet();

  @override
  State<_JoinHotspotSheet> createState() => _JoinHotspotSheetState();
}

class _JoinHotspotSheetState extends State<_JoinHotspotSheet> {
  final _ssid = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _ssid.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Join the hotspot', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Use the hotspot name and password shown on the sending device.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _ssid,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Hotspot name'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: _submit,
            icon: Icon(AppIcons.wifi, size: 17),
            label: const Text('Join and scan'),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final ssid = _ssid.text.trim();
    if (ssid.isEmpty) return;
    Navigator.of(context).pop((ssid, _password.text));
  }
}

class _ManualConnectSheet extends StatefulWidget {
  const _ManualConnectSheet();

  @override
  State<_ManualConnectSheet> createState() => _ManualConnectSheetState();
}

class _ManualConnectSheetState extends State<_ManualConnectSheet> {
  final _address = TextEditingController(text: '192.168.43.1');

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Connect by address', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Enter the address shown on the sending device. The port is '
            'optional and defaults to 47811.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _address,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'Address or host:port'),
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(_address.text.trim()),
            icon: Icon(AppIcons.link, size: 17),
            label: const Text('Connect'),
          ),
        ],
      ),
    );
  }
}

class _CodeSheet extends StatefulWidget {
  const _CodeSheet();

  @override
  State<_CodeSheet> createState() => _CodeSheetState();
}

class _CodeSheetState extends State<_CodeSheet> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty || !mounted) return;
    setState(() => _code.text = text);
  }

  void _submit() {
    final value = _code.text.trim();
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Enter pairing code', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'On the sending device, tap Copy code under the QR code, then paste '
            'it here. The code starts with freesend://',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _code,
            autofocus: true,
            minLines: 1,
            maxLines: 3,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: 'Pairing code',
              hintText: 'freesend://pair?…',
              suffixIcon: IconButton(
                tooltip: 'Paste from clipboard',
                onPressed: _pasteFromClipboard,
                icon: Icon(AppIcons.paste, size: 17),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: _submit,
            icon: Icon(AppIcons.link, size: 17),
            label: const Text('Connect'),
          ),
        ],
      ),
    );
  }
}
