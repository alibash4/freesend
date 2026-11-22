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
  // Android's shared storage root; the all-files grant makes it readable.
  if (Platform.isAndroid) return Directory('/storage/emulated/0');
  final home = Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      Platform.environment['HOMEPATH'];
  return Directory(home != null && home.isNotEmpty ? home : '.');
}

/// File-type icon for a name, shared by the filesystem and SAF browsers.
IconData iconForFileName(String name) {
  final dot = name.lastIndexOf('.');
  final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  return switch (ext) {
    'jpg' ||
    'jpeg' ||
    'png' ||
    'gif' ||
    'webp' ||
    'bmp' ||
    'svg' ||
    'heic' ||
    'avif' =>
      AppIcons.imageFilled,
    'mp4' || 'mkv' || 'avi' || 'mov' || 'webm' || 'm4v' => AppIcons.videoFilled,
    'mp3' ||
    'wav' ||
    'flac' ||
    'aac' ||
    'ogg' ||
    'm4a' ||
    'opus' =>
      AppIcons.musicFilled,
    'pdf' => AppIcons.pdfFilled,
    'doc' ||
    'docx' ||
    'txt' ||
    'md' ||
    'rtf' ||
    'odt' =>
      AppIcons.fileTextFilled,
    'zip' ||
    'rar' ||
    '7z' ||
    'tar' ||
    'gz' ||
    'bz2' ||
    'xz' =>
      AppIcons.fileFilled,
    _ => AppIcons.fileFilled,
  };
}

/// Animated radio-style selection indicator shared by the file browsers:
/// an outline ring that fills with the accent colour and reveals a check.
class FileSelectRadio extends StatelessWidget {
  const FileSelectRadio({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.accent : Colors.transparent,
        border: Border.all(
          color: selected ? AppColors.accent : AppColors.neutral400,
          width: 2,
        ),
      ),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        scale: selected ? 1 : 0,
        child: Icon(
          AppIcons.check,
          size: 14,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// What the user picked in [FileBrowserScreen].
class FileBrowserResult {
  const FileBrowserResult({this.files = const [], this.directories = const []});

  final List<File> files;
  final List<Directory> directories;
}

/// Whether the browser offers files, folders, or both.
enum FileBrowserMode { filesAndFolders, foldersOnly }

/// Lets an ancestor route consume system back for directory-up navigation
/// inside an embedded [FileBrowserView]. The view registers its handler
/// while mounted; routes check [onBack] before running their own logic.
class BrowserBackHandler {
  /// Returns true when the back press was consumed by the browser.
  bool Function()? onBack;
}

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
    this.showHeader = true,
    this.backHandler,
    this.isItemSelected,
    this.onItemToggle,
    required this.onConfirm,
  });

  /// Widget-test seam: `Directory.list` stream events never fire inside the
  /// fake-async zone a widget test runs in, so tests substitute a lister
  /// that resolves immediately.
  @visibleForTesting
  static Future<List<FileSystemEntity>> Function(Directory directory)?
      debugListDirectory;

  final FileBrowserMode mode;
  final Set<String>? allowedExtensions;

  /// Desktop shows the breadcrumb strip; embedded mobile use hides it and
  /// relies on [backHandler] for up-navigation instead.
  final bool showHeader;

  /// Receives the system-back handler while this view is mounted.
  final BrowserBackHandler? backHandler;

  /// Live-selection hooks: when [onItemToggle] is provided the parent owns
  /// selection state - [isItemSelected] reports it and every tap is
  /// forwarded instead of using the built-in marks and confirm bar.
  final bool Function(FileSystemEntity entity)? isItemSelected;
  final void Function(FileSystemEntity entity, bool selected)? onItemToggle;

  /// Called with the marked files and directories when the user taps the
  /// confirm action. The view clears its marks afterwards. Only used when
  /// [onItemToggle] is null (standalone picker mode).
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
  bool _grid = false;
  String? _error;
  final Set<String> _selectedFiles = {};
  final Set<String> _selectedDirs = {};

  /// Stable closure so [dispose] only unregisters its own handler.
  late final bool Function() _backEntry = _handleSystemBack;
  DateTime? _lastRootBack;

  bool get _foldersOnly => widget.mode == FileBrowserMode.foldersOnly;

  @override
  void initState() {
    super.initState();
    widget.backHandler?.onBack = _backEntry;
    _load(_dir);
  }

  @override
  void dispose() {
    if (widget.backHandler?.onBack == _backEntry) {
      widget.backHandler?.onBack = null;
    }
    super.dispose();
  }

  /// System back inside the embedded browser walks up the directory tree.
  /// At the root the first press warns and the second lets the enclosing
  /// screen's own back handling run.
  bool _handleSystemBack() {
    final parent = _parentPath;
    if (parent != null) {
      _load(Directory(parent));
      return true;
    }
    final now = DateTime.now();
    final last = _lastRootBack;
    if (last != null && now.difference(last).inSeconds < 2) {
      _lastRootBack = null;
      return false;
    }
    _lastRootBack = now;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).pressBackAgainToExit),
      ),
    );
    return true;
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
      final lister = FileBrowserView.debugListDirectory;
      final entries = lister != null
          ? await lister(dir)
          : await dir.list(followLinks: false).toList();
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

  /// On Android the shared-storage root doubles as the home directory, so
  /// the breadcrumb anchors there instead of exposing /storage/emulated/0.
  static const _androidHome = '/storage/emulated/0';

  /// Breadcrumb segments as (label, absolute path) pairs, root first.
  List<({String label, String path})> _crumbs(String rootLabel) {
    final normalized = _dir.path.replaceAll('\\', '/');
    if (Platform.isAndroid &&
        (normalized == _androidHome ||
            normalized.startsWith('$_androidHome/'))) {
      final crumbs = <({String label, String path})>[
        (label: rootLabel, path: _androidHome),
      ];
      var acc = _androidHome;
      final rest = normalized.substring(_androidHome.length);
      for (final part in rest.split('/').where((part) => part.isNotEmpty)) {
        acc += '/$part';
        crumbs.add((label: part, path: acc));
      }
      return crumbs;
    }
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
    final crumbs = _crumbs('');
    return crumbs.length > 1 ? crumbs[crumbs.length - 2].path : null;
  }

  void _toggle(FileSystemEntity entity) {
    final onItemToggle = widget.onItemToggle;
    if (onItemToggle != null) {
      onItemToggle(entity, !_isSelected(entity));
      return;
    }
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

  bool _isSelected(FileSystemEntity entity) =>
      widget.isItemSelected?.call(entity) ??
      (entity is Directory
          ? _selectedDirs.contains(entity.path)
          : _selectedFiles.contains(entity.path));

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

  IconData _iconFor(String name) => iconForFileName(name);

  Widget _leading(FileSystemEntity entity) {
    if (entity is Directory) {
      return Icon(
        AppIcons.folderFilled,
        color: AppColors.accent,
        size: 36,
      );
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
          errorBuilder: (context, error, stackTrace) => Icon(
            _iconFor(name),
            size: 36,
            color: AppColors.accent,
          ),
        ),
      );
    }
    return Icon(_iconFor(name), size: 36, color: AppColors.accent);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selectedCount = _selectedFiles.length + _selectedDirs.length;
    return Column(
      children: [
        if (widget.showHeader) ...[
          SizedBox(
            height: 44,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(AppIcons.backSmall),
                  tooltip: l10n.up,
                  onPressed: _parentPath == null
                      ? null
                      : () => _load(Directory(_parentPath!)),
                ),
                Expanded(
                  child: _Breadcrumbs(
                    crumbs: _crumbs(l10n.navHome),
                    onSelect: (path) => _load(Directory(path)),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _grid ? AppIcons.list : AppIcons.grid,
                    size: 16,
                  ),
                  tooltip: _grid ? l10n.listView : l10n.gridView,
                  onPressed: () => setState(() => _grid = !_grid),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
        Expanded(child: _body(l10n)),
        if (selectedCount > 0 && widget.onItemToggle == null)
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
        final entity = entries[index];
        final selected = _isSelected(entity);
        final name = _nameOf(entity);
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Padding(
            padding: const EdgeInsets.only(left: AppSpacing.sm),
            child: _leading(entity),
          ),
          title: Text(
            name,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 17,
              color: scheme.onSurface,
            ),
          ),
          subtitle: entity is File
              ? Text(
                  formatBytes(entity.lengthSync()),
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 15),
                )
              : null,
          trailing: IconButton(
            icon: FileSelectRadio(selected: selected),
            onPressed: () => _toggle(entity),
          ),
          onTap:
              entity is Directory ? () => _load(entity) : () => _toggle(entity),
        );
      },
    );
  }

  Widget _gridThumb(FileSystemEntity entity, String name) {
    if (entity is Directory) {
      return Center(
        child: Icon(AppIcons.folderFilled, size: 48, color: AppColors.accent),
      );
    }
    if (imageFileExtensions.contains(_extensionOf(name))) {
      return Image.file(
        File(entity.path),
        fit: BoxFit.cover,
        cacheWidth: 240,
        errorBuilder: (context, error, stackTrace) => Center(
          child: Icon(_iconFor(name), size: 48, color: AppColors.accent),
        ),
      );
    }
    return Center(
      child: Icon(_iconFor(name), size: 48, color: AppColors.accent),
    );
  }

  Widget _gridTile(FileSystemEntity entity) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _isSelected(entity);
    final name = _nameOf(entity);
    return Material(
      color: selected ? AppColors.accentWash : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadii.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap:
            entity is Directory ? () => _load(entity) : () => _toggle(entity),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _gridThumb(entity, name)),
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
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (entity is File)
                        Text(
                          formatBytes(entity.lengthSync()),
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
