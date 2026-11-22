import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import 'package:free_send/core/format.dart';
import 'package:free_send/l10n/app_localizations.dart';
import 'package:free_send/services/local_store.dart';
import 'package:free_send/services/saf_browser.dart';
import 'package:free_send/services/saf_folders.dart';
import 'package:free_send/theme/app_icons.dart';
import 'package:free_send/theme/app_theme.dart';
import 'package:free_send/ui/kit/tokens.dart';
import 'package:free_send/ui/screens/file_browser_screen.dart';

/// Android counterpart of [FileBrowserView]: browses the Storage Access
/// Framework tree the user granted instead of the raw filesystem.
///
/// Same contract - [mode], [allowedExtensions] and [onConfirm] - so the
/// send screen can embed either browser per platform. Picks are copied
/// into the app cache on confirm because the transfer layer needs real
/// file paths.
class SafBrowserView extends StatefulWidget {
  const SafBrowserView({
    super.key,
    this.mode = FileBrowserMode.filesAndFolders,
    this.allowedExtensions,
    this.store,
    required this.onConfirm,
  });

  final FileBrowserMode mode;
  final Set<String>? allowedExtensions;

  /// Persists the granted tree URI so the browser reopens the same root.
  final LocalStore? store;

  /// Called with cached [File]s and [Directory]s once the picked SAF
  /// items have been copied into the app cache.
  final FutureOr<void> Function(
    List<File> files,
    List<Directory> directories,
  ) onConfirm;

  @override
  State<SafBrowserView> createState() => _SafBrowserViewState();
}

class _SafBrowserViewState extends State<SafBrowserView> {
  String? _rootUri;
  String _path = '';
  List<SafEntry> _entries = const [];
  bool _loading = false;
  bool _grid = false;
  bool _pickingRoot = false;
  bool _confirming = false;
  String? _error;

  /// Document URIs of marked files and relative-path -> documentId of
  /// marked folders (the id rebuilds a tree URI for the copy).
  final Set<String> _selectedFiles = {};
  final Map<String, String> _selectedDirs = {};

  bool get _foldersOnly => widget.mode == FileBrowserMode.foldersOnly;

  String get _rootLabel => AppLocalizations.of(context).thisDevice;

  @override
  void initState() {
    super.initState();
    // Reopen the previously granted tree when we still have one; the
    // "choose a folder" prompt only appears for first-time users.
    final stored = widget.store?.safRootUri;
    if (stored != null && stored.isNotEmpty) {
      _rootUri = stored;
      _load('');
    }
  }

  String _relPath(String name) => _path.isEmpty ? name : '$_path/$name';

  Future<void> _pickRoot() async {
    if (_pickingRoot) return;
    setState(() {
      _pickingRoot = true;
      _error = null;
    });
    final uri = await FilePicker.getDirectoryPath(
      dialogTitle: AppLocalizations.of(context).chooseFolderToSend,
    );
    if (!mounted) return;
    if (uri == null || uri.isEmpty) {
      setState(() => _pickingRoot = false);
      return;
    }
    await SafBrowser.persist(uri);
    await widget.store?.setSafRootUri(uri);
    if (!mounted) return;
    setState(() {
      _rootUri = uri;
      _path = '';
      _pickingRoot = false;
    });
    await _load('');
  }

  Future<void> _load(String path) async {
    final root = _rootUri;
    if (root == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await SafBrowser.list(root, path);
      entries.sort((a, b) {
        if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      if (!mounted) return;
      setState(() {
        _path = path;
        _entries = entries;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      // A revoked grant fails at the root; forget it so the next launch
      // asks for a folder again instead of erroring forever.
      if (path.isEmpty) {
        final store = widget.store;
        if (store != null) unawaited(store.setSafRootUri(null));
      }
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  /// (label, path-inside-tree) pairs for the breadcrumb strip; the root
  /// crumb has an empty path meaning "the granted tree root".
  List<({String label, String path})> _crumbs() {
    final crumbs = <({String label, String path})>[
      (label: _rootLabel, path: '')
    ];
    if (_path.isEmpty) return crumbs;
    var acc = '';
    for (final segment in _path.split('/')) {
      acc = acc.isEmpty ? segment : '$acc/$segment';
      crumbs.add((label: segment, path: acc));
    }
    return crumbs;
  }

  String? get _parentPath {
    if (_path.isEmpty) return null;
    final index = _path.lastIndexOf('/');
    return index < 0 ? '' : _path.substring(0, index);
  }

  void _toggle(SafEntry entry) {
    setState(() {
      if (entry.isDir) {
        final rel = _relPath(entry.name);
        if (_selectedDirs.remove(rel) == null) {
          _selectedDirs[rel] = entry.documentId;
        }
      } else if (!_foldersOnly) {
        if (!_selectedFiles.remove(entry.uri)) _selectedFiles.add(entry.uri);
      }
    });
  }

  bool _isSelected(SafEntry entry) => entry.isDir
      ? _selectedDirs.containsKey(_relPath(entry.name))
      : _selectedFiles.contains(entry.uri);

  /// Rebuilds the tree URI for a granted subfolder from its document id.
  String _treeUriFor(String documentId) {
    final root = _rootUri ?? '';
    final authority = root.startsWith('content://')
        ? root.substring('content://'.length).split('/').first
        : '';
    return 'content://$authority/tree/$documentId';
  }

  Future<void> _confirm() async {
    if (_confirming) return;
    setState(() => _confirming = true);
    try {
      final files = <File>[];
      for (final uri in _selectedFiles) {
        final path = await SafBrowser.copyFileToCache(uri);
        if (path != null) files.add(File(path));
      }
      final directories = <Directory>[];
      for (final entry in _selectedDirs.entries) {
        final cached = await SafFolders.copyTreeToCache(
          _treeUriFor(entry.value),
        );
        if (cached != null && cached.isNotEmpty) {
          directories.add(Directory(cached));
        }
      }
      setState(() {
        _selectedFiles.clear();
        _selectedDirs.clear();
      });
      await widget.onConfirm(files, directories);
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  String _extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  List<SafEntry> _visibleEntries() {
    var entries = _foldersOnly
        ? _entries.where((entry) => entry.isDir).toList(growable: false)
        : _entries;
    final allowed = widget.allowedExtensions;
    if (allowed != null) {
      entries = entries.where((entry) {
        if (entry.isDir) return true;
        return allowed.contains(_extensionOf(entry.name));
      }).toList(growable: false);
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selectedCount = _selectedFiles.length + _selectedDirs.length;
    return Column(
      children: [
        SizedBox(
          height: 44,
          child: Row(
            children: [
              IconButton(
                icon: Icon(AppIcons.backSmall),
                tooltip: l10n.up,
                onPressed:
                    _parentPath == null ? null : () => _load(_parentPath!),
              ),
              Expanded(child: _breadcrumbs()),
              IconButton(
                icon: Icon(_grid ? AppIcons.list : AppIcons.grid, size: 16),
                tooltip: _grid ? l10n.listView : l10n.gridView,
                onPressed: () => setState(() => _grid = !_grid),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _body(l10n)),
        if (selectedCount > 0)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(child: Text(l10n.selectedCount(selectedCount))),
                  FilledButton(
                    onPressed: _confirming ? null : _confirm,
                    child: _confirming
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _foldersOnly ? l10n.addFolder : l10n.addFiles,
                          ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _breadcrumbs() {
    final scheme = Theme.of(context).colorScheme;
    final crumbs = _crumbs();
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      itemCount: crumbs.length,
      separatorBuilder: (context, index) => Icon(
        AppIcons.chevronRight,
        size: 14,
        color: scheme.onSurfaceVariant,
      ),
      itemBuilder: (context, index) {
        final crumb = crumbs[index];
        final isCurrent = index == crumbs.length - 1;
        return Center(
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            onTap: isCurrent ? null : () => _load(crumb.path),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Text(
                crumb.label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                      color: isCurrent
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                    ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _body(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (_rootUri == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                AppIcons.folderOpen,
                size: 32,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.chooseFolderToBrowse,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: _pickingRoot ? null : _pickRoot,
                icon: Icon(AppIcons.folder, size: 17),
                label: Text(l10n.chooseFolderToBrowse),
              ),
            ],
          ),
        ),
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.folderReadFailed(_error!), textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: _pickRoot,
                child: Text(l10n.chooseFolderToBrowse),
              ),
            ],
          ),
        ),
      );
    }
    final entries = _visibleEntries();
    if (entries.isEmpty) {
      return Center(child: Text(l10n.folderEmpty));
    }
    if (_grid) {
      return GridView.builder(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 150,
          childAspectRatio: 0.92,
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
        ),
        itemCount: entries.length,
        itemBuilder: (context, index) => _gridTile(entries[index]),
      );
    }
    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final selected = _isSelected(entry);
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: entry.isDir
              ? Icon(AppIcons.folderFilled, color: AppColors.accent, size: 36)
              : Icon(
                  iconForFileName(entry.name),
                  size: 36,
                  color: AppColors.accent,
                ),
          title: Text(
            entry.name,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 17,
              color: scheme.onSurface,
            ),
          ),
          subtitle: entry.isDir
              ? null
              : Text(
                  formatBytes(entry.size),
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 15),
                ),
          trailing: IconButton(
            icon: FileSelectRadio(selected: selected),
            onPressed: () => _toggle(entry),
          ),
          onTap: entry.isDir
              ? () => _load(_relPath(entry.name))
              : () => _toggle(entry),
        );
      },
    );
  }

  Widget _gridThumb(SafEntry entry) {
    if (entry.isDir) {
      return Center(
        child: Icon(AppIcons.folderFilled, size: 48, color: AppColors.accent),
      );
    }
    return Center(
      child: Icon(
        iconForFileName(entry.name),
        size: 48,
        color: AppColors.accent,
      ),
    );
  }

  Widget _gridTile(SafEntry entry) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _isSelected(entry);
    return Material(
      color: selected ? AppColors.accentWash : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadii.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: entry.isDir
            ? () => _load(_relPath(entry.name))
            : () => _toggle(entry),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _gridThumb(entry)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    AppSpacing.xs,
                    AppSpacing.sm,
                    AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (!entry.isDir)
                        Text(
                          formatBytes(entry.size),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (selected)
              const Positioned(
                top: 6,
                right: 6,
                child: FileSelectRadio(selected: true),
              ),
          ],
        ),
      ),
    );
  }
}
