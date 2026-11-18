import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'package:free_send/theme/app_icons.dart';
import 'package:free_send/theme/app_theme.dart';
import 'package:free_send/services/app_logger.dart';
import 'package:free_send/ui/shell.dart';

/// Shows everything the app logged this session, with copy and dump actions.
///
/// The same buffer is mirrored to `freesend.log` in the app support directory,
/// so a release build can be diagnosed after the fact.
class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  LogLevel? _filter;

  @override
  void initState() {
    super.initState();
    // The buffer grows while this screen is open.
    AppLog.revision.addListener(_refresh);
  }

  @override
  void dispose() {
    AppLog.revision.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _copyAll() async {
    await Clipboard.setData(ClipboardData(text: AppLog.dump()));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Logs copied')));
  }

  Future<void> _saveToFile() async {
    final path = await AppLog.dumpToFile();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Saved to $path')));
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear logs?'),
        content: const Text(
          'The on-device log file keeps its history; only this view empties.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await AppLog.clear();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = AppLog.entries
        .where((entry) => _filter == null || entry.level == _filter)
        .toList(growable: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        actions: [
          IconButton(
            tooltip: 'Copy all',
            onPressed: _copyAll,
            icon: Icon(AppIcons.copy),
          ),
          IconButton(
            tooltip: 'Save to file',
            onPressed: _saveToFile,
            icon: Icon(AppIcons.folder),
          ),
          IconButton(
            tooltip: 'Clear',
            onPressed: _clear,
            icon: Icon(AppIcons.trash),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: kPagePadding,
              child: Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final level in [null, ...LogLevel.values])
                    FilterChip(
                      label: Text(level?.name ?? 'all'),
                      selected: _filter == level,
                      onSelected: (_) => setState(() => _filter = level),
                    ),
                ],
              ),
            ),
            Expanded(
              child: entries.isEmpty
                  ? Center(
                      child: Text(
                        'No log entries yet.',
                        style: theme.textTheme.bodySmall,
                      ),
                    )
                  : ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        final color = switch (entry.level) {
                          LogLevel.error => theme.colorScheme.error,
                          LogLevel.warn => Colors.orange,
                          LogLevel.info => theme.colorScheme.onSurface,
                          LogLevel.debug => theme.colorScheme.onSurfaceVariant,
                        };
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: 4,
                          ),
                          child: Text(
                            entry.format(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: color,
                            ),
                          ),
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