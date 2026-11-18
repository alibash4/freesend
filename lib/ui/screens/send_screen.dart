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
import 'package:free_send/state/send_controller.dart';
import 'package:free_send/theme/app_icons.dart';
import 'package:free_send/theme/app_theme.dart';
import 'package:free_send/ui/screens/media_browser_screen.dart';
import 'package:free_send/ui/screens/send_select_view.dart';
import 'package:free_send/ui/screens/setup_screen.dart';
import 'package:free_send/ui/shell.dart';
import 'package:free_send/ui/widgets/common.dart';
import 'package:free_send/ui/widgets/peer_list.dart';
import 'package:free_send/core/transfer_flow.dart';
import 'package:free_send/services/discovery_service.dart';
import 'package:free_send/ui/widgets/scan_radar.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<SendScreen> createState() => _SendScreenState();
}

enum _SourceKind { any, media, photos, videos, audio, docs, apps, folder }

class _SendScreenState extends State<SendScreen> {
  bool _picking = false;
  String _query = '';

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
      _toast('Could not open the file picker: $error');
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
    if (apps.isEmpty) {
      _toast('No installable app bundles were found on this device.');
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
      _toast('That app bundle is no longer readable.');
      return;
    }
    controller.addFiles([file]);
  }

  Future<void> _pickFolder(SendController controller) async {
    var path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Choose a folder to send',
    );
    if (path == null || path.isEmpty || !mounted) return;
    if (path.startsWith('content://')) {
      final cached = await SafFolders.copyTreeToCache(path);
      if (!mounted) return;
      if (cached == null || cached.isEmpty) {
        _toast('That Android folder could not be read. Choose it again.');
        return;
      }
      path = cached;
    }
    final folder = Directory(path);
    if (!await folder.exists()) {
      if (mounted) _toast('That folder is not readable.');
      return;
    }
    await controller.addDirectory(folder);
    if (mounted && controller.items.isEmpty) {
      _toast('That folder has no readable files.');
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
    _toast('$label copied');
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
            icon: Icon(AppIcons.back),
            onPressed: () async {
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
                    tooltip: 'Remove',
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
  });

  final SendController controller;
  final Future<void> Function(String value, String label) onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hotspot = controller.hotspot;
    final transferring = controller.phase == SendPhase.transferring;
    final paused = controller.paused;
    final address = controller.sessionAddress != null
        ? '${controller.sessionAddress}:${controller.port}'
        : 'Port ${controller.port}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            StatusPill(
              label: paused
                  ? 'Paused'
                  : transferring
                      ? 'Transferring'
                      : controller.hasPeer
                          ? '${controller.peerName ?? 'Device'} connected'
                          : 'Waiting for a device',
              icon:
                  paused ? AppIcons.stop : (transferring ? AppIcons.zap : null),
              color: transferring ? theme.colorScheme.primary : null,
            ),
            const Spacer(),
            if (transferring && controller.peerCount > 1)
              StatusPill(label: '${controller.peerCount} devices'),
            if (!transferring) const PulsingDots(),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (!transferring) ...[
          Text(
            'Looking for a device to receive these',
            style: theme.textTheme.titleMedium,
          ),
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
              'Nobody is ready yet - on the other device, open FreeSend and '
              'tap Receive.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
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
              caption:
                  '${formatBytes(controller.sentBytes)} of ${formatBytes(controller.totalBytes)}',
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
                        label: 'Speed',
                        value: formatSpeed(controller.speedBytesPerSecond),
                      ),
                    ),
                    Expanded(
                      child: _Metric(
                        label: 'Remaining',
                        value: formatEta(
                          controller.remainingBytes,
                          controller.speedBytesPerSecond,
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
          Text('Or join manually', style: theme.textTheme.titleMedium),
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
                    label: 'Network',
                    value: controller.sessionAddress ?? 'Wired',
                    monospace: true,
                    onCopy: controller.sessionAddress == null
                        ? null
                        : () => onCopy(controller.sessionAddress!, 'Network'),
                  )
                else
                  DetailRow(
                    label: 'Hotspot',
                    value: hotspot?.ssid ?? controller.appState.deviceName,
                    onCopy: hotspot == null
                        ? null
                        : () => onCopy(hotspot.ssid, 'Hotspot name'),
                  ),
                if (hotspot?.hasCredentials ?? false) ...[
                  const SizedBox(height: AppSpacing.sm),
                  DetailRow(
                    label: 'Password',
                    value: hotspot!.password!,
                    monospace: true,
                    onCopy: () => onCopy(hotspot.password!, 'Password'),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                DetailRow(
                  label: 'Address',
                  value: address,
                  monospace: true,
                  onCopy: () => onCopy(address, 'Address'),
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
                    'On the other device, open FreeSend, choose Receive, and '
                    'scan the code above — or join this hotspot and the session '
                    'appears on its own.',
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
            'Preparing ${formatCount(controller.items.length, 'file')} · '
            '${formatBytes(controller.totalBytes)}',
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
                        label: const Text('Resume'),
                      )
                    : OutlinedButton.icon(
                        onPressed: controller.canPause
                            ? controller.pauseTransfer
                            : null,
                        icon: Icon(AppIcons.stop, size: 17),
                        label: const Text('Pause'),
                      ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: OutlinedButton.icon(
                onPressed: controller.cancelSession,
                icon: Icon(AppIcons.stop, size: 17),
                label: Text(transferring ? 'Cancel transfer' : 'Stop sharing'),
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
            'Sent to ${controller.peerName ?? 'the other device'}',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Center(
          child: Text(
            record == null
                ? ''
                : '${formatCount(record.fileCount, 'file')} · '
                    '${formatBytes(record.bytes)} · '
                    '${formatSpeed(record.averageBytesPerSecond)} average',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: () => onDone(),
          child: const Text('Done'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: () => onAgain(),
          child: const Text('Share these files again'),
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
            cancelled ? 'Sharing stopped' : 'Could not share',
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
            child: const Text('Try again'),
          ),
        if (!cancelled) const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: () => onBack(),
          child: const Text('Back to files'),
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
              child: Text('Send an app', style: theme.textTheme.titleLarge),
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
                          ? 'Installed app'
                          : 'Version ${app.version}',
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
                'Add to this transfer',
                style: theme.textTheme.titleLarge,
              ),
            ),
            ListTile(
              leading: Icon(AppIcons.folderOpen),
              title: const Text('Files'),
              subtitle: const Text('Any file type'),
              onTap: () => Navigator.of(context).pop(_SourceKind.any),
            ),
            if (Platform.isAndroid || Platform.isMacOS)
              ListTile(
                leading: Icon(AppIcons.image),
                title: const Text('Media library'),
                subtitle:
                    const Text('Photos, videos, and audio with thumbnails'),
                onTap: () => Navigator.of(context).pop(_SourceKind.media),
              ),
            ListTile(
              leading: Icon(AppIcons.video),
              title: const Text('Videos'),
              onTap: () => Navigator.of(context).pop(_SourceKind.videos),
            ),
            ListTile(
              leading: Icon(AppIcons.music),
              title: const Text('Audio'),
              onTap: () => Navigator.of(context).pop(_SourceKind.audio),
            ),
            ListTile(
              leading: Icon(AppIcons.fileText),
              title: const Text('Documents'),
              subtitle: const Text('PDF, Office, text, CSV'),
              onTap: () => Navigator.of(context).pop(_SourceKind.docs),
            ),
            ListTile(
              leading: Icon(AppIcons.package),
              title: const Text('Apps'),
              subtitle: const Text('Installable app bundles on this device'),
              onTap: () => Navigator.of(context).pop(_SourceKind.apps),
            ),
            ListTile(
              leading: Icon(AppIcons.folder),
              title: const Text('Folder'),
              subtitle: const Text('Send a whole folder tree'),
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
  });

  final SeekCandidate candidate;
  final AuthState? state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = switch (state) {
      AuthState.pending => 'Waiting for an answer',
      AuthState.accepted => 'Accepted',
      AuthState.declined => 'Declined',
      AuthState.offline => 'Unreachable',
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
                  AppIcons.chevronRight,
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
