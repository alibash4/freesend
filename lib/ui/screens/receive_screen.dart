import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:scroll_animator/scroll_animator.dart';

import 'package:free_send/core/platform_env.dart';
import 'package:free_send/core/format.dart';
import 'package:free_send/core/transfer_flow.dart';
import 'package:free_send/models/transfer_item.dart';
import 'package:free_send/services/pairing_code.dart';
import 'package:free_send/state/app_state.dart';
import 'package:free_send/state/receive_controller.dart';
import 'package:free_send/l10n/app_localizations.dart';
import 'package:free_send/theme/app_icons.dart';
import 'package:free_send/theme/app_theme.dart';
import 'package:free_send/ui/widgets/vpn_warning.dart';
import 'package:free_send/ui/kit/app_page_title.dart';
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
    _beginWaiting();
    // Knock consent is handled app-wide in app.dart so a sender is answered
    // even while the user sits on another tab.
  }

  /// The receiver waits; it does not hunt. The sender's signal finds it.
  void _beginWaiting() {
    final controller = context.read<ReceiveController>();
    if (controller.phase == ReceivePhase.idle) {
      // A phone hosts whenever one is involved (R3/R4), so an Android
      // receiver brings its link up straight away.
      controller.startWaiting(
        host: PlatformEnv.kind == PlatformKind.android,
      );
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
          SnackBar(
            content: Text(AppLocalizations.of(context).invalidPairingCode),
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
    final port =
        parts.length > 1 ? int.tryParse(parts[1].trim()) ?? 47811 : 47811;
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onBack?.call();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(backGlyph, size: 25),
            mouseCursor: SystemMouseCursors.click,
            onPressed: () {
              context.read<AppState>().tick();
              widget.onBack?.call();
            },
          ),
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
                          if (context.mounted) {
                            await controller.startWaiting(
                              host: PlatformEnv.kind == PlatformKind.android,
                            );
                          }
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
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: AppPageTitle(l10n.waitingForDevice),
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
          controller.isWaiting ? l10n.waitingHintOpen : l10n.waitingHintReady,
          style: theme.textTheme.bodySmall,
        ),
        if (controller.vpnWarning) ...[
          const SizedBox(height: AppSpacing.md),
          const VpnWarning(),
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
        _OtherWaysToConnect(
          controller: controller,
          onScan: onScan,
          onPaste: onPaste,
          onManual: onManual,
        ),
      ],
    );
  }
}

/// The escape hatches, folded away so the waiting state stays the anchor.
/// Each row names the action and says when to use it.
class _OtherWaysToConnect extends StatelessWidget {
  const _OtherWaysToConnect({
    required this.controller,
    required this.onScan,
    required this.onPaste,
    required this.onManual,
  });

  final ReceiveController controller;
  final VoidCallback onScan;
  final VoidCallback onPaste;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final scheme = theme.colorScheme;
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(
          AppIcons.link,
          size: 18,
          color: scheme.onSurfaceVariant,
        ),
        title: Text(
          l10n.otherWaysTitle,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          l10n.otherWaysSubtitle,
          style: theme.textTheme.bodySmall,
        ),
        children: [
          if (ScanScreen.isSupported)
            _ConnectOption(
              icon: AppIcons.qr,
              title: l10n.scanPairingCode,
              subtitle: l10n.scanPairingCodeHint,
              onTap: () {
                controller.appState.tick();
                onScan();
              },
            ),
          _ConnectOption(
            icon: AppIcons.pairingLock,
            title: l10n.enterPairingCode,
            subtitle: l10n.enterPairingCodeHint,
            onTap: () {
              controller.appState.tick();
              onPaste();
            },
          ),
          _ConnectOption(
            icon: AppIcons.ipAddress,
            title: l10n.connectByAddress,
            subtitle: l10n.connectByAddressHint,
            onTap: () {
              controller.appState.tick();
              onManual();
            },
          ),
        ],
      ),
    );
  }
}

/// One self-explaining row inside "Other ways to connect".
class _ConnectOption extends StatelessWidget {
  const _ConnectOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(
                chevronGlyph(context),
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
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
    final l10n = AppLocalizations.of(context);
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
              semanticsLabel: l10n.qrCodeSemantics,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.qrScanTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.qrScanHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton.icon(
            style: clickCursorStyle,
            onPressed: () {
              context.read<AppState>().tick();
              Clipboard.setData(ClipboardData(text: payload));
            },
            icon: Icon(AppIcons.copy, size: 16),
            label: Text(l10n.copyCode),
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
    final l10n = AppLocalizations.of(context);
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
              l10n.noCameraBody,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Asks for the hotspot password the phone shows, then joins it.
Future<void> _askHotspotPassword(BuildContext context, String ssid) async {
  final controller = context.read<ReceiveController>();
  final password = await showDialog<String>(
    context: context,
    builder: (context) {
      final field = TextEditingController();
      return AlertDialog(
        title: Text('Join "$ssid"?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the password shown on the other device.',
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: field,
              autofocus: true,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
              onSubmitted: (value) => Navigator.of(context).pop(value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(field.text),
            child: const Text('Join'),
          ),
        ],
      );
    },
  );
  if (password == null || !context.mounted) return;
  await controller.joinSurveyed(ssid, password.trim());
}

class _JoinPromptPanel extends StatelessWidget {
  const _JoinPromptPanel({required this.controller, required this.onJoin});

  final ReceiveController controller;
  final VoidCallback onJoin;

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
                AppIcons.wifi,
                size: 18,
                color: theme.colorScheme.accentText,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.joinHotspotPromptTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.joinHotspotPromptBody,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            style: clickCursorStyle,
            onPressed: () {
              controller.appState.tick();
              onJoin();
            },
            child: Text(l10n.joinHotspot),
          ),
          if (!controller.showLocalWifiQr) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              style: clickCursorStyle,
              onPressed: controller.surveyingHotspots
                  ? null
                  : controller.surveyHotspots,
              icon: controller.surveyingHotspots
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(AppIcons.search, size: 17),
              label: Text(
                controller.hotspotCandidates.isEmpty
                    ? 'Look for the other device\'s hotspot'
                    : 'Look again',
              ),
            ),
            for (final ssid in controller.hotspotCandidates)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    style: clickCursorStyle,
                    onPressed: () => _askHotspotPassword(context, ssid),
                    icon: Icon(AppIcons.wifi, size: 16),
                    label: Text(ssid),
                  ),
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              style: clickCursorStyle,
              onPressed: () {
                controller.appState.tick();
                controller.toggleLocalWifiQr();
              },
              icon: Icon(
                controller.showLocalWifiQr ? AppIcons.wifi : AppIcons.link,
                size: 16,
              ),
              label: Text(
                controller.showLocalWifiQr
                    ? l10n.backToHotspot
                    : l10n.sameWifiShowCode,
              ),
            ),
          ),
          if (controller.showLocalWifiQr) ...[
            const SizedBox(height: AppSpacing.sm),
            if (controller.localWifiQrPayload == null)
              Text(
                l10n.noLocalAddressBody,
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
    final l10n = AppLocalizations.of(context);
    final manifest = controller.manifest!;
    final selectedCount = controller.selectedIds.length;
    final allSelected =
        selectedCount == manifest.items.length && selectedCount > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppPageTitle(manifest.hostName),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.offeringSummary(
            l10n.fileCount(manifest.items.length),
            formatBytes(manifest.totalBytes),
          ),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionHeader(
          title: l10n.chooseWhatToReceive,
          icon: AppIcons.inbox,
          action: TextButton(
            style: clickCursorStyle,
            onPressed: () {
              controller.appState.tick();
              controller.selectAll(value: !allSelected);
            },
            child: Text(allSelected ? l10n.clearAll : l10n.selectAll),
          ),
        ),
        Column(
          children: [
            for (var i = 0; i < manifest.items.length; i++) ...[
              if (i > 0) Divider(height: 1, color: theme.colorScheme.hairline),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: CheckboxListTile(
                  value: controller.selectedIds.contains(manifest.items[i].id),
                  onChanged: (_) {
                    controller.appState.tick();
                    controller.toggleSelection(manifest.items[i].id);
                  },
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
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SurfaceCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                      l10n.savingTo(controller.saveLocation),
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
                    Icon(
                      AppIcons.lock,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        controller.securityCode == null
                            ? l10n.encryptedSession
                            : '${l10n.encryptedSession} · ${controller.securityCode}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: clickCursorStyle,
                onPressed: () {
                  controller.appState.tick();
                  controller.cancel();
                },
                child: Text(l10n.backToSessions),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: FilledButton.icon(
                style: clickCursorStyle,
                onPressed: selectedCount == 0
                    ? null
                    : () {
                        controller.appState.tick();
                        controller.beginReceive();
                      },
                icon: Icon(AppIcons.download, size: 17),
                label: Text(
                  selectedCount == 0
                      ? l10n.selectFiles
                      : l10n.receiveCountLabel(
                          l10n.fileCount(selectedCount),
                          formatBytes(controller.selectedBytes),
                        ),
                ),
              ),
            ),
          ],
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
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (controller.encrypted)
          StatusPill(
            label: l10n.encryptedTag,
            icon: AppIcons.lock,
            color: theme.colorScheme.primary,
          ),
        if (controller.anyPaused) ...[
          StatusPill(
            label:
                controller.pausedByMe ? l10n.pausedByYou : l10n.pausedBySender,
            icon: AppIcons.pause,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Center(
          child: ProgressRing(
            progress: controller.overallProgress,
            headline: '${(controller.overallProgress * 100).round()}%',
            caption: l10n.ofTotal(
              formatBytes(controller.receivedBytes),
              formatBytes(controller.totalBytes),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SurfaceCard(
          child: Row(
            children: [
              Expanded(
                child: _Metric(
                  label: l10n.fromLabel,
                  value: controller.manifest?.hostName ?? l10n.nearbyDevice,
                ),
              ),
              Expanded(
                child: _Metric(
                  label: l10n.speed,
                  value: formatSpeed(controller.speedBytesPerSecond),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: l10n.remaining,
                  value: formatEta(
                    (controller.totalBytes - controller.receivedBytes)
                        .clamp(0, controller.totalBytes),
                    controller.speedBytesPerSecond,
                    l10n,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionHeader(title: l10n.files, icon: AppIcons.inbox),
        Column(
          children: [
            for (var i = 0; i < controller.receivedItems.length; i++) ...[
              if (i > 0) Divider(height: 1, color: theme.colorScheme.hairline),
              FileTile(
                name: controller.receivedItems[i].name,
                size: controller.receivedItems[i].size,
                progress: controller.receivedItems[i].progress,
                subtitle: switch (controller.receivedItems[i].status) {
                  TransferStatus.done => l10n.statusSaved(
                      formatBytes(controller.receivedItems[i].size)),
                  TransferStatus.paused => l10n.statusPaused(
                      formatBytes(controller.receivedItems[i].transferred),
                      formatBytes(controller.receivedItems[i].size)),
                  TransferStatus.failed => l10n.failedTag,
                  TransferStatus.active ||
                  TransferStatus.pending =>
                    l10n.ofTotal(
                      formatBytes(controller.receivedItems[i].transferred),
                      formatBytes(controller.receivedItems[i].size),
                    ),
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
                style: clickCursorStyle,
                onPressed: () {
                  controller.appState.tick();
                  if (controller.pausedByMe) {
                    controller.resume();
                  } else {
                    controller.pause();
                  }
                },
                icon: Icon(
                  controller.pausedByMe ? AppIcons.play : AppIcons.pause,
                  size: 17,
                ),
                label: Text(
                  controller.pausedByMe ? l10n.resume : l10n.pause,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                style: clickCursorStyle,
                onPressed: () {
                  controller.appState.tick();
                  controller.cancel();
                },
                icon: Icon(AppIcons.stop, size: 17),
                label: Text(l10n.cancel),
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
    final l10n = AppLocalizations.of(context);
    final record = controller.lastRecord;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Container(
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
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
            child: AppPageTitle(l10n.filesReceivedTitle,
                textAlign: TextAlign.center)),
        const SizedBox(height: AppSpacing.xs),
        Center(
          child: Text(
            record == null
                ? ''
                : l10n.doneSummaryAverage(
                    l10n.fileCount(record.fileCount),
                    formatBytes(record.bytes),
                    formatSpeed(record.averageBytesPerSecond),
                  ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        SurfaceCard(
          child: Row(
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
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!Platform.isAndroid)
                TextButton(
                  style: clickCursorStyle,
                  onPressed: () {
                    context.read<AppState>().tick();
                    _revealFolder(controller.saveLocation);
                  },
                  child: Text(l10n.open),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: clickCursorStyle,
            onPressed: () {
              context.read<AppState>().tick();
              onDone();
            },
            child: Text(l10n.done),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: clickCursorStyle,
            onPressed: () async {
              context.read<AppState>().tick();
              await controller.reset();
              if (!context.mounted) return;
              await controller.startWaiting(
                host: PlatformEnv.kind == PlatformKind.android,
              );
            },
            child: Text(l10n.receiveMore),
          ),
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
    final l10n = AppLocalizations.of(context);
    final cancelled = controller.phase == ReceivePhase.cancelled;
    final failed = controller.receivedItems
        .where((item) => !item.done && controller.selectedIds.contains(item.id))
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Container(
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
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: AppPageTitle(
            cancelled ? l10n.transferCancelled : l10n.couldNotConnect,
            textAlign: TextAlign.center,
          ),
        ),
        if (controller.errorMessage != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Text(
              controller.errorMessage!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        if (failed > 0 && !cancelled) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: clickCursorStyle,
              onPressed: () {
                context.read<AppState>().tick();
                controller.retryFailed();
              },
              icon: Icon(AppIcons.refresh, size: 17),
              label: Text(l10n.retryFiles(failed)),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: clickCursorStyle,
            onPressed: () {
              context.read<AppState>().tick();
              onRetry();
            },
            child: Text(l10n.scanAgain),
          ),
        ),
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
          style: theme.textTheme.titleMedium?.copyWith(
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
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
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
            Text(l10n.joinHotspotSheetTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.hotspotCredentialsHint,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _ssid,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: l10n.hotspotName),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.password),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              style: clickCursorStyle,
              onPressed: () {
                context.read<AppState>().tick();
                _submit();
              },
              icon: Icon(AppIcons.wifi, size: 17),
              label: Text(l10n.joinAndScan),
            ),
          ],
        ),
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
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
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
            Text(l10n.connectByAddress, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.manualConnectBody,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _address,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(labelText: l10n.addressOrHost),
              onSubmitted: (value) => Navigator.of(context).pop(value),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              style: clickCursorStyle,
              onPressed: () {
                context.read<AppState>().tick();
                Navigator.of(context).pop(_address.text.trim());
              },
              icon: Icon(AppIcons.link, size: 17),
              label: Text(l10n.connect),
            ),
          ],
        ),
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
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
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
            Text(l10n.pairingCodeSheetTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.pairingCodeHint,
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
                labelText: l10n.pairingCodeLabel,
                hintText: 'freesend://pair?…',
                suffixIcon: IconButton(
                  tooltip: l10n.pasteFromClipboard,
                  mouseCursor: SystemMouseCursors.click,
                  onPressed: () {
                    context.read<AppState>().tick();
                    _pasteFromClipboard();
                  },
                  icon: Icon(AppIcons.paste, size: 17),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              style: clickCursorStyle,
              onPressed: () {
                context.read<AppState>().tick();
                _submit();
              },
              icon: Icon(AppIcons.link, size: 17),
              label: Text(l10n.connect),
            ),
          ],
        ),
      ),
    );
  }
}
