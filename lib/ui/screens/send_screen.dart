import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:scroll_animator/scroll_animator.dart';

import 'package:free_send/core/format.dart';
import 'package:free_send/core/platform_env.dart';
import 'package:free_send/l10n/app_localizations.dart';
import 'package:free_send/services/app_packages.dart';
import 'package:free_send/services/saf_folders.dart';
import 'package:free_send/state/app_state.dart';
import 'package:free_send/state/send_controller.dart';
import 'package:free_send/theme/app_icons.dart';
import 'package:free_send/theme/app_theme.dart';
import 'package:free_send/ui/widgets/vpn_warning.dart';
import 'package:free_send/ui/screens/media_browser_screen.dart';
import 'package:free_send/ui/screens/send_select_view.dart';
import 'package:free_send/ui/screens/scan_screen.dart';
import 'package:free_send/ui/screens/setup_screen.dart';
import 'package:free_send/ui/shell.dart';
import 'package:free_send/ui/widgets/common.dart';
import 'package:free_send/ui/widgets/peer_list.dart';
import 'package:free_send/core/transfer_flow.dart';
import 'package:free_send/services/discovery_service.dart';
import 'package:free_send/ui/widgets/scan_radar.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key, this.onBack, this.initialMode});

  final VoidCallback? onBack;

  /// The entry already chosen from the send control, so this screen does not
  /// raise the chooser a second time.
  final SendMode? initialMode;

  /// Raises the send control where the user is, and returns what they picked.
  ///
  /// A sheet on mobile, a centered dialog on desktop. Null means dismissed, in
  /// which case nothing should navigate.
  static Future<SendMode?> choose(BuildContext context) {
    return PlatformEnv.isDesktop
        ? showDialog<SendMode>(
            context: context,
            builder: (context) => const _SendChooserDialog(),
          )
        : showModalBottomSheet<SendMode>(
            context: context,
            isScrollControlled: true,
            builder: (context) => const _SendChooserSheet(),
          );
  }

  @override
  State<SendScreen> createState() => _SendScreenState();
}

enum _SourceKind { any, media, photos, videos, audio, docs, apps, folder }

class _SendScreenState extends State<SendScreen> {
  bool _picking = false;
  String _query = '';
  bool _chooserShown = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialMode;
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<SendController>().setMode(initial);
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _chooseMode());
    }
  }

  /// The send control: nearby, scan a code, or a group. A sheet on mobile, a
  /// dialog on desktop, and the camera entry only exists where it can work.
  Future<void> _chooseMode() async {
    if (_chooserShown) return;
    _chooserShown = true;
    final controller = context.read<SendController>();
    final mode = await SendScreen.choose(context);
    if (!mounted) return;
    if (mode == null) {
      widget.onBack?.call();
      return;
    }
    controller.setMode(mode);
  }

  /// Scanning a receiver's QR hands us its doorbell address.
  Future<void> _scanReceiver(SendController controller) async {
    final code = await ScanScreen.open(context);
    if (code == null || !mounted) return;
    final host = code.host;
    if (host == null) return;
    await controller.knockScanned(code);
  }

  late final ScrollController _scrollController = AnimatedScrollController(
    animationFactory: const ChromiumEaseInOut(),
  );

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openSourcePicker(SendController controller) async {
    final kind = await showModalBottomSheet<_SourceKind>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => const _SourceSheet(),
    );
    if (kind == null || !mounted) return;
    if (kind == _SourceKind.folder) {
      setState(() => _picking = true);
      try {
        await _pickFolder(controller);
      } finally {
        if (mounted) setState(() => _picking = false);
      }
      return;
    }
    if (kind == _SourceKind.media) {
      await _pickMedia(controller);
      return;
    }
    if (kind == _SourceKind.apps) {
      await _pickApps(controller);
      return;
    }
    await _pick(controller, kind);
  }

  Future<void> _pick(SendController controller, _SourceKind kind) async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final picked = await FilePicker.pickFiles(
        type: switch (kind) {
          _SourceKind.any => FileType.any,
          _SourceKind.photos => FileType.image,
          _SourceKind.videos => FileType.video,
          _SourceKind.audio => FileType.audio,
          _SourceKind.docs ||
          _SourceKind.folder ||
          _SourceKind.media ||
          _SourceKind.apps =>
            FileType.custom,
        },
        allowedExtensions: kind == _SourceKind.docs
            ? const [
                'pdf',
                'doc',
                'docx',
                'txt',
                'md',
                'rtf',
                'xls',
                'xlsx',
                'csv',
                'ppt',
                'pptx',
              ]
            : null,
      );
      final files = <File>[];
      for (final picked in picked) {
        final path = picked.path;
        if (path != null && path.isNotEmpty) files.add(File(path));
      }
      controller.addFiles(files);
    } on Object catch (error) {
      if (!mounted) return;
      _toast(AppLocalizations.of(context).filePickerFailed('$error'));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _pickMedia(SendController controller) async {
    final files = await Navigator.of(context).push<List<File>>(
      MaterialPageRoute(builder: (_) => const MediaBrowserScreen()),
    );
    if (files == null || files.isEmpty || !mounted) return;
    controller.addFiles(files);
  }

  Future<void> _pickApps(SendController controller) async {
    final apps = await InstalledApps.list();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    if (apps.isEmpty) {
      _toast(l10n.noAppBundles);
      return;
    }
    final selected = await showModalBottomSheet<InstalledApp>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _AppsSheet(apps: apps),
    );
    if (selected == null || !mounted) return;
    final file = File(selected.path);
    if (!await file.exists()) {
      _toast(l10n.appBundleUnreadable);
      return;
    }
    controller.addFiles([file]);
  }

  Future<void> _pickFolder(SendController controller) async {
    final l10n = AppLocalizations.of(context);
    var path = await FilePicker.getDirectoryPath(
      dialogTitle: AppLocalizations.of(context).chooseFolderToSend,
    );
    if (path == null || path.isEmpty || !mounted) return;
    if (path.startsWith('content://')) {
      final cached = await SafFolders.copyTreeToCache(path);
      if (!mounted) return;
      if (cached == null || cached.isEmpty) {
        _toast(l10n.androidFolderUnreadable);
        return;
      }
      path = cached;
    }
    final folder = Directory(path);
    if (!await folder.exists()) {
      if (mounted) _toast(l10n.folderNotReadable);
      return;
    }
    await controller.addDirectory(folder);
    if (mounted && controller.items.isEmpty) {
      _toast(l10n.folderNoReadableFiles);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    _toast(AppLocalizations.of(context).labelCopied(label));
  }

  Future<void> _start(SendController controller) async {
    final ready = await SetupScreen.ensure(
      context,
      title: AppLocalizations.of(context).setupBeforeSend,
    );
    if (!ready || !mounted) return;
    await controller.startSession();
  }

  Future<bool> _confirmLeave(SendController controller) async {
    if (!controller.isBusy) return true;
    final l10n = AppLocalizations.of(context);
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.stopSharingTitle),
        content: Text(l10n.stopSharingBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.keepSharing),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.stop),
          ),
        ],
      ),
    );
    if (leave == true) {
      await controller.cancelSession();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SendController>();
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmLeave(controller);
        if (leave && context.mounted) widget.onBack?.call();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.sendTitle),
          leading: IconButton(
            icon: Icon(backGlyph),
            mouseCursor: SystemMouseCursors.click,
            onPressed: () async {
              context.read<AppState>().tick();
              final leave = await _confirmLeave(controller);
              if (leave && context.mounted) widget.onBack?.call();
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
                    SendPhase.idle => SendSelectView(
                        key: const ValueKey('select'),
                        controller: controller,
                        onStart: () => _start(controller),
                      ),
                    SendPhase.preparing => _BusyView(
                        key: const ValueKey('preparing'),
                        label: l10n.openingHotspot,
                      ),
                    SendPhase.waitingForPeer ||
                    SendPhase.transferring =>
                      _SessionView(
                        key: const ValueKey('session'),
                        controller: controller,
                        onCopy: _copy,
                        onScanReceiver: () => _scanReceiver(controller),
                      ),
                    SendPhase.completed => _CompletedView(
                        key: const ValueKey('done'),
                        controller: controller,
                        onDone: () async {
                          await controller.reset();
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        onAgain: () async {
                          await controller.reset();
                          if (!context.mounted) return;
                          await _start(controller);
                        },
                      ),
                    SendPhase.failed || SendPhase.cancelled => _FailedView(
                        key: const ValueKey('failed'),
                        controller: controller,
                        onRetry: () async {
                          await controller.reset();
                          if (!context.mounted) return;
                          await _start(controller);
                        },
                        onBack: () async {
                          await controller.reset();
                          if (context.mounted) Navigator.of(context).pop();
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

class _PickView extends StatelessWidget {
  const _PickView({
    super.key,
    required this.controller,
    required this.picking,
    required this.query,
    required this.onQueryChanged,
    required this.onPick,
    required this.onStart,
  });

  final SendController controller;
  final bool picking;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onPick;
  final Future<void> Function() onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final needle = query.trim().toLowerCase();
    final visible = controller.items
        .where((item) =>
            needle.isEmpty || item.name.toLowerCase().contains(needle))
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.pickWhatToSend,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.everythingStreamed,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (controller.items.isNotEmpty) ...[
          TextField(
            onChanged: onQueryChanged,
            decoration: InputDecoration(
              hintText: l10n.searchSelectedFiles,
              prefixIcon: Icon(AppIcons.search, size: 18),
              isDense: true,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (controller.items.isEmpty)
          EmptyState(
            icon: AppIcons.addCircle,
            title: l10n.nothingSelected,
            message: l10n.chooseFilesMessage,
            action: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: picking ? null : onPick,
                    icon: picking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(AppIcons.folderOpen, size: 17),
                    label:
                        Text(picking ? l10n.opening : l10n.chooseFilesOrFolder),
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: [
              if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Text(
                    l10n.noSelectedFileMatches(query),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              for (var i = 0; i < visible.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    color: theme.colorScheme.hairline,
                  ),
                FileTile(
                  name: visible[i].name,
                  size: visible[i].size,
                  subtitle: visible[i].relativePath,
                  trailing: IconButton(
                    tooltip: l10n.remove,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => controller.removeItem(visible[i]),
                    icon: Icon(
                      AppIcons.close,
                      size: 17,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
        if (controller.items.isEmpty && controller.recents.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.recentFiles, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          for (final recent in controller.recents.take(6))
            if (File(recent.path).existsSync())
              InkWell(
                onTap: picking
                    ? null
                    : () => controller.addFiles([File(recent.path)]),
                child: FileTile(
                  name: recent.name,
                  size: recent.size,
                  subtitle: l10n.tapToAddAgain,
                ),
              ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (controller.items.isNotEmpty)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: picking ? null : onPick,
                  icon: Icon(AppIcons.add, size: 17),
                  label: Text(l10n.addMore),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => onStart(),
                  icon: Icon(AppIcons.hotspot, size: 17),
                  label: Text(l10n.startSharing),
                ),
              ),
            ],
          ),
        if (controller.items.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(
                AppIcons.info,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.filesTotal(
                    controller.items.length,
                    formatBytes(controller.totalBytes),
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ),
              TextButton(
                onPressed: controller.clearFiles,
                child: Text(l10n.clear),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _BusyView extends StatelessWidget {
  const _BusyView({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl * 2),
      child: Column(
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _SessionView extends StatelessWidget {
  const _SessionView({
    super.key,
    required this.controller,
    required this.onCopy,
    required this.onScanReceiver,
  });

  final SendController controller;
  final Future<void> Function(String value, String label) onCopy;
  final VoidCallback onScanReceiver;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final hotspot = controller.hotspot;
    final transferring = controller.phase == SendPhase.transferring;
    final paused = controller.paused;
    final address = controller.sessionAddress != null
        ? '${controller.sessionAddress}:${controller.port}'
        : l10n.portOnly('${controller.port}');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            StatusPill(
              label: paused
                  ? l10n.paused
                  : transferring
                      ? l10n.transferringTag
                      : controller.hasPeer
                          ? l10n.deviceConnected(
                              controller.peerName ?? l10n.device)
                          : l10n.waitingForDevice,
              icon:
                  paused ? AppIcons.stop : (transferring ? AppIcons.zap : null),
              color: transferring ? theme.colorScheme.primary : null,
            ),
            const Spacer(),
            if (transferring && controller.peerCount > 1)
              StatusPill(label: l10n.deviceCount(controller.peerCount)),
            if (!transferring) const PulsingDots(),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (!transferring) ...[
          Text(
            switch (controller.mode) {
              SendMode.group => l10n.chooseReceivers,
              SendMode.scanCode => l10n.scanReceiverCode,
              SendMode.nearby => l10n.lookingForReceiver,
            },
            style: theme.textTheme.titleMedium,
          ),
          if (controller.vpnWarning) ...[
            const VpnWarning(),
            const SizedBox(height: AppSpacing.md),
          ],
          if (controller.hotspot != null) ...[
            _HostedLinkCard(
              ssid: controller.hotspot!.ssid,
              password: controller.hotspot!.password,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          const SizedBox(height: AppSpacing.md),
          Center(
            child: ScanRadar(
              blips: controller.candidates.length,
              active: controller.isHunting,
              sweepColor: theme.colorScheme.primary,
              ringColor: theme.colorScheme.surfaceContainerHigh,
              blipColor: theme.colorScheme.primary,
              size: 220,
              seed: controller.link.index,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (controller.candidates.isEmpty)
            Text(
              l10n.noCandidatesBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            )
          else if (controller.mode == SendMode.group) ...[
            for (final candidate in controller.candidates)
              _CandidateRow(
                candidate: candidate,
                state: controller.stateOf(candidate),
                groupMode: true,
                selected: controller.selected.contains(candidate.id),
                onTap: () => controller.toggleSelected(candidate.id),
              ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              onPressed:
                  controller.selected.isEmpty ? null : controller.knockSelected,
              icon: Icon(AppIcons.sendPlane, size: 17),
              label: Text(
                controller.selected.isEmpty
                    ? l10n.selectDevice
                    : l10n.askDevices(controller.selected.length),
              ),
            ),
          ] else if (controller.mode == SendMode.scanCode)
            OutlinedButton.icon(
              onPressed: onScanReceiver,
              icon: Icon(AppIcons.qr, size: 17),
              label: Text(l10n.scanQrCode),
            )
          else
            for (final candidate in controller.candidates)
              _CandidateRow(
                candidate: candidate,
                state: controller.stateOf(candidate),
                onTap: () => controller.knock(candidate),
              ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (transferring) ...[
          Center(
            child: ProgressRing(
              progress: controller.overallProgress,
              headline: '${(controller.overallProgress * 100).round()}%',
              caption: l10n.ofTotal(
                formatBytes(controller.sentBytes),
                formatBytes(controller.totalBytes),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SurfaceCard(
            child: Column(
              children: [
                Row(
                  children: [
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
                          controller.remainingBytes,
                          controller.speedBytesPerSecond,
                          l10n,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    controller.currentFileName ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Text(l10n.orJoinManually, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          SurfaceCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (controller.link == ShareLink.ethernet)
                  DetailRow(
                    label: l10n.networkLabel,
                    value: controller.sessionAddress ?? l10n.wired,
                    monospace: true,
                    onCopy: controller.sessionAddress == null
                        ? null
                        : () => onCopy(
                            controller.sessionAddress!, l10n.networkLabel),
                  )
                else
                  DetailRow(
                    label: l10n.hotspotLabel,
                    value: hotspot?.ssid ?? controller.appState.deviceName,
                    onCopy: hotspot == null
                        ? null
                        : () => onCopy(hotspot.ssid, l10n.hotspotName),
                  ),
                if (hotspot?.hasCredentials ?? false) ...[
                  const SizedBox(height: AppSpacing.sm),
                  DetailRow(
                    label: l10n.password,
                    value: hotspot!.password!,
                    monospace: true,
                    onCopy: () => onCopy(hotspot.password!, l10n.password),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                DetailRow(
                  label: l10n.addressLabel,
                  value: address,
                  monospace: true,
                  onCopy: () => onCopy(address, l10n.addressLabel),
                ),
                if (hotspot?.note != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    hotspot!.note!,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SurfaceCard(
            tint: theme.colorScheme.primaryContainer,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  AppIcons.phone,
                  size: 17,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.pairingInstructions,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.preparingSummary(
              l10n.fileCount(controller.items.length),
              formatBytes(controller.totalBytes),
            ),
            style: theme.textTheme.bodySmall,
          ),
        ],
        if (controller.peers.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          PeerList(peers: controller.peers),
        ],
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            if (transferring) ...[
              Expanded(
                child: paused
                    ? FilledButton.icon(
                        onPressed: controller.resumeTransfer,
                        icon: Icon(AppIcons.forward, size: 17),
                        label: Text(l10n.resume),
                      )
                    : OutlinedButton.icon(
                        onPressed: controller.canPause
                            ? controller.pauseTransfer
                            : null,
                        icon: Icon(AppIcons.stop, size: 17),
                        label: Text(l10n.pause),
                      ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: OutlinedButton.icon(
                onPressed: controller.cancelSession,
                icon: Icon(AppIcons.stop, size: 17),
                label: Text(
                  transferring ? l10n.cancelTransfer : l10n.stopSharing,
                ),
              ),
            ),
          ],
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
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CompletedView extends StatelessWidget {
  const _CompletedView({
    super.key,
    required this.controller,
    required this.onDone,
    required this.onAgain,
  });

  final SendController controller;
  final Future<void> Function() onDone;
  final Future<void> Function() onAgain;

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
          child: Text(
            l10n.sentToName(controller.peerName ?? l10n.theOtherDevice),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
        ),
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
        FilledButton(
          onPressed: () => onDone(),
          child: Text(l10n.done),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: () => onAgain(),
          child: Text(l10n.shareAgain),
        ),
      ],
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({
    super.key,
    required this.controller,
    required this.onRetry,
    required this.onBack,
  });

  final SendController controller;
  final Future<void> Function() onRetry;
  final Future<void> Function() onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final cancelled = controller.phase == SendPhase.cancelled;
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
              cancelled ? AppIcons.stop : AppIcons.alert,
              size: 30,
              color: theme.colorScheme.error,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Text(
            cancelled ? l10n.sharingStopped : l10n.couldNotShare,
            style: theme.textTheme.headlineSmall,
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
        if (!cancelled)
          FilledButton(
            onPressed: () => onRetry(),
            child: Text(l10n.tryAgain),
          ),
        if (!cancelled) const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: () => onBack(),
          child: Text(l10n.backToFiles),
        ),
      ],
    );
  }
}

class _AppsSheet extends StatelessWidget {
  const _AppsSheet({required this.apps});

  final List<InstalledApp> apps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(l10n.sendAnApp, style: theme.textTheme.titleLarge),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: apps.length,
                itemBuilder: (context, index) {
                  final app = apps[index];
                  return ListTile(
                    leading: Icon(AppIcons.package),
                    title: Text(app.name),
                    subtitle: Text(
                      app.version.isEmpty
                          ? l10n.installedApp
                          : l10n.appVersion(app.version),
                    ),
                    onTap: () => Navigator.of(context).pop(app),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceSheet extends StatelessWidget {
  const _SourceSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                l10n.addToTransfer,
                style: theme.textTheme.titleLarge,
              ),
            ),
            ListTile(
              leading: Icon(AppIcons.folderOpen),
              title: Text(l10n.files),
              subtitle: Text(l10n.anyFileType),
              onTap: () => Navigator.of(context).pop(_SourceKind.any),
            ),
            if (Platform.isAndroid || Platform.isMacOS)
              ListTile(
                leading: Icon(AppIcons.image),
                title: Text(l10n.mediaLibrary),
                subtitle: Text(l10n.mediaLibraryHint),
                onTap: () => Navigator.of(context).pop(_SourceKind.media),
              ),
            ListTile(
              leading: Icon(AppIcons.video),
              title: Text(l10n.videos),
              onTap: () => Navigator.of(context).pop(_SourceKind.videos),
            ),
            ListTile(
              leading: Icon(AppIcons.music),
              title: Text(l10n.audioLabel),
              onTap: () => Navigator.of(context).pop(_SourceKind.audio),
            ),
            ListTile(
              leading: Icon(AppIcons.fileText),
              title: Text(l10n.documents),
              subtitle: Text(l10n.docsHint),
              onTap: () => Navigator.of(context).pop(_SourceKind.docs),
            ),
            ListTile(
              leading: Icon(AppIcons.package),
              title: Text(l10n.appsLabel),
              subtitle: Text(l10n.appsHint),
              onTap: () => Navigator.of(context).pop(_SourceKind.apps),
            ),
            ListTile(
              leading: Icon(AppIcons.folder),
              title: Text(l10n.folderLabel),
              subtitle: Text(l10n.folderHint),
              onTap: () => Navigator.of(context).pop(_SourceKind.folder),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

/// One receiver on the sender's radar. Tapping asks it to accept.
class _CandidateRow extends StatelessWidget {
  const _CandidateRow({
    required this.candidate,
    required this.state,
    required this.onTap,
    this.groupMode = false,
    this.selected = false,
  });

  final SeekCandidate candidate;
  final AuthState? state;
  final VoidCallback onTap;
  final bool groupMode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final label = switch (state) {
      AuthState.pending => l10n.waitingAnswer,
      AuthState.accepted => l10n.acceptedTag,
      AuthState.declined => l10n.declinedTag,
      AuthState.offline => l10n.unreachable,
      null => candidate.platform,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Material(
        color: theme.colorScheme.softFill,
        borderRadius: BorderRadius.circular(AppRadii.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                if (groupMode)
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: selected,
                      onChanged: (_) => onTap(),
                    ),
                  )
                else
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      AppIcons.device,
                      size: 17,
                      color: theme.colorScheme.accentText,
                    ),
                  ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        candidate.deviceName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(label, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Icon(
                  chevronGlyph(context),
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The three ways to start sending: nearby, by scanning a code, or to a group.
/// The camera entry is absent on desktops because the app never offers a
/// scanner there.
class _SendChooserBody extends StatelessWidget {
  const _SendChooserBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final entries = <(SendMode, String, String, IconData)>[
      (
        SendMode.nearby,
        l10n.shareNearby,
        l10n.shareNearbyHint,
        AppIcons.radar,
      ),
      if (showScanEntry(PlatformEnv.kind))
        (
          SendMode.scanCode,
          l10n.scanQrCode,
          l10n.scanQrHint,
          AppIcons.qr,
        ),
      (
        SendMode.group,
        l10n.sendToGroup,
        l10n.sendToGroupHint,
        AppIcons.device,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.howToSend, style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        for (final (mode, title, body, icon) in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(mode),
                icon: Icon(icon, size: 18),
                label: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title),
                      Text(
                        body,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Mobile: a bottom sheet that opens at half height and drags taller.

/// Shows the link this phone is hosting so a device with no camera can join.
class _HostedLinkCard extends StatelessWidget {
  const _HostedLinkCard({required this.ssid, required this.password});

  final String ssid;
  final String? password;

  Future<void> _copy(BuildContext context, String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label copied')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.wifi, size: 16, color: theme.colorScheme.accentText),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Your hotspot is on',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'On the other device, join this network '
            '${password == null ? '' : 'with the password below'} '
            'and look for this name.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          _credentialRow(context, 'Name', ssid),
          if (password != null) ...[
            const SizedBox(height: AppSpacing.xs),
            _credentialRow(context, 'Password', password!),
          ],
        ],
      ),
    );
  }

  Widget _credentialRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 74,
          child: Text(label, style: theme.textTheme.bodySmall),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
        ),
        IconButton(
          tooltip: 'Copy $label',
          onPressed: () => _copy(context, value, label),
          icon: Icon(AppIcons.copy, size: 16),
        ),
      ],
    );
  }
}

class _SendChooserSheet extends StatelessWidget {
  const _SendChooserSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: _SendChooserBody(),
      ),
    );
  }
}

/// Desktop: a centered modal with a Close control.
class _SendChooserDialog extends StatelessWidget {
  const _SendChooserDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.sendTitle),
      content: SizedBox(width: 380, child: _SendChooserBody()),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}
