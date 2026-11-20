import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import 'package:free_send/core/format.dart';
import 'package:free_send/core/platform_env.dart';
import 'package:free_send/l10n/app_localizations.dart';
import 'package:free_send/models/recent_file.dart';
import 'package:free_send/models/transfer_item.dart';
import 'package:free_send/services/app_packages.dart';
import 'package:free_send/state/send_controller.dart';
import 'package:free_send/theme/app_icons.dart';
import 'package:free_send/theme/app_theme.dart';
import 'package:free_send/ui/widgets/common.dart';

enum _SendCategory { files, folders, music, docs, videos, apk, large }

/// MVP source browser for the send screen: a category strip, a selectable
/// content grid/list, and the current send queue.
class SendSelectView extends StatefulWidget {
  const SendSelectView({
    super.key,
    required this.controller,
    required this.onStart,
  });

  final SendController controller;
  final Future<void> Function() onStart;

  @override
  State<SendSelectView> createState() => _SendSelectViewState();
}

class _SendSelectViewState extends State<SendSelectView> {
  _SendCategory _category = _SendCategory.files;
  bool _grid = false;
  bool _selectionMode = false;
  bool _loadingApps = false;
  List<InstalledApp> _apps = const [];

  /// App enumeration is expensive, so it stays lazy: only
  /// [_selectCategory] kicks it off, and only on Android where the APK
  /// category exists.
  Future<void> _loadApps() async {
    if (_loadingApps || _apps.isNotEmpty) return;
    setState(() => _loadingApps = true);
    final apps = await InstalledApps.list();
    if (!mounted) return;
    setState(() {
      _apps = apps;
      _loadingApps = false;
    });
  }

  Future<void> _addFiles(FileType type, {List<String>? extensions}) async {
    final effectiveExtensions = extensions ??
        (type == FileType.custom
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
            : null);
    final picked = await FilePicker.pickFiles(
      type: type,
      allowedExtensions: effectiveExtensions,
    );
    if (picked.isEmpty || !mounted) return;
    final files = picked
        .map((picked) => picked.path)
        .whereType<String>()
        .map(File.new)
        .toList(growable: false);
    widget.controller.addFiles(files);
  }

  Future<void> _addFolder() async {
    final path = await FilePicker.getDirectoryPath();
    if (path == null || path.isEmpty || !mounted) return;
    await widget.controller.addDirectory(Directory(path));
  }

  void _togglePath(String path) {
    final existing = widget.controller.items
        .where((item) => item.path == path)
        .toList(growable: false);
    if (existing.isNotEmpty) {
      for (final item in existing) {
        widget.controller.removeItem(item);
      }
      return;
    }
    final file = File(path);
    if (file.existsSync()) widget.controller.addFiles([file]);
  }

  bool _isSelected(String path) =>
      widget.controller.items.any((item) => item.path == path);

  void _selectCategory(_SendCategory category) {
    setState(() => _category = category);
    if (category == _SendCategory.apk) _loadApps();
  }

  List<RecentFile> _categoryRecents() {
    final all = widget.controller.recents
        .where((recent) => File(recent.path).existsSync())
        .toList(growable: false);
    return switch (_category) {
      _SendCategory.music =>
        all.where((recent) => _isMusic(recent.name)).toList(growable: false),
      _SendCategory.docs =>
        all.where((recent) => _isDocument(recent.name)).toList(growable: false),
      _SendCategory.videos =>
        all.where((recent) => _isVideo(recent.name)).toList(growable: false),
      _SendCategory.large => all
          .where((recent) => recent.size >= 100 * 1024 * 1024)
          .toList(growable: false),
      _SendCategory.files ||
      _SendCategory.folders ||
      _SendCategory.apk =>
        const [],
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final controller = widget.controller;
    final wide = MediaQuery.sizeOf(context).width >= 840;
    // Recents stat every file synchronously, so only resolve them for the
    // categories that actually render them.
    final needsRecents = _category != _SendCategory.files &&
        _category != _SendCategory.folders &&
        _category != _SendCategory.apk;
    final recents = needsRecents ? _categoryRecents() : const <RecentFile>[];
    final selected = controller.items;
    // APK bundles only exist on Android; other platforms never show the tab.
    final categories = _SendCategory.values
        .where(
            (category) => category != _SendCategory.apk || Platform.isAndroid)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),
        _CategoryTabs(
          categories: categories,
          selected: _category,
          onSelected: _selectCategory,
          labelBuilder: (category) => _categoryLabel(l10n, category),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: Text(
                _categoryLabel(l10n, _category),
                style: theme.textTheme.titleLarge,
              ),
            ),
            if (wide)
              TextButton(
                onPressed: () =>
                    setState(() => _selectionMode = !_selectionMode),
                child: Text(_selectionMode ? l10n.done : l10n.select),
              ),
            IconButton(
              tooltip: _grid ? l10n.listView : l10n.gridView,
              onPressed: () => setState(() => _grid = !_grid),
              icon: Icon(_grid ? Icons.view_list : Icons.grid_view),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (_category == _SendCategory.files ||
            _category == _SendCategory.folders)
          _selectedQueue(
            l10n,
            selected
                .where((item) =>
                    _category == _SendCategory.files ||
                    (item.relativePath?.contains('/') ?? false))
                .toList(growable: false),
            wide,
          )
        else if (_category == _SendCategory.apk)
          _appsContent(l10n, wide)
        else
          _recentsContent(l10n, recents, wide),
        if (PlatformEnv.isDesktop) ...[
          const SizedBox(height: AppSpacing.md),
          LinkPicker(
            link: controller.link,
            onChanged: controller.setLink,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: Text(
                '${l10n.fileCount(selected.length)} · '
                '${formatBytes(controller.totalBytes)}',
                style: theme.textTheme.bodySmall,
              ),
            ),
            FilledButton.icon(
              onPressed: selected.isEmpty ? null : () => widget.onStart(),
              icon: Icon(AppIcons.send, size: 17),
              label: Text(l10n.startSharing),
            ),
          ],
        ),
      ],
    );
  }

  Widget _selectedQueue(
    AppLocalizations l10n,
    List<TransferItem> items,
    bool wide,
  ) {
    if (items.isEmpty) {
      return _empty(
        l10n,
        _category == _SendCategory.folders ? l10n.addFolder : l10n.addFiles,
        _category == _SendCategory.folders
            ? _addFolder
            : () => _addFiles(FileType.any),
      );
    }
    return _contentLayout(
      children: [
        for (final item in items)
          _SelectableTile(
            name: item.name,
            subtitle: formatBytes(item.size),
            icon: _category == _SendCategory.folders
                ? AppIcons.folderOpen
                : AppIcons.file,
            selected: true,
            onTap: () => widget.controller.removeItem(item),
            longPress: null,
            grid: _grid,
            wide: wide,
          ),
      ],
      grid: _grid,
    );
  }

  Widget _recentsContent(
    AppLocalizations l10n,
    List<RecentFile> recents,
    bool wide,
  ) {
    if (recents.isEmpty) {
      return _empty(l10n, l10n.addFiles, () => _addFiles(_typeFor(_category)));
    }
    return _contentLayout(
      children: [
        for (final recent in recents)
          _SelectableTile(
            name: recent.name,
            subtitle: formatBytes(recent.size),
            icon: _categoryIcon(_category),
            selected: _isSelected(recent.path),
            onTap: () {
              if (!_selectionMode && !wide) {
                setState(() => _selectionMode = true);
              }
              _togglePath(recent.path);
            },
            longPress:
                (!wide) ? () => setState(() => _selectionMode = true) : null,
            grid: _grid,
            wide: wide,
          ),
      ],
      grid: _grid,
    );
  }

  Widget _appsContent(AppLocalizations l10n, bool wide) {
    if (_loadingApps) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_apps.isEmpty) {
      return _empty(l10n, l10n.addFiles, () => _addFiles(FileType.any));
    }
    return _contentLayout(
      children: [
        for (final app in _apps)
          _SelectableTile(
            name: app.name,
            subtitle: app.version,
            icon: AppIcons.android,
            selected: _isSelected(app.path),
            onTap: () {
              if (!_selectionMode && !wide) {
                setState(() => _selectionMode = true);
              }
              _togglePath(app.path);
            },
            longPress:
                (!wide) ? () => setState(() => _selectionMode = true) : null,
            grid: _grid,
            wide: wide,
          ),
      ],
      grid: _grid,
    );
  }

  Widget _contentLayout({
    required List<Widget> children,
    required bool grid,
  }) {
    if (grid) {
      return GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 140,
          childAspectRatio: 0.9,
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
        ),
        children: children,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _empty(
    AppLocalizations l10n,
    String actionLabel,
    VoidCallback action,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          Icon(AppIcons.folderOpen,
              size: 28, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.emptyCategory),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: action,
            icon: Icon(AppIcons.add, size: 17),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  bool _isMusic(String name) => const {
        'mp3',
        'wav',
        'flac',
        'm4a',
        'ogg',
        'aac',
      }.contains(_extension(name));

  bool _isDocument(String name) => const {
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
      }.contains(_extension(name));

  bool _isVideo(String name) => const {
        'mp4',
        'mkv',
        'mov',
        'avi',
        'webm',
      }.contains(_extension(name));

  String _extension(String name) {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  FileType _typeFor(_SendCategory category) {
    return switch (category) {
      _SendCategory.music => FileType.audio,
      _SendCategory.videos => FileType.video,
      _SendCategory.docs => FileType.custom,
      _SendCategory.large ||
      _SendCategory.files ||
      _SendCategory.folders ||
      _SendCategory.apk =>
        FileType.any,
    };
  }

  String _categoryLabel(AppLocalizations l10n, _SendCategory category) {
    return switch (category) {
      _SendCategory.files => l10n.files,
      _SendCategory.folders => l10n.folders,
      _SendCategory.music => l10n.music,
      _SendCategory.docs => l10n.documents,
      _SendCategory.videos => l10n.videos,
      _SendCategory.apk => l10n.apk,
      _SendCategory.large => l10n.largeFiles,
    };
  }

  IconData _categoryIcon(_SendCategory category) {
    return switch (category) {
      _SendCategory.files => AppIcons.file,
      _SendCategory.folders => AppIcons.folderOpen,
      _SendCategory.music => AppIcons.music,
      _SendCategory.docs => AppIcons.pdf,
      _SendCategory.videos => AppIcons.video,
      _SendCategory.apk => AppIcons.android,
      _SendCategory.large => AppIcons.info,
    };
  }
}

/// Scrollable category tabs with a sliding accent indicator - the same
/// 20x3 pill the bottom navigation uses, animated with the app's standard
/// motion curve.
class _CategoryTabs extends StatefulWidget {
  const _CategoryTabs({
    required this.categories,
    required this.selected,
    required this.onSelected,
    required this.labelBuilder,
  });

  final List<_SendCategory> categories;
  final _SendCategory selected;
  final ValueChanged<_SendCategory> onSelected;
  final String Function(_SendCategory) labelBuilder;

  @override
  State<_CategoryTabs> createState() => _CategoryTabsState();
}

class _CategoryTabsState extends State<_CategoryTabs> {
  final _stackKey = GlobalKey();
  final _tabKeys = <_SendCategory, GlobalKey>{};

  /// Left edge of the indicator inside the strip; -1 hides it until the
  /// first measurement lands.
  double _indicatorX = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncIndicator());
  }

  @override
  void didUpdateWidget(_CategoryTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncIndicator());
    }
  }

  /// Measures the selected tab's centre relative to the strip so the
  /// indicator can slide to it. Both boxes live inside the same scroll
  /// view, so the difference is scroll-independent.
  void _syncIndicator() {
    final stripBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final tabBox = _tabKeys[widget.selected]?.currentContext?.findRenderObject()
        as RenderBox?;
    if (stripBox == null ||
        tabBox == null ||
        !stripBox.hasSize ||
        !tabBox.hasSize) {
      return;
    }
    final stripOrigin = stripBox.localToGlobal(Offset.zero);
    final tabOrigin = tabBox.localToGlobal(Offset.zero);
    final centerX = tabOrigin.dx - stripOrigin.dx + tabBox.size.width / 2;
    final left = centerX - 10;
    if ((left - _indicatorX).abs() > 0.5) {
      setState(() => _indicatorX = left);
    }
  }

  void _select(_SendCategory category) {
    widget.onSelected(category);
    final tabContext = _tabKeys[category]?.currentContext;
    if (tabContext != null) {
      Scrollable.ensureVisible(
        tabContext,
        alignment: 0.5,
        duration: AppMotion.base,
        curve: AppMotion.standard,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: SizedBox(
        height: 40,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          child: Stack(
            key: _stackKey,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final category in widget.categories)
                    _CategoryTab(
                      key: _tabKeys.putIfAbsent(category, GlobalKey.new),
                      label: widget.labelBuilder(category),
                      selected: category == widget.selected,
                      onTap: () => _select(category),
                    ),
                ],
              ),
              if (_indicatorX >= 0)
                AnimatedPositioned(
                  duration: AppMotion.base,
                  curve: AppMotion.standard,
                  left: _indicatorX,
                  bottom: 5,
                  child: Container(
                    width: 20,
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTab extends StatelessWidget {
  const _CategoryTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final idle = dark ? AppColors.neutral300 : AppColors.neutral700;
    final color = selected ? AppColors.accent : idle;
    return InkWell(
      mouseCursor: SystemMouseCursors.click,
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.field),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 9,
        ),
        child: AnimatedDefaultTextStyle(
          duration: AppMotion.base,
          curve: AppMotion.standard,
          style: theme.textTheme.labelLarge!.copyWith(
            fontSize: 15,
            color: color,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class _SelectableTile extends StatelessWidget {
  const _SelectableTile({
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.longPress,
    required this.grid,
    required this.wide,
  });

  final String name;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? longPress;
  final bool grid;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final content = grid
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 26,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          )
        : Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          );

    final tile = Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppRadii.field),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        onTap: onTap,
        onLongPress: longPress,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: wide ? 16 : 12,
            vertical: 10,
          ),
          child: grid
              ? SizedBox(height: 110, child: Center(child: content))
              : SizedBox(height: 44, child: content),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: tile,
    );
  }
}
