import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import 'package:free_send/l10n/app_localizations.dart';
import 'package:free_send/theme/app_icons.dart';
import 'package:free_send/theme/app_theme.dart';
import 'package:free_send/ui/kit/tokens.dart';
import 'package:free_send/ui/widgets/common.dart';

/// Paged device library for one media type. Used inside the send tabs so
/// audio and video never scan the filesystem.
class DeviceMediaPicker extends StatefulWidget {
  const DeviceMediaPicker({
    super.key,
    required this.type,
    required this.isSelected,
    required this.onToggle,
  });

  final RequestType type;
  final bool Function(String path) isSelected;
  final void Function(String path, bool selected) onToggle;

  @override
  State<DeviceMediaPicker> createState() => _DeviceMediaPickerState();
}

class _DeviceMediaPickerState extends State<DeviceMediaPicker> {
  final ScrollController _scroll = ScrollController();
  final List<AssetEntity> _assets = [];
  final Map<String, String> _paths = {};
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _denied = false;
  int _page = 0;
  AssetPathEntity? _album;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _open();
  }

  @override
  void didUpdateWidget(DeviceMediaPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.type != widget.type) {
      _assets.clear();
      _paths.clear();
      _page = 0;
      _hasMore = true;
      _open();
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || _loading || _loadingMore || !_hasMore) return;
    final position = _scroll.position;
    if (position.pixels > position.maxScrollExtent - 480) _loadMore();
  }

  Future<void> _open() async {
    setState(() {
      _loading = true;
      _denied = false;
    });
    final permission = await PhotoManager.requestPermissionExtend();
    if (!mounted) return;
    if (!permission.isAuth && !permission.hasAccess) {
      setState(() {
        _loading = false;
        _denied = true;
      });
      return;
    }
    final paths = await PhotoManager.getAssetPathList(
      type: widget.type,
      hasAll: true,
      onlyAll: true,
    );
    if (!mounted) return;
    _album = paths.isEmpty ? null : paths.first;
    _page = 0;
    _assets.clear();
    if (_album == null) {
      setState(() {
        _loading = false;
        _hasMore = false;
      });
      return;
    }
    await _loadMore(initial: true);
  }

  Future<void> _loadMore({bool initial = false}) async {
    final album = _album;
    if (album == null || _loadingMore) return;
    _loadingMore = true;
    try {
      final page = await album.getAssetListPaged(page: _page, size: _pageSize);
      if (!mounted) return;
      setState(() {
        _assets.addAll(page);
        _page += 1;
        _hasMore = page.length == _pageSize;
        _loading = false;
        _loadingMore = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _hasMore = false;
      });
    }
  }

  Future<void> _toggle(AssetEntity asset) async {
    var path = _paths[asset.id];
    if (path == null) {
      final file = await asset.file;
      if (file == null || !mounted) return;
      path = file.path;
      _paths[asset.id] = path;
    }
    widget.onToggle(path, !widget.isSelected(path));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_denied) {
      return EmptyState(
        icon: AppIcons.image,
        title: l10n.mediaUnavailable,
        message: l10n.mediaPermissionOff,
        action: OutlinedButton(
          onPressed: PhotoManager.openSetting,
          child: Text(l10n.tryAgain),
        ),
      );
    }
    if (_assets.isEmpty) {
      return EmptyState(
        icon: widget.type == RequestType.audio ? AppIcons.music : AppIcons.video,
        title: l10n.noMediaHere,
        message: l10n.noMediaHint,
      );
    }
    if (widget.type == RequestType.audio) {
      return ListView.builder(
        controller: _scroll,
        itemCount: _assets.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _assets.length) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          final asset = _assets[index];
          final path = _paths[asset.id];
          final selected = path != null && widget.isSelected(path);
          return ListTile(
            leading: Icon(AppIcons.music),
            title: MiddleEllipsisText(asset.title ?? l10n.audioLabel),
            trailing: Icon(
              selected ? AppIcons.checkCircle : AppIcons.circle,
              color: selected ? Theme.of(context).colorScheme.primary : null,
            ),
            onTap: () => _toggle(asset),
          );
        },
      );
    }
    return GridView.builder(
      controller: _scroll,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        childAspectRatio: 1,
        crossAxisSpacing: 3,
        mainAxisSpacing: 3,
      ),
      itemCount: _assets.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _assets.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final asset = _assets[index];
        final path = _paths[asset.id];
        return RepaintBoundary(
          child: _AssetTile(
            asset: asset,
            selected: path != null && widget.isSelected(path),
            onTap: () => _toggle(asset),
          ),
        );
      },
    );
  }
}

/// In-app media browser: albums, photos, videos, and audio with thumbnails.
/// Returns the selected files as absolute paths to the send screen.
class MediaBrowserScreen extends StatefulWidget {
  const MediaBrowserScreen({super.key});

  @override
  State<MediaBrowserScreen> createState() => _MediaBrowserScreenState();
}

enum _MediaKind { image, video, audio }

const _pageSize = 60;

class _MediaBrowserScreenState extends State<MediaBrowserScreen> {
  bool _loading = true;
  bool _sending = false;
  bool _permissionDenied = false;
  String? _error;
  List<AssetPathEntity> _albums = const [];
  AssetPathEntity? _album;
  List<AssetEntity> _assets = const [];
  final Set<String> _selected = {};
  final Map<String, AssetEntity> _byId = {};
  String _query = '';
  _MediaKind _kind = _MediaKind.image;
  int _nextPage = 0;
  bool _hasMore = true;
  bool _loadingMore = false;
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || _loading || _loadingMore || !_hasMore) return;
    final position = _scroll.position;
    if (position.pixels > position.maxScrollExtent - 480) {
      _loadMore();
    }
  }

  RequestType get _requestType => switch (_kind) {
        _MediaKind.image => RequestType.image,
        _MediaKind.video => RequestType.video,
        _MediaKind.audio => RequestType.audio,
      };

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _permissionDenied = false;
    });
    try {
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.isAuth && !permission.hasAccess) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _permissionDenied = true;
          _error = AppLocalizations.of(context).mediaPermissionOff;
        });
        return;
      }
      final paths = await PhotoManager.getAssetPathList(
        type: _requestType,
        hasAll: true,
      );
      final albums = <AssetPathEntity>[];
      for (final path in paths) {
        if (await path.assetCountAsync > 0) albums.add(path);
      }
      AssetPathEntity? initial;
      if (albums.isNotEmpty) {
        initial = albums.firstWhere(
          (path) => path.isAll,
          orElse: () => albums.first,
        );
      }
      if (!mounted) return;
      setState(() {
        _albums = albums;
        _album = initial;
      });
      if (initial != null) {
        await _loadAssets(initial);
      } else {
        setState(() {
          _assets = const [];
          _byId.clear();
          _loading = false;
        });
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppLocalizations.of(context).mediaReadFailed('$error');
      });
    }
  }

  Future<void> _loadAssets(AssetPathEntity album) async {
    setState(() {
      _loading = true;
      _album = album;
    });
    try {
      final assets = await album.getAssetListPaged(page: 0, size: _pageSize);
      if (!mounted) return;
      setState(() {
        _assets = assets;
        _nextPage = 1;
        _hasMore = assets.length == _pageSize;
        _byId
          ..clear()
          ..addEntries(assets.map((asset) => MapEntry(asset.id, asset)));
        _selected.removeWhere((id) => !_byId.containsKey(id));
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppLocalizations.of(context).albumReadFailed('$error');
      });
    }
  }

  Future<void> _loadMore() async {
    final album = _album;
    if (album == null || _loadingMore || !_hasMore) return;
    _loadingMore = true;
    try {
      final page = await album.getAssetListPaged(
        page: _nextPage,
        size: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _assets = [..._assets, ...page];
        _nextPage += 1;
        _hasMore = page.length == _pageSize;
        for (final asset in page) {
          _byId[asset.id] = asset;
        }
        _loadingMore = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _changeKind(_MediaKind kind) async {
    if (kind == _kind) return;
    setState(() {
      _kind = kind;
      _selected.clear();
      _albums = const [];
      _album = null;
      _assets = const [];
      _byId.clear();
      _nextPage = 0;
      _hasMore = true;
    });
    await _load();
  }

  Future<void> _send() async {
    if (_selected.isEmpty || _sending) return;
    setState(() => _sending = true);
    final files = <File>[];
    for (final id in _selected.toList()) {
      final asset = _byId[id];
      if (asset == null) continue;
      try {
        final file = await asset.file;
        if (file != null && await file.exists()) files.add(file);
      } on Object {
        // A cloud-only asset may not be downloadable; skip it.
      }
    }
    if (!mounted) return;
    setState(() => _sending = false);
    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).mediaItemsUnreadable),
        ),
      );
      return;
    }
    Navigator.of(context).pop(files);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final needle = _query.trim().toLowerCase();
    final visible = _assets
        .where((asset) =>
            needle.isEmpty ||
            (asset.title ?? '').toLowerCase().contains(needle))
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mediaTitle),
        actions: [
          if (_selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Center(
                child: Text(
                  l10n.selectedCount(_selected.length),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                0,
              ),
              child: TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: l10n.searchAlbum,
                  prefixIcon: Icon(AppIcons.search, size: 18),
                  isDense: true,
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                children: [
                  for (final kind in _MediaKind.values)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: ChoiceChip(
                        label: Text(switch (kind) {
                          _MediaKind.image => l10n.photosFilter,
                          _MediaKind.video => l10n.videos,
                          _MediaKind.audio => l10n.audioLabel,
                        }),
                        selected: _kind == kind,
                        onSelected: (_) => _changeKind(kind),
                      ),
                    ),
                ],
              ),
            ),
            if (_albums.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _album?.id,
                  hint: Text(l10n.albumLabel),
                  items: [
                    for (final album in _albums)
                      DropdownMenuItem<String>(
                        value: album.id,
                        child: Text(album.name),
                      ),
                  ],
                  onChanged: (id) {
                    final album = _albums.where((entry) => entry.id == id);
                    if (album.isNotEmpty) _loadAssets(album.first);
                  },
                ),
              ),
            Expanded(child: _body(theme, visible)),
            if (_selected.isNotEmpty)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(AppIcons.send, size: 17),
                      label: Text(
                        _sending
                            ? l10n.preparing
                            : l10n.sendItems(_selected.length),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _body(ThemeData theme, List<AssetEntity> assets) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return EmptyState(
        icon: AppIcons.image,
        title: l10n.mediaUnavailable,
        message: _error!,
        action: OutlinedButton.icon(
          onPressed: () {
            if (_permissionDenied) {
              PhotoManager.openSetting();
            } else {
              _load();
            }
          },
          icon: Icon(AppIcons.refresh, size: 17),
          label: Text(l10n.tryAgain),
        ),
      );
    }
    if (assets.isEmpty) {
      return EmptyState(
        icon: AppIcons.image,
        title: l10n.noMediaHere,
        message: l10n.noMediaHint,
      );
    }
    return GridView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(AppSpacing.xs),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        childAspectRatio: 1,
        crossAxisSpacing: 3,
        mainAxisSpacing: 3,
      ),
      itemCount: assets.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= assets.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final asset = assets[index];
        return RepaintBoundary(
          child: _AssetTile(
            asset: asset,
            selected: _selected.contains(asset.id),
            onTap: () => setState(() {
              if (!_selected.remove(asset.id)) _selected.add(asset.id);
            }),
          ),
        );
      },
    );
  }
}

class _AssetTile extends StatelessWidget {
  const _AssetTile({
    required this.asset,
    required this.selected,
    required this.onTap,
  });

  final AssetEntity asset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = asset.duration;
    final durationLabel = duration >= 3600
        ? '${duration ~/ 3600}:${(duration % 3600 ~/ 60).toString().padLeft(2, '0')}:'
            '${(duration % 60).toString().padLeft(2, '0')}'
        : '${duration ~/ 60}:${(duration % 60).toString().padLeft(2, '0')}';

    return Material(
      color: theme.colorScheme.surfaceContainer,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (asset.type == AssetType.audio)
              Icon(
                AppIcons.music,
                size: 30,
                color: theme.colorScheme.onSurfaceVariant,
              )
            else
              AssetEntityImage(
                asset,
                isOriginal: false,
                thumbnailSize: const ThumbnailSize.square(160),
                errorBuilder: (_, __, ___) => Icon(
                  asset.type == AssetType.video
                      ? AppIcons.video
                      : AppIcons.image,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (asset.type == AssetType.video)
              Positioned(
                left: 6,
                bottom: 6,
                child: Text(
                  durationLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 4)
                    ],
                  ),
                ),
              ),
            Positioned(
              top: 6,
              right: 6,
              child: Icon(
                selected ? AppIcons.checkCircle : AppIcons.circle,
                size: 20,
                color: selected
                    ? theme.colorScheme.primary
                    : Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
