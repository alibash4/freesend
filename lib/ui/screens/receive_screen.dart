import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:scroll_animator/scroll_animator.dart';

import 'package:free_send/core/format.dart';
import 'package:free_send/core/transfer_flow.dart';
import 'package:free_send/models/transfer_item.dart';
import 'package:free_send/services/pairing_code.dart';
import 'package:free_send/services/transfer/doorbell.dart';
import 'package:free_send/state/receive_controller.dart';
import 'package:free_send/l10n/app_localizations.dart';
import 'package:free_send/theme/app_icons.dart';
import 'package:free_send/theme/app_theme.dart';
import 'package:free_send/ui/screens/scan_screen.dart';
import 'package:free_send/services/permissions/transfer_setup.dart';
import 'package:free_send/ui/screens/setup_screen.dart';
import 'package:free_send/ui/shell.dart';
import 'package:free_send/ui/widgets/common.dart';

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

  StreamSubscription<Knock>? _knocks;

  @override
  void dispose() {
    unawaited(_knocks?.cancel());
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
    _beginWaiting();
    final controller = context.read<ReceiveController>();
    _knocks = controller.knocks.listen(_showKnockDialog);
  }

  /// The receiver waits; it does not hunt. The sender's signal finds it.
  void _beginWaiting() {
    final controller = context.read<ReceiveController>();
    if (controller.phase == ReceivePhase.idle) {
      controller.startWaiting();
    }
  }

  Future<void> _showKnockDialog(Knock knock) async {
    final controller = context.read<ReceiveController>();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Accept files from ${knock.senderName}?'),
        content: Text(
          '${formatCount(knock.fileCount, 'file')} · '
          '${formatBytes(knock.totalBytes)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Decline'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    await controller.answerKnock(confirmed ?? false);
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
            _beginWaiting();
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
          if (controller.isWaiting)
            IconButton(
              tooltip: l10n.rescan,
              onPressed: controller.startWaiting,
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
                    _WaitingView(
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
                        if (context.mounted) await controller.startWaiting();
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

class _WaitingView extends StatelessWidget {
  const _WaitingView({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Waiting for a device',
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
          controller.isWaiting
              ? 'Ready to receive. Keep this screen open.'
              : 'Getting ready…',
          style: theme.textTheme.bodySmall,
        ),
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
        switch (controller.presence) {
          ReceiverPresence.qr => _QrPanel(
              payload: controller.waitingQrPayload ?? '',
            ),
          ReceiverPresence.noCamera => const _NoCameraPanel(),
          ReceiverPresence.joinPrompt => _JoinPromptPanel(
              controller: controller,
              onJoin: onJoin,
            ),
          ReceiverPresence.idle => const SizedBox.shrink(),
        },
        const SizedBox(height: AppSpacing.lg),
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
        ),
      ],
    );
  }
}

/// The receiver is the target: it shows the code instead of hunting for one.
class _QrPanel extends StatelessWidget {
  const _QrPanel({required this.payload});

  final String payload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.neutral0,
              borderRadius: BorderRadius.circular(AppRadii.field),
            ),
            child: QrImageView(
              data: payload,
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
            'Scan this from the other device',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'The other device opens FreeSend and scans this code to connect.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton.icon(
            onPressed: () =>
                Clipboard.setData(ClipboardData(text: payload)),
            icon: Icon(AppIcons.copy, size: 16),
            label: const Text('Copy code'),
          ),
        ],
      ),
    );
  }
}

class _NoCameraPanel extends StatelessWidget {
  const _NoCameraPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            AppIcons.info,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              "There's nothing to scan here. The other device will find this "
              'one by name - keep both on the same network.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _JoinPromptPanel extends StatelessWidget {
  const _JoinPromptPanel({required this.controller, required this.onJoin});

  final ReceiveController controller;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                AppIcons.wifi,
                size: 18,
                color: theme.colorScheme.accentText,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  "Connect to the phone's hotspot",
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'This device joins the hotspot the phone creates. Pick it in the '
            'list once it appears.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: onJoin,
            icon: Icon(AppIcons.wifi, size: 17),
            label: const Text('Join a hotspot'),
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: controller.toggleLocalWifiQr,
              icon: Icon(
                controller.showLocalWifiQr ? AppIcons.wifi : AppIcons.link,
                size: 16,
              ),
              label: Text(
                controller.showLocalWifiQr
                    ? 'Back to the hotspot'
                    : 'Unable to connect? Use local Wi-Fi network',
              ),
            ),
          ),
          if (controller.showLocalWifiQr) ...[
            const SizedBox(height: AppSpacing.sm),
            if (controller.localWifiQrPayload == null)
              Text(
                'This device has no usable local address. Connect both devices '
                'to the same network first.',
                style: theme.textTheme.bodySmall,
              )
            else
              _QrPanel(payload: controller.localWifiQrPayload!),
          ],
        ],
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
            await controller.startWaiting();
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
