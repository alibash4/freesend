import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:scroll_animator/scroll_animator.dart';

import 'package:free_send/ui/screens/icon_gallery_screen.dart';
import 'package:free_send/ui/screens/logs_screen.dart';
import 'package:free_send/core/app_constants.dart';
import 'package:free_send/core/platform_env.dart';
import 'package:free_send/l10n/app_localizations.dart';
import 'package:free_send/state/app_state.dart';
import 'package:free_send/state/update_controller.dart';
import 'package:free_send/theme/app_icons.dart';
import 'package:free_send/theme/app_theme.dart';
import 'package:free_send/ui/kit/app_bottom_nav.dart';
import 'package:free_send/ui/shell.dart';
import 'package:free_send/ui/widgets/collapsing_title.dart';
import 'package:free_send/ui/widgets/common.dart';
import 'package:free_send/ui/widgets/app_toast.dart';
import 'package:free_send/ui/widgets/update_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final ScrollController _scrollController = AnimatedScrollController(
    animationFactory: const ChromiumEaseInOut(),
  );
  late final TextEditingController _nameController;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Read eagerly: a lazy field initializer would run context.read during
    // dispose if the field was never touched during build.
    _nameController =
        TextEditingController(text: context.read<AppState>().deviceName);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _saveName();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _focusNode.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final appState = context.read<AppState>();
    final value = _nameController.text.trim();
    if (value.isEmpty) {
      _nameController.text = appState.deviceName;
      return;
    }
    await appState.setDeviceName(value);
    if (!mounted) return;
    AppToast.show(
      context,
      AppLocalizations.of(context).deviceNameUpdated,
    );
  }

  Future<String?> _pickLocaleDesktop(
    BuildContext context,
    BuildContext buttonContext,
    AppLocalizations l10n,
  ) async {
    final overlayBox =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final buttonBox = buttonContext.findRenderObject()! as RenderBox;
    final position = RelativeRect.fromRect(
      buttonBox.localToGlobal(Offset.zero, ancestor: overlayBox) &
          buttonBox.size,
      Offset.zero & overlayBox.size,
    );
    // Each item is padded by AppSpacing.sm on both sides inside the menu, so
    // the inner tile is narrower than the trigger by that amount.
    final tileWidth = buttonBox.size.width - AppSpacing.sm * 2;
    final current = context.read<AppState>().locale.languageCode;
    final choices = [
      ('ar', l10n.arabic),
      ('en', l10n.english),
    ]..sort(
        (a, b) => (a.$1 == current ? 0 : 1).compareTo(b.$1 == current ? 0 : 1),
      );
    return showMenu<String>(
      context: context,
      position: position,
      items: [
        for (final (code, label) in choices)
          _MenuItem(
            value: code,
            label: label,
            selected: current == code,
            width: tileWidth,
          ),
      ],
    );
  }

  /// Last path segment of a directory path, tolerating both separators and a
  /// trailing slash. Returns the input unchanged when it has no segments.
  String _dirName(String path) {
    final parts = path.split(RegExp(r'[\\/]')).where((part) => part.isNotEmpty);
    return parts.isEmpty ? path : parts.last;
  }

  Future<String?> _pickLocaleSheet(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final current = context.read<AppState>().locale.languageCode;
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (code, label) in [
              ('ar', l10n.arabic),
              ('en', l10n.english),
            ])
              ListTile(
                leading: current == code
                    ? Icon(
                        AppIcons.check,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : const SizedBox(width: 18),
                title: Text(label),
                onTap: () {
                  sheetContext.read<AppState>().tick();
                  Navigator.of(sheetContext).pop(code);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _renameDevice() async {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    _nameController.text = context.read<AppState>().deviceName;
    final editor = Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        PlatformEnv.isDesktop ? AppSpacing.lg : AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.deviceName, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _nameController,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _saveNameAndClose(),
            decoration: InputDecoration(
              labelText: l10n.deviceName,
              hintText: l10n.deviceNameHint,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton(
              style: ButtonStyle(
                mouseCursor: WidgetStatePropertyAll(
                  SystemMouseCursors.click,
                ),
              ),
              onPressed: () {
                context.read<AppState>().tick();
                _saveNameAndClose();
              },
              child: Text(l10n.save),
            ),
          ),
        ],
      ),
    );
    if (PlatformEnv.isDesktop) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 48,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: editor,
          ),
        ),
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        // viewInsets must be read inside the sheet so the content rides up
        // with the keyboard instead of sitting behind it.
        builder: (sheetContext) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: SafeArea(top: false, child: editor),
        ),
      );
    }
  }

  void _saveNameAndClose() {
    _saveName();
    Navigator.of(context).pop();
  }

  Future<void> _chooseFolder() async {
    final appState = context.read<AppState>();
    final l10n = AppLocalizations.of(context);
    try {
      final path = await FilePicker.getDirectoryPath(
        dialogTitle: l10n.chooseFolderTitle,
      );
      if (path == null || path.isEmpty) return;
      await appState.setDownloadDir(path);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.saveLocationUpdated)));
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.couldNotChangeFolder(error.toString()))),
        );
    }
  }

  Future<void> _checkNow() async {
    final updates = context.read<UpdateController>();
    await updates.checkManually();
    if (!mounted) return;
    if (updates.phase == UpdatePhase.available) {
      await UpdateSheet.show(context);
    } else if (updates.phase == UpdatePhase.upToDate) {
      Timer(const Duration(seconds: 3), () {
        if (mounted) updates.dismiss();
      });
    }
  }

  Future<void> _clearHistory(AppState appState) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearHistoryQuestion),
        content: Text(l10n.receivedFilesStay),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.clear),
          ),
        ],
      ),
    );
    if (confirmed == true) await appState.clearHistory();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = context.watch<AppState>();
    final updateState = context.watch<UpdateController>();
    final l10n = AppLocalizations.of(context);

    return CollapsingHeader(
      controller: _scrollController,
      title: l10n.settings,
      child: ListView(
        controller: _scrollController,
        padding: EdgeInsets.only(
          top: CollapsingHeader.expandedHeight + AppSpacing.md,
          bottom: AppSpacing.xl +
              (appState.floatingNav ? floatingNavClearance(context) : 0),
        ),
        children: [
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: kPagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(title: l10n.general, icon: AppIcons.sliders),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.deviceName,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    SizedBox(
                      width: 168,
                      child: OutlinedButton(
                        style: ButtonStyle(
                          mouseCursor: WidgetStatePropertyAll(
                            SystemMouseCursors.click,
                          ),
                        ),
                        onPressed: () {
                          appState.tick();
                          _renameDevice();
                        },
                        child: Text(
                          appState.deviceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.saveLocation,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    SizedBox(
                      width: 168,
                      child: OutlinedButton(
                        style: ButtonStyle(
                          mouseCursor: WidgetStatePropertyAll(
                            SystemMouseCursors.click,
                          ),
                        ),
                        onPressed: () {
                          appState.tick();
                          _chooseFolder();
                        },
                        child: Text(
                          appState.downloadDir.isEmpty
                              ? l10n.notSetYet
                              : _dirName(appState.downloadDir),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
                SectionHeader(
                  title: PlatformEnv.isDesktop
                      ? l10n.appearance
                      : l10n.lookAndFeel,
                  icon: AppIcons.palette,
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.language,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    SizedBox(
                      width: 168,
                      child: Builder(
                        builder: (buttonContext) => OutlinedButton(
                          style: ButtonStyle(
                            mouseCursor: WidgetStatePropertyAll(
                              SystemMouseCursors.click,
                            ),
                          ),
                          onPressed: () async {
                            appState.tick();
                            final value = PlatformEnv.isDesktop
                                ? await _pickLocaleDesktop(
                                    context,
                                    buttonContext,
                                    l10n,
                                  )
                                : await _pickLocaleSheet(context, l10n);
                            if (value != null) {
                              // Let the popup/sheet finish its dismiss
                              // animation before flipping directionality,
                              // otherwise the exiting menu jumps position.
                              await Future<void>.delayed(
                                const Duration(milliseconds: 300),
                              );
                              if (!mounted) return;
                              appState.setLocale(Locale(value));
                            }
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  appState.locale.languageCode == 'ar'
                                      ? l10n.arabic
                                      : l10n.english,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.keyboard_arrow_down,
                                size: 17,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(l10n.theme, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 6),
                // Three choices in one soft track, so the control reads as a
                // single object on the page.
                Container(
                  height: 45,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppRadii.field),
                  ),
                  child: _SlidingPill(
                    selectedIndex: [
                      ThemeMode.light,
                      ThemeMode.dark,
                      ThemeMode.system,
                    ].indexOf(appState.themeMode),
                    count: 3,
                    child: Row(
                      spacing: 4,
                      children: [
                        for (final (mode, label, icon) in [
                          (ThemeMode.light, l10n.light, AppIcons.sun),
                          (ThemeMode.dark, l10n.dark, AppIcons.moon),
                          (
                            ThemeMode.system,
                            l10n.auto,
                            PlatformEnv.isDesktop
                                ? AppIcons.auto
                                : AppIcons.deviceMobile
                          ),
                        ])
                          Expanded(
                            child: _ThemeChoice(
                              label: label,
                              icon: icon,
                              selected: appState.themeMode == mode,
                              onTap: () => appState.setThemeMode(mode),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _UpdateRow(
                  label: l10n.black,
                  subtitle: l10n.blackThemeSubtitle,
                  value: appState.blackTheme,
                  onChanged: (value) => appState.setBlackTheme(value),
                ),
                // The floating pill only exists where the bottom navigation
                // does - phones. Desktop uses the sidebar instead.
                if (PlatformEnv.kind == PlatformKind.android ||
                    PlatformEnv.kind == PlatformKind.ios) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _UpdateRow(
                    label: l10n.floatingNav,
                    subtitle: l10n.floatingNavSubtitle,
                    value: appState.floatingNav,
                    onChanged: (value) => appState.setFloatingNav(value),
                  ),
                ],
                if (PlatformEnv.kind == PlatformKind.android ||
                    PlatformEnv.kind == PlatformKind.ios) ...[
                  const SizedBox(height: AppSpacing.xl),
                  _UpdateRow(
                    label: l10n.hapticFeedback,
                    subtitle: l10n.hapticFeedbackSubtitle,
                    value: appState.haptics,
                    onChanged: (value) => appState.setHaptics(value),
                  ),
                  if (appState.haptics) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.hapticIntensity,
                      style: theme.textTheme.bodySmall,
                    ),
                    Slider(
                      value: appState.hapticIntensity,
                      min: 0,
                      max: 1,
                      divisions: 1,
                      onChanged: appState.setHapticIntensity,
                    ),
                  ],
                ],
                const SizedBox(height: AppSpacing.xxl),
                SectionHeader(title: l10n.system, icon: AppIcons.apps),
                if (PlatformEnv.supportsTray) ...[
                  _UpdateRow(
                    label: l10n.minimizeToTray,
                    subtitle: l10n.keepRunningInTray,
                    value: appState.minimizeToTray,
                    onChanged: (value) => appState.setMinimizeToTray(value),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                Text(l10n.diagnostics, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 6),
                Text(
                  l10n.diagnosticsBody,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton.icon(
                    style: clickCursorStyle,
                    onPressed: () {
                      context.read<AppState>().tick();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LogsScreen(),
                        ),
                      );
                    },
                    icon: Icon(AppIcons.info, size: 17),
                    label: Text(l10n.openLogs),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _UpdateRow(
                  label: l10n.checkAutomatically,
                  subtitle: l10n.lookForNewerRelease,
                  value: appState.autoUpdate,
                  onChanged: (value) async {
                    await appState.setAutoUpdate(value);
                    if (!context.mounted) return;
                    context.read<UpdateController>().setAutoCheck(value);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: OutlinedButton.icon(
                      style: ButtonStyle(
                        mouseCursor: WidgetStatePropertyAll(
                          SystemMouseCursors.click,
                        ),
                      ),
                      onPressed: updateState.phase == UpdatePhase.checking
                          ? null
                          : _checkNow,
                      icon: updateState.phase == UpdatePhase.checking
                          ? const SpinnerIcon(size: 16)
                          : Icon(AppIcons.refresh, size: 17),
                      label: Text(
                        updateState.phase == UpdatePhase.checking
                            ? l10n.checkingUpdates
                            : l10n.checkForUpdates,
                      ),
                    ),
                  ),
                ),
                if (updateState.localizedMessage(l10n).isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    updateState.localizedMessage(l10n),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: updateState.phase == UpdatePhase.failed
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Text(l10n.history, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 6),
                Text(
                  l10n.localDataExplanation,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: OutlinedButton.icon(
                      style: ButtonStyle(
                        mouseCursor: WidgetStatePropertyAll(
                          SystemMouseCursors.click,
                        ),
                      ),
                      onPressed: appState.history.isEmpty
                          ? null
                          : () => _clearHistory(appState),
                      icon: Icon(AppIcons.trash, size: 17),
                      label: Text(l10n.clearTransferHistory),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                SectionHeader(title: l10n.about, icon: AppIcons.info),
                _AboutRow(
                  label: l10n.app,
                  value:
                      '${AppConstants.appName} ${updateState.currentVersion}',
                ),
                Divider(
                    height: AppSpacing.lg, color: theme.colorScheme.hairline),
                _AboutRow(
                  label: l10n.protocol,
                  value: 'v${AppConstants.protocolVersion}',
                ),
                Divider(
                    height: AppSpacing.lg, color: theme.colorScheme.hairline),
                _AboutRow(label: l10n.platform, value: PlatformEnv.label),
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    style: ButtonStyle(
                      mouseCursor: WidgetStatePropertyAll(
                        SystemMouseCursors.click,
                      ),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const IconGalleryScreen(),
                      ),
                    ),
                    icon: Icon(AppIcons.apps, size: 17),
                    label: Text(l10n.iconGallery),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground =
        selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.field - 3),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          mouseCursor: SystemMouseCursors.click,
          onTap: selected ? null : onTap,
          child: SizedBox(
            height: 37,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: AppMotion.base,
                  curve: Curves.easeOutBack,
                  width: selected ? 21 : 0,
                  child: ClipRect(
                    child: AnimatedScale(
                      scale: selected ? 1 : 0,
                      duration: AppMotion.base,
                      curve: Curves.easeOutBack,
                      child: Icon(icon, size: 15, color: foreground),
                    ),
                  ),
                ),
                // A choice slot is a third of a narrow page wide, so the label
                // ellipsises instead of spilling over the next choice.
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UpdateRow extends StatelessWidget {
  const _UpdateRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Switch(
              value: value,
              onChanged: (next) {
                context.read<AppState>().tick();
                onChanged(next);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// The moving selection pill behind a segmented strip. [child] is the row of
/// choices; the pill slides to [selectedIndex] with the app's standard
/// 200ms ease-out motion.
class _SlidingPill extends StatelessWidget {
  const _SlidingPill({
    required this.selectedIndex,
    required this.count,
    required this.child,
  });

  final int selectedIndex;
  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        AnimatedAlign(
          duration: AppMotion.base,
          curve: Curves.easeOutCubic,
          alignment: AlignmentDirectional(
            count <= 1 ? 0 : 2 * selectedIndex / (count - 1) - 1,
            0,
          ),
          child: FractionallySizedBox(
            widthFactor: 1 / count,
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadii.field - 3),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// A popup-menu entry rendered as its own rounded, padded tile so the menu
/// reads like the rest of the app's surfaces instead of a flat list.
class _MenuItem extends PopupMenuEntry<String> {
  const _MenuItem({
    required this.value,
    required this.label,
    required this.selected,
    required this.width,
  });

  final String value;
  final String label;
  final bool selected;
  final double width;

  @override
  double get height => 44;

  @override
  bool represents(String? value) => value == this.value;

  @override
  State<PopupMenuEntry<String>> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.field),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(AppRadii.field),
          onTap: () {
            context.read<AppState>().tick();
            Navigator.pop(context, widget.value);
          },
          child: SizedBox(
            width: widget.width,
            height: 40,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.label,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  if (widget.selected)
                    Icon(
                      AppIcons.check,
                      size: 15,
                      color: theme.colorScheme.primary,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
