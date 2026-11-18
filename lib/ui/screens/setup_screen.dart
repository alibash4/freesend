import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'package:free_send/l10n/app_localizations.dart';
import 'package:free_send/services/permissions/transfer_setup.dart';
import 'package:free_send/state/app_state.dart';
import 'package:free_send/theme/app_icons.dart';
import 'package:free_send/theme/app_theme.dart';
import 'package:free_send/ui/widgets/common.dart';

/// Full-screen gate shown before a send or a receive while a required grant
/// is still off. [title] is the only copy that changes between the two.
/// Permission rows can be granted here, in context; device settings that
/// only the user can flip are status rows that re-check on return.
class SetupScreen extends StatefulWidget {
  const SetupScreen({
    super.key,
    required this.title,
    this.onReady,
    this.onLeave,
  });

  final String title;

  /// Called once every required step is on. When null, the route pops with
  /// `true`.
  final VoidCallback? onReady;

  /// Called from the back control. When null, the route pops with `false`.
  final VoidCallback? onLeave;

  /// Pushes the gate when Android is missing a required grant. Returns true
  /// once they are on, or when this platform has nothing to ask for.
  static Future<bool> ensure(BuildContext context,
      {required String title}) async {
    if (!TransferSetup.applies || await TransferSetup.isReady) return true;
    if (!context.mounted) return false;
    final ready = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => SetupScreen(title: title),
      ),
    );
    return ready ?? false;
  }

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> with WidgetsBindingObserver {
  List<SetupStep> _steps = const [];

  /// The step whose system dialog is open. Null when nothing is in flight.
  int? _busyIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reload();
  }

  Future<void> _reload() async {
    final steps = await TransferSetup.load();
    if (!mounted) return;
    if (steps.isNotEmpty &&
        steps.every((step) => step.granted || !step.mustGrant)) {
      final onReady = widget.onReady;
      if (onReady != null) {
        onReady();
      } else {
        Navigator.of(context).pop(true);
      }
      return;
    }
    setState(() => _steps = steps);
  }

  Future<void> _enable(SetupStep step) async {
    if (_busyIndex != null) return;
    setState(() => _busyIndex = step.index);
    await TransferSetup.enable(step);
    if (!mounted) return;
    setState(() => _busyIndex = null);
    await _reload();
  }

  /// The copy for a step. The check itself carries no text so the service
  /// stays free of any localization.
  String _titleFor(AppLocalizations l10n, SetupStep step) =>
      switch (step.kind) {
        SetupKind.nearby => l10n.setupNearbyTitle,
        SetupKind.notifications => l10n.setupNotificationsTitle,
        SetupKind.wifi => l10n.setupWifiTitle,
        SetupKind.vpn => l10n.setupVpnTitle,
        SetupKind.location => l10n.setupLocationTitle,
      };

  String _bodyFor(AppLocalizations l10n, SetupStep step) => switch (step.kind) {
        SetupKind.nearby => l10n.setupNearbyBody,
        SetupKind.notifications => l10n.setupNotificationsBody,
        SetupKind.wifi => l10n.setupWifiBody,
        SetupKind.vpn => l10n.setupVpnBody,
        SetupKind.location => l10n.setupLocationBody,
      };

  IconData _iconFor(SetupStep step) => switch (step.kind) {
        SetupKind.nearby => AppIcons.hotspot,
        SetupKind.notifications => AppIcons.bell,
        SetupKind.wifi => AppIcons.wifi,
        SetupKind.vpn => AppIcons.shieldAlert,
        SetupKind.location => AppIcons.locationPin,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final active = _steps.cast<SetupStep?>().firstWhere(
          (step) => step != null && !step.granted && step.mustGrant,
          orElse: () => null,
        );

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md)
              .copyWith(top: AppSpacing.lg, bottom: AppSpacing.xl),
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: IconButton(
                onPressed: () {
                  context.read<AppState>().tick();
                  final leave = widget.onLeave;
                  if (leave != null) {
                    leave();
                  } else {
                    Navigator.of(context).pop(false);
                  }
                },
                icon: Icon(backGlyph),
                mouseCursor: SystemMouseCursors.click,
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: AppTypography.pageTitle.copyWith(
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.setupIntro,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            for (final step in _steps) ...[
              _SetupRow(
                icon: _iconFor(step),
                step: step,
                title: _titleFor(l10n, step),
                body: _bodyFor(l10n, step),
                optionalLabel: l10n.setupOptional,
                locked: active != null &&
                    step.mustGrant &&
                    step.index > active.index,
              ),
              if (step != _steps.last)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Container(height: 1, color: scheme.hairline),
                ),
            ],
            if (active != null && active.isActionable) ...[
              const SizedBox(height: AppSpacing.xl),
              Center(
                child: FilledButton(
                  style: clickCursorStyle,
                  onPressed: _busyIndex == null ? () => _enable(active) : null,
                  child: _busyIndex == active.index
                      ? const SpinnerIcon(size: 16)
                      : Text(
                          active.needsSettings
                              ? l10n.setupSettings
                              : l10n.setupEnable,
                        ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: TextButton.icon(
                style: clickCursorStyle,
                onPressed: () {
                  context.read<AppState>().tick();
                  _reload();
                },
                icon: Icon(AppIcons.refresh, size: 16),
                label: Text(l10n.setupCheckAgain),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One requirement in the gate list, styled like the permission rows: muted
/// icon, title, explanatory body, and a status label on the trailing edge.
class _SetupRow extends StatelessWidget {
  const _SetupRow({
    required this.icon,
    required this.step,
    required this.title,
    required this.body,
    required this.optionalLabel,
    required this.locked,
  });

  final IconData icon;
  final SetupStep step;
  final String title;
  final String body;

  /// The tag shown next to a check the transfer does not depend on.
  final String optionalLabel;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final tint = step.granted ? AppColors.success : scheme.error;
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (!step.mustGrant) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      optionalLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (step.granted) ...[
                Icon(AppIcons.check, size: 14, color: tint),
                const SizedBox(width: 4),
              ],
              Text(
                step.granted ? l10n.setupDone : l10n.setupActionNeeded,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 12,
                  color: tint,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    return Opacity(opacity: locked ? 0.45 : 1, child: row);
  }
}
