import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:scroll_animator/scroll_animator.dart';

import 'package:free_send/core/format.dart';
import 'package:free_send/state/send_controller.dart';
import 'package:free_send/theme/app_icons.dart';
import 'package:free_send/theme/app_theme.dart';
import 'package:free_send/ui/shell.dart';
import 'package:free_send/ui/widgets/common.dart';
import 'package:free_send/ui/widgets/pairing_card.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

enum _SourceKind { any, photos, videos, audio, docs, folder }

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
    await _pick(controller, kind);
  }

  Future<void> _pick(SendController controller, _SourceKind kind) async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: false,
        type: switch (kind) {
          _SourceKind.any => FileType.any,
          _SourceKind.photos => FileType.image,
          _SourceKind.videos => FileType.video,
          _SourceKind.audio => FileType.audio,
          _SourceKind.docs || _SourceKind.folder => FileType.custom,
        },
        allowedExtensions: kind == _SourceKind.docs
            ? const [
                'pdf', 'doc', 'docx', 'txt', 'md', 'rtf',
                'xls', 'xlsx', 'csv', 'ppt', 'pptx',
              ]
            : null,
      );
      if (result == null) return;
      final files = <File>[];
      for (final picked in result.files) {
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

  Future<void> _pickFolder(SendController controller) async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose a folder to send',
    );
    if (path == null || path.isEmpty || !mounted) return;
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

  Future<bool> _confirmLeave(SendController controller) async {
    if (!controller.isBusy) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop sharing?'),
        content: const Text(
          'The hotspot will close and the other device will lose the connection.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep sharing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Stop'),
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
    return PopScope(
      canPop: !controller.isBusy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmLeave(controller);
        if (leave && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Send'),
          leading: IconButton(
            icon: const Icon(AppIcons.back),
            onPressed: () async {
              final leave = await _confirmLeave(controller);
              if (leave && context.mounted) Navigator.of(context).pop();
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
                    SendPhase.idle => _PickView(
                        key: const ValueKey('pick'),
                        controller: controller,
                        picking: _picking,
                        query: _query,
                        onQueryChanged: (value) =>
                            setState(() => _query = value),
                        onPick: () => _openSourcePicker(controller),
                        onStart: controller.startSession,
                      ),
                    SendPhase.preparing => const _BusyView(
                        key: ValueKey('preparing'),
                        label: 'Opening the hotspot…',
                      ),
                    SendPhase.waitingForPeer || SendPhase.transferring =>
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
                          await controller.startSession();
                        },
                      ),
                    SendPhase.failed || SendPhase.cancelled => _FailedView(
                        key: const ValueKey('failed'),
                        controller: controller,
                        onRetry: () async {
                          await controller.reset();
                          if (!context.mounted) return;
                          await controller.startSession();
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
    final needle = query.trim().toLowerCase();
    final visible = controller.items
        .where((item) => needle.isEmpty || item.name.toLowerCase().contains(needle))
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pick what to send',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Everything is streamed straight over the hotspot link.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (controller.items.isNotEmpty) ...[
          TextField(
            onChanged: onQueryChanged,
            decoration: const InputDecoration(
              hintText: 'Search selected files',
              prefixIcon: Icon(AppIcons.search, size: 18),
              isDense: true,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (controller.items.isEmpty)
          EmptyState(
            icon: AppIcons.addCircle,
            title: 'Nothing selected',
            message:
                'Choose files from this device. Folders keep their names when '
                'they arrive.',
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
                        : const Icon(AppIcons.folderOpen, size: 17),
                    label: Text(picking ? 'Opening…' : 'Choose files or folder'),
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
                    'No selected file matches “$query”.',
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
        const SizedBox(height: AppSpacing.md),
        if (controller.items.isNotEmpty)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: picking ? null : onPick,
                  icon: const Icon(AppIcons.add, size: 17),
                  label: const Text('Add more'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => onStart(),
                  icon: const Icon(AppIcons.hotspot, size: 17),
                  label: const Text('Start sharing'),
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
                  '${formatCount(controller.items.length, 'file')} · '
                  '${formatBytes(controller.totalBytes)} total',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              TextButton(
                onPressed: controller.clearFiles,
                child: const Text('Clear'),
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
    final address = hotspot?.ip != null
        ? '${hotspot!.ip}:${controller.port}'
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
              icon: paused ? AppIcons.stop : (transferring ? AppIcons.zap : null),
              color: transferring ? theme.colorScheme.primary : null,
            ),
            const Spacer(),
            if (transferring && controller.peerCount > 1)
              StatusPill(label: '${controller.peerCount} devices'),
            if (!transferring) const PulsingDots(),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (!transferring && controller.pairingCode != null) ...[
          PairingCard(
            code: controller.pairingCode!,
            onCopy: () =>
                onCopy(controller.pairingCode!.encode(), 'Pairing code'),
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
                    'On the other device, open Free Send, choose Receive, and '
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
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            if (transferring) ...[
              Expanded(
                child: paused
                    ? FilledButton.icon(
                        onPressed: controller.resumeTransfer,
                        icon: const Icon(AppIcons.forward, size: 17),
                        label: const Text('Resume'),
                      )
                    : OutlinedButton.icon(
                        onPressed: controller.canPause
                            ? controller.pauseTransfer
                            : null,
                        icon: const Icon(AppIcons.stop, size: 17),
                        label: const Text('Pause'),
                      ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: OutlinedButton.icon(
                onPressed: controller.cancelSession,
                icon: const Icon(AppIcons.stop, size: 17),
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
            child: const Icon(
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

class _SourceSheet extends StatelessWidget {
  const _SourceSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
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
            child: Text('Add to this transfer', style: theme.textTheme.titleLarge),
          ),
          ListTile(
            leading: const Icon(AppIcons.folderOpen),
            title: const Text('Files'),
            subtitle: const Text('Any file type'),
            onTap: () => Navigator.of(context).pop(_SourceKind.any),
          ),
          ListTile(
            leading: const Icon(AppIcons.image),
            title: const Text('Photos'),
            onTap: () => Navigator.of(context).pop(_SourceKind.photos),
          ),
          ListTile(
            leading: const Icon(AppIcons.video),
            title: const Text('Videos'),
            onTap: () => Navigator.of(context).pop(_SourceKind.videos),
          ),
          ListTile(
            leading: const Icon(AppIcons.music),
            title: const Text('Audio'),
            onTap: () => Navigator.of(context).pop(_SourceKind.audio),
          ),
          ListTile(
            leading: const Icon(AppIcons.fileText),
            title: const Text('Documents'),
            subtitle: const Text('PDF, Office, text, CSV'),
            onTap: () => Navigator.of(context).pop(_SourceKind.docs),
          ),
          ListTile(
            leading: const Icon(AppIcons.folder),
            title: const Text('Folder'),
            subtitle: const Text('Send a whole folder tree'),
            onTap: () => Navigator.of(context).pop(_SourceKind.folder),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}
