import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:scroll_animator/scroll_animator.dart';

import 'package:free_send/core/app_constants.dart';
import 'package:free_send/core/platform_env.dart';
import 'package:free_send/state/app_state.dart';
import 'package:free_send/state/update_controller.dart';
import 'package:free_send/theme/app_icons.dart';
import 'package:free_send/theme/app_theme.dart';
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
    try {
      final path = await FilePicker.getDirectoryPath(
        dialogTitle: 'Choose where received files go',
      );
      if (path == null || path.isEmpty) return;
      await appState.setDownloadDir(path);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Save location updated')));
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Could not change folder: $error')));
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text('Received files stay on disk.'),
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
    if (confirmed == true) await appState.clearHistory();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = context.watch<AppState>();
    final updateState = context.watch<UpdateController>();

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        Padding(
          padding: kPagePadding.copyWith(top: AppSpacing.md),
          child: Text('Settings', style: theme.textTheme.headlineSmall),
        ),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: kPagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'This device'),
              Text('Device name', style: theme.textTheme.bodySmall),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                focusNode: _focusNode,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _saveName(),
                decoration: const InputDecoration(
                  hintText: 'Shown to the other device during a transfer',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      PlatformEnv.canCreateHotspot
                          ? '${PlatformEnv.label} · can create a hotspot'
                          : '${PlatformEnv.label} · shares over the current network',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: _saveName,
                    child: const Text('Save'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              const SectionHeader(title: 'Received files'),
              Text(
                appState.downloadDir.isEmpty
                    ? 'Not set yet'
                    : appState.downloadDir,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _chooseFolder,
                  icon: const Icon(AppIcons.folderOpen, size: 17),
                  label: const Text('Change folder'),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const SectionHeader(title: 'Appearance'),
              Text('Theme', style: theme.textTheme.bodySmall),
              const SizedBox(height: 6),
              // Three choices in one soft track, so the control reads as a
              // single object on the page.
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Row(
                  children: [
                    for (final (mode, label, icon) in const [
                      (ThemeMode.light, 'Light', AppIcons.sun),
                      (ThemeMode.dark, 'Dark', AppIcons.moon),
                      (ThemeMode.system, 'Auto', AppIcons.auto),
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
              const SizedBox(height: AppSpacing.xl),
              if (PlatformEnv.supportsTray) ...[
                const SectionHeader(title: 'System tray'),
                _UpdateRow(
                  label: 'Minimize to tray on close',
                  subtitle:
                      'Keep FreeSend running in the tray when the window is '
                      'closed.',
                  value: appState.minimizeToTray,
                  onChanged: (value) => appState.setMinimizeToTray(value),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              const SectionHeader(title: 'Data'),
              Text(
                'FreeSend keeps a local list of past transfers and nothing '
                'else. Files are never uploaded — the two devices talk '
                'directly over the hotspot link.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: appState.history.isEmpty
                      ? null
                      : () => _clearHistory(appState),
                  icon: const Icon(AppIcons.trash, size: 17),
                  label: const Text('Clear transfer history'),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const SectionHeader(title: 'Updates'),
              _UpdateRow(
                label: 'Check automatically',
                subtitle:
                    'Look for a newer release every time FreeSend starts.',
                value: appState.autoUpdate,
                onChanged: (value) async {
                  await appState.setAutoUpdate(value);
                  if (!context.mounted) return;
                  context.read<UpdateController>().setAutoCheck(value);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _checkNow,
                  icon: const Icon(AppIcons.refresh, size: 17),
                  label: const Text('Check for updates'),
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
              const SectionHeader(title: 'About'),
              _AboutRow(
                label: 'App',
                value: '${AppConstants.appName} ${updateState.currentVersion}',
              ),
              Divider(height: AppSpacing.lg, color: theme.colorScheme.hairline),
              _AboutRow(
                label: 'Protocol',
                value: 'v${AppConstants.protocolVersion}',
              ),
              Divider(height: AppSpacing.lg, color: theme.colorScheme.hairline),
              _AboutRow(label: 'Platform', value: PlatformEnv.label),
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
    return Material(
      color: selected ? scheme.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: selected ? null : onTap,
        child: SizedBox(
          height: 38,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: foreground),
              const SizedBox(width: 6),
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
          Switch(value: value, onChanged: onChanged),
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
