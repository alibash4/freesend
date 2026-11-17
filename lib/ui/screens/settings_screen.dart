import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:scroll_animator/scroll_animator.dart';

import 'package:free_send/core/app_constants.dart';
import 'package:free_send/core/platform_env.dart';
import 'package:free_send/l10n/app_localizations.dart';
import 'package:free_send/state/app_state.dart';
import 'package:free_send/state/update_controller.dart';
import 'package:free_send/theme/app_icons.dart';
import 'package:free_send/theme/app_theme.dart';
import 'package:free_send/ui/kit/app_page_title.dart';
import 'package:free_send/ui/shell.dart';
import 'package:free_send/ui/widgets/common.dart';
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
  late final TextEditingController _nameController =
      TextEditingController(text: context.read<AppState>().deviceName);
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
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

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        Padding(
          padding: kPagePadding.copyWith(top: AppSpacing.md),
          child: AppPageTitle(l10n.settings),
        ),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: kPagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(title: l10n.thisDevice),
              Text(l10n.deviceName, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                focusNode: _focusNode,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _saveName(),
                decoration: InputDecoration(
                  hintText: l10n.deviceNameHint,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  constraints: const BoxConstraints(minHeight: 40),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      PlatformEnv.canCreateHotspot
                          ? l10n.platformCanHotspot(PlatformEnv.label)
                          : l10n.platformSharesNetwork(PlatformEnv.label),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: _saveName,
                    child: Text(l10n.save),
                  ),
                ],
              ),
              if (PlatformEnv.kind == PlatformKind.android ||
                  PlatformEnv.kind == PlatformKind.ios) ...[
                const SizedBox(height: AppSpacing.sm),
                _UpdateRow(
                  label: l10n.hapticFeedback,
                  subtitle: l10n.hapticFeedbackSubtitle,
                  value: appState.haptics,
                  onChanged: (value) => appState.setHaptics(value),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              SectionHeader(title: l10n.receivedFiles),
              Text(
                appState.downloadDir.isEmpty
                    ? l10n.notSetYet
                    : appState.downloadDir,
                style: theme.textTheme.bodyMedium,
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
                    onPressed: _chooseFolder,
                    icon: Icon(AppIcons.folderOpen, size: 17),
                    label: Text(l10n.changeFolder),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SectionHeader(title: l10n.appearance),
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
                      (ThemeMode.system, l10n.auto,
                        PlatformEnv.isDesktop
                            ? AppIcons.auto
                            : AppIcons.deviceMobile),
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
              const SizedBox(height: AppSpacing.xl),
              Text(l10n.language, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 6),
              Container(
                height: 45,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppRadii.field),
                ),
                child: Row(
                  spacing: 4,
                  children: [
                    Expanded(
                      child: _LanguageChoice(
                        label: l10n.arabic,
                        selected: appState.locale.languageCode == 'ar',
                        onTap: () => appState.setLocale(const Locale('ar')),
                      ),
                    ),
                    Expanded(
                      child: _LanguageChoice(
                        label: l10n.english,
                        selected: appState.locale.languageCode == 'en',
                        onTap: () => appState.setLocale(const Locale('en')),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (PlatformEnv.supportsTray) ...[
                SectionHeader(title: l10n.systemTray),
                _UpdateRow(
                  label: l10n.minimizeToTray,
                  subtitle: l10n.keepRunningInTray,
                  value: appState.minimizeToTray,
                  onChanged: (value) => appState.setMinimizeToTray(value),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              SectionHeader(title: l10n.data),
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
              const SizedBox(height: AppSpacing.xl),
              SectionHeader(title: l10n.updates),
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
                    onPressed: _checkNow,
                    icon: Icon(AppIcons.refresh, size: 17),
                    label: Text(l10n.checkForUpdates),
                  ),
                ),
              ),
              if (updateState.message != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  updateState.message!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: updateState.phase == UpdatePhase.failed
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              SectionHeader(title: l10n.about),
              _AboutRow(
                label: l10n.app,
                value: '${AppConstants.appName} ${updateState.currentVersion}',
              ),
              Divider(height: AppSpacing.lg, color: theme.colorScheme.hairline),
              _AboutRow(
                label: l10n.protocol,
                value: 'v${AppConstants.protocolVersion}',
              ),
              Divider(height: AppSpacing.lg, color: theme.colorScheme.hairline),
              _AboutRow(label: l10n.platform, value: PlatformEnv.label),
            ],
          ),
        ),
      ],
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
                SizedBox(
                  width: 21,
                  child: AnimatedScale(
                    scale: selected ? 1 : 0,
                    duration: AppMotion.base,
                    curve: Curves.easeOutBack,
                    child: Icon(icon, size: 15, color: foreground),
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

class _LanguageChoice extends StatelessWidget {
  const _LanguageChoice({
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
    final scheme = theme.colorScheme;
    final foreground =
        selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: selected ? scheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.field - 3),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          mouseCursor: SystemMouseCursors.click,
          onTap: selected ? null : onTap,
          child: SizedBox(
            height: 37,
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: foreground,
                ),
              ),
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
                if (context.read<AppState>().haptics) {
                  HapticFeedback.selectionClick();
                }
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
    return Row(
      children: [
        Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
