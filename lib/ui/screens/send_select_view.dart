import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import 'package:free_send/core/format.dart';
import 'package:free_send/core/platform_env.dart';
import 'package:free_send/l10n/app_localizations.dart';
import 'package:free_send/models/recent_file.dart';
import 'package:free_send/models/transfer_item.dart';
import 'package:free_send/services/app_packages.dart';
import 'package:free_send/ui/screens/file_browser_screen.dart';
import 'package:free_send/services/storage_access.dart';
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

  Future<void> _addBrowserItems(
    List<File> files,
    List<Directory> directories,
  ) async {
    if (files.isNotEmpty) widget.controller.addFiles(files);
    for (final directory in directories) {
      await widget.controller.addDirectory(directory);
    }
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
    // Every browsing category embeds a file browser: the raw filesystem
    // on desktop, and on Android the same browser once the all-files
    // grant is in place. iOS keeps the old content views, and the APK
    // list is Android-only anyway.
    final browserMode = _category != _SendCategory.apk &&
        (PlatformEnv.isDesktop || Platform.isAndroid);
    // Recents stat every file synchronously, so only resolve them for the
    // categories that actually render them.
    final needsRecents = !browserMode &&
        _category != _SendCategory.files &&
        _category != _SendCategory.folders &&
        _category != _SendCategory.apk;
    final recents = needsRecents ? _categoryRecents() : const <RecentFile>[];
    // On desktop every browsing category embeds the filesystem browser;
    // only the APK list (Android-only anyway) keeps the old content views.
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
            if (wide && !browserMode)
              TextButton(
                onPressed: () =>
                    setState(() => _selectionMode = !_selectionMode),
                child: Text(_selectionMode ? l10n.done : l10n.select),
              ),
            if (!browserMode)
              IconButton(
                tooltip: _grid ? l10n.listView : l10n.gridView,
                onPressed: () => setState(() => _grid = !_grid),
                icon: Icon(_grid ? AppIcons.list : AppIcons.grid, size: 20),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (browserMode) ...[
          if (selected.isNotEmpty) ...[
            _QueueStrip(
              items: selected,
              onRemove: widget.controller.removeItem,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          _browserContent(),
        ] else if (_category == _SendCategory.files ||
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

  /// The embedded filesystem browser for the current category. Keyed by
  /// category so each tab keeps its own navigation state.
  Widget _browserContent() {
    final mode = _category == _SendCategory.folders
        ? FileBrowserMode.foldersOnly
        : FileBrowserMode.filesAndFolders;
    final allowed = switch (_category) {
      _SendCategory.music => audioFileExtensions,
      _SendCategory.docs => documentFileExtensions,
      _SendCategory.videos => videoFileExtensions,
      _ => null,
    };
    // The send screen scrolls as a whole, so the browser gets a bounded
    // height: about half the viewport, with sane clamps.
    final height =
        (MediaQuery.sizeOf(context).height * 0.5).clamp(320.0, 560.0);
    return SizedBox(
      height: height,
      child: PlatformEnv.isDesktop
          ? FileBrowserView(
              key: ValueKey(_category),
              mode: mode,
              allowedExtensions: allowed,
              onConfirm: _addBrowserItems,
            )
          : _StorageGate(
              key: ValueKey(_category),
              child: FileBrowserView(
                mode: mode,
                allowedExtensions: allowed,
                onConfirm: _addBrowserItems,
              ),
            ),
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

/// Gates the Android file browser behind the "All files access" grant.
/// Shows a prompt until [StorageAccess.isGranted] reports access, then
/// reveals the normal filesystem browser. Re-checks whenever the app
/// resumes so returning from system settings just works.
class _StorageGate extends StatefulWidget {
  const _StorageGate({super.key, required this.child});

  final Widget child;

  @override
  State<_StorageGate> createState() => _StorageGateState();
}

class _StorageGateState extends State<_StorageGate>
    with WidgetsBindingObserver {
  bool _checking = true;
  bool _granted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final granted = await StorageAccess.isGranted();
    if (!mounted) return;
    setState(() {
      _granted = granted;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    if (_checking) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_granted) return widget.child;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.folderOpen,
              size: 40,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.storageAccessNeeded,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.storageAccessBody,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () async {
                await StorageAccess.request();
                await _refresh();
              },
              icon: Icon(AppIcons.settings, size: 17),
              label: Text(l10n.grantStorageAccess),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact horizontal strip of everything already in the send queue,
/// shown above the embedded browser on desktop.
class _QueueStrip extends StatelessWidget {
  const _QueueStrip({required this.items, required this.onRemove});

  final List<TransferItem> items;
  final void Function(TransferItem item) onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final item = items[index];
          final isFolder = item.relativePath?.contains('/') ?? false;
          return Container(
            padding: const EdgeInsets.only(left: AppSpacing.sm),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isFolder ? AppIcons.folderOpen : AppIcons.file,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xs),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    item.name,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  icon: Icon(AppIcons.close, size: 16),
                  visualDensity: VisualDensity.compact,
                  tooltip: AppLocalizations.of(context).remove,
                  onPressed: () => onRemove(item),
                ),
              ],
            ),
          );
        },
      ),
    );
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

  /// Lazily created so a preserved [State] across hot reload still gets a
  /// working controller (field initializers don't re-run on reload).
  ScrollController? _scrollControllerInstance;
  ScrollController get _scrollController =>
      _scrollControllerInstance ??= ScrollController();

  /// Left edge of the indicator inside the strip; -1 hides it until the
  /// first measurement lands.
  double _indicatorX = -1;

  /// Whether more content is hidden past each visual edge, driving the
  /// gradient fades.
  bool _fadeLeft = false;
  bool _fadeRight = false;
  bool _scrollListening = false;

  void _listenToScroll() {
    if (_scrollListening) return;
    _scrollListening = true;
    _scrollController.addListener(_updateEdgeFades);
  }

  @override
  void initState() {
    super.initState();
    _listenToScroll();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncIndicator();
      _updateEdgeFades();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Direction flips swap which scroll edge is "start", so recompute.
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateEdgeFades());
  }

  @override
  void dispose() {
    _scrollControllerInstance?.dispose();
    _scrollControllerInstance = null;
    super.dispose();
  }

  void _updateEdgeFades() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final atStart = position.pixels <= position.minScrollExtent + 0.5;
    final atEnd = position.pixels >= position.maxScrollExtent - 0.5;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // The scroll "start" sits on the left in LTR and on the right in RTL.
    final fadeLeft = rtl ? !atEnd : !atStart;
    final fadeRight = rtl ? !atStart : !atEnd;
    if (fadeLeft != _fadeLeft || fadeRight != _fadeRight) {
      setState(() {
        _fadeLeft = fadeLeft;
        _fadeRight = fadeRight;
      });
    }
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
    // Recompute after every layout so the fades stay correct across hot
    // reloads, resizes, and locale/direction flips; the scroll listener
    // covers live updates while dragging.
    _listenToScroll();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateEdgeFades());
    return Material(
      type: MaterialType.transparency,
      child: SizedBox(
        height: 40,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scrollable = SingleChildScrollView(
              controller: _scrollController,
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
            );
            if (!_fadeLeft && !_fadeRight) return scrollable;

            // dstIn masks the child's alpha, so the tabs themselves fade
            // into the page - no dependence on the colour behind them.
            final fade = (AppSpacing.xl / constraints.maxWidth)
                .clamp(0.05, 0.5)
                .toDouble();
            final List<Color> colors;
            final List<double> stops;
            if (_fadeLeft && _fadeRight) {
              colors = const [
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ];
              stops = [0, fade, 1 - fade, 1];
            } else if (_fadeLeft) {
              colors = const [
                Colors.transparent,
                Colors.white,
                Colors.white,
              ];
              stops = [0, fade, 1];
            } else {
              colors = const [
                Colors.white,
                Colors.white,
                Colors.transparent,
              ];
              stops = [0, 1 - fade, 1];
            }
            return ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: colors,
                stops: stops,
              ).createShader(bounds),
              child: scrollable,
            );
          },
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
