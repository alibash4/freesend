import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';

import 'package:free_send/core/format.dart';
import 'package:free_send/l10n/app_localizations.dart';
import 'package:free_send/theme/app_icons.dart';
import 'package:free_send/theme/app_theme.dart';
import 'package:free_send/ui/kit/tokens.dart';

/// Extension sets shared by the send screen's category filters.
const imageFileExtensions = {
  'jpg',
  'jpeg',
  'png',
  'gif',
  'webp',
  'bmp',
  'svg',
  'heic',
  'avif',
};
const audioFileExtensions = {
  'mp3',
  'wav',
  'flac',
  'aac',
  'ogg',
  'm4a',
  'opus',
  'wma',
};
const videoFileExtensions = {
  'mp4',
  'mkv',
  'avi',
  'mov',
  'webm',
  'm4v',
  'wmv',
  'flv',
  'ts',
};
const documentFileExtensions = {
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
  'odt',
  'ods',
  'odp',
  'epub',
};

Directory _homeDirectory() {
  final home = Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      Platform.environment['HOMEPATH'];
  return Directory(home != null && home.isNotEmpty ? home : '.');
}

/// What the user picked in [FileBrowserScreen].
class FileBrowserResult {
  const FileBrowserResult({this.files = const [], this.directories = const []});

  final List<File> files;
  final List<Directory> directories;
}

/// Whether the browser offers files, folders, or both.
enum FileBrowserMode { filesAndFolders, foldersOnly }

/// In-app filesystem browser used as the file picker on desktop platforms.
///
/// Navigates real directories with [dart:io], shows breadcrumbs, sorts
/// folders first, and lets the user multi-select files and/or whole
/// folders. Pops with a [FileBrowserResult] when confirmed.
class FileBrowserScreen extends StatelessWidget {
  const FileBrowserScreen({
    super.key,
    this.mode = FileBrowserMode.filesAndFolders,
    this.allowedExtensions,
  });

  final FileBrowserMode mode;

  /// When non-null, only files with these extensions (no dot, lowercase)
  /// are shown and selectable. `null` shows every file.
  final Set<String>? allowedExtensions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).files),
        actions: [
          IconButton(
            icon: Icon(AppIcons.close),
            tooltip: AppLocalizations.of(context).cancel,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
      body: FileBrowserView(
        mode: mode,
        allowedExtensions: allowedExtensions,
        onConfirm: (files, directories) {
          Navigator.of(context).pop(
            FileBrowserResult(files: files, directories: directories),
          );
        },
      ),
    );
  }
}

/// The browser surface without any [Scaffold] chrome: breadcrumbs, the
/// entry list, and a confirm bar. Embedded directly by the send screen
/// under the category tabs; wrapped by [FileBrowserScreen] when a
/// standalone picker route is needed.
class FileBrowserView extends StatefulWidget {
  const FileBrowserView({
    super.key,
    this.mode = FileBrowserMode.filesAndFolders,
    this.allowedExtensions,
    required this.onConfirm,
  });

  final FileBrowserMode mode;
  final Set<String>? allowedExtensions;

  /// Called with the marked files and directories when the user taps the
  /// confirm action. The view clears its marks afterwards.
  final FutureOr<void> Function(
    List<File> files,
    List<Directory> directories,
  ) onConfirm;

  @override
  State<FileBrowserView> createState() => _FileBrowserViewState();
}

class _FileBrowserViewState extends State<FileBrowserView> {
  Directory _dir = _homeDirectory();
  List<FileSystemEntity> _entries = const [];
  bool _loading = true;
  String? _error;
  final Set<String> _selectedFiles = {};
  final Set<String> _selectedDirs = {};

  bool get _foldersOnly => widget.mode == FileBrowserMode.foldersOnly;

  @override
  void initState() {
    super.initState();
    _load(_dir);
  }

  String _nameOf(FileSystemEntity entity) {
    final normalized = entity.path.replaceAll('\\', '/');
    final parts = normalized.split('/').where((part) => part.isNotEmpty);
    return parts.isEmpty ? entity.path : parts.last;
  }

  String _extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  Future<void> _load(Directory dir) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await dir.list(followLinks: false).toList();
      entries.sort((a, b) {
        final aDir = a is Directory;
        final bDir = b is Directory;
        if (aDir != bDir) return aDir ? -1 : 1;
        return _nameOf(a).toLowerCase().compareTo(_nameOf(b).toLowerCase());
      });
      if (!mounted) return;
      setState(() {
        _dir = dir;
        _entries = entries;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  /// Breadcrumb segments as (label, absolute path) pairs, root first.
  List<({String label, String path})> _crumbs() {
    final normalized = _dir.path.replaceAll('\\', '/');
    final parts =
        normalized.split('/').where((part) => part.isNotEmpty).toList();
    final crumbs = <({String label, String path})>[];
    if (normalized.startsWith('/')) {
      crumbs.add((label: '/', path: '/'));
      var acc = '';
      for (final part in parts) {
        acc += '/$part';
        crumbs.add((label: part, path: acc));
      }
    } else {
      // Windows-style drive path, e.g. C:/Users/...
      final drive = parts.isEmpty ? normalized : parts.first;
      crumbs.add((label: drive, path: '$drive:/'));
      var acc = '$drive:/';
      for (var i = 1; i < parts.length; i++) {
        acc += parts[i];
        crumbs.add((label: parts[i], path: acc));
        acc += '/';
      }
    }
    return crumbs;
  }

  String? get _parentPath {
    final crumbs = _crumbs();
    return crumbs.length > 1 ? crumbs[crumbs.length - 2].path : null;
  }

  void _toggle(FileSystemEntity entity) {
    setState(() {
      if (entity is Directory) {
        if (!_selectedDirs.remove(entity.path)) _selectedDirs.add(entity.path);
      } else if (!_foldersOnly) {
        if (!_selectedFiles.remove(entity.path)) {
          _selectedFiles.add(entity.path);
        }
      }
    });
  }

  bool _isSelected(FileSystemEntity entity) => entity is Directory
      ? _selectedDirs.contains(entity.path)
      : _selectedFiles.contains(entity.path);

  Future<void> _confirm() async {
    final files = _selectedFiles.map(File.new).toList(growable: false);
    final directories =
        _selectedDirs.map(Directory.new).toList(growable: false);
    setState(() {
      _selectedFiles.clear();
      _selectedDirs.clear();
    });
    await widget.onConfirm(files, directories);
  }

  IconData _iconFor(String name) {
    return switch (_extensionOf(name)) {
      'jpg' ||
      'jpeg' ||
      'png' ||
      'gif' ||
      'webp' ||
      'bmp' ||
      'svg' ||
      'heic' ||
      'avif' =>
        AppIcons.image,
      'mp4' || 'mkv' || 'avi' || 'mov' || 'webm' || 'm4v' => AppIcons.video,
      'mp3' ||
      'wav' ||
      'flac' ||
      'aac' ||
      'ogg' ||
      'm4a' ||
      'opus' =>
        AppIcons.music,
      'pdf' => AppIcons.pdf,
      'doc' || 'docx' || 'txt' || 'md' || 'rtf' || 'odt' => AppIcons.fileText,
      'zip' || 'rar' || '7z' || 'tar' || 'gz' || 'bz2' || 'xz' => AppIcons.file,
      _ => AppIcons.file,
    };
  }

  Widget _leading(FileSystemEntity entity) {
    if (entity is Directory) {
      return Icon(AppIcons.folder, color: AppColors.accent);
    }
    final name = _nameOf(entity);
    if (imageFileExtensions.contains(_extensionOf(name))) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.field),
        child: Image.file(
          File(entity.path),
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          cacheWidth: 96,
          errorBuilder: (context, error, stackTrace) =>
              Icon(_iconFor(name), size: 28),
        ),
      );
    }
    return Icon(_iconFor(name), size: 28);
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
                icon: Icon(AppIcons.arrowUp),
                tooltip: l10n.up,
                onPressed: _parentPath == null
                    ? null
                    : () => _load(Directory(_parentPath!)),
              ),
              Expanded(
                child: _Breadcrumbs(
                  crumbs: _crumbs(),
                  onSelect: (path) => _load(Directory(path)),
                ),
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
                    onPressed: _confirm,
                    child: Text(
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

  Widget _body(AppLocalizations l10n) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            l10n.folderReadFailed(_error!),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    var entries = _foldersOnly
        ? _entries.whereType<Directory>().toList(growable: false)
        : _entries;
    final allowed = widget.allowedExtensions;
    if (allowed != null) {
      entries = entries.where((entity) {
        if (entity is Directory) return true;
        return allowed.contains(_extensionOf(_nameOf(entity)));
      }).toList(growable: false);
    }
    if (entries.isEmpty) {
      return Center(child: Text(l10n.folderEmpty));
    }
    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entity = entries[index];
        final selected = _isSelected(entity);
        final name = _nameOf(entity);
        return ListTile(
          leading: _leading(entity),
          title: Text(name, overflow: TextOverflow.ellipsis),
          subtitle:
              entity is File ? Text(formatBytes(entity.lengthSync())) : null,
          trailing: IconButton(
            icon: Icon(
              selected ? AppIcons.checkCircle : AppIcons.circle,
              color: selected ? AppColors.accent : AppColors.neutral400,
            ),
            onPressed: () => _toggle(entity),
          ),
          onTap:
              entity is Directory ? () => _load(entity) : () => _toggle(entity),
        );
      },
    );
  }
}

class _Breadcrumbs extends StatelessWidget {
  const _Breadcrumbs({required this.crumbs, required this.onSelect});

  final List<({String label, String path})> crumbs;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
            onTap: isCurrent ? null : () => onSelect(crumb.path),
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
}
