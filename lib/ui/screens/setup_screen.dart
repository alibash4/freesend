import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'package:free_send/l10n/app_localizations.dart';
import 'package:free_send/services/permissions/transfer_setup.dart';
import 'package:free_send/state/app_state.dart';
import 'package:free_send/theme/app_icons.dart';
import 'package:free_send/theme/app_theme.dart';
import 'package:free_send/ui/widgets/collapsing_title.dart';
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
  final ScrollController _scrollController = ScrollController();

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
    _scrollController.dispose();
    super.dispose();
  }

  void _leave() {
    context.read<AppState>().tick();
    final leave = widget.onLeave;
    if (leave != null) {
      leave();
    } else {
      Navigator.of(context).pop(false);
    }
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

  /// The label on a row's inline action. Permission kinds ask the system;
  /// permanently-denied ones and the status rows (Wi-Fi, VPN, location)
  /// send the user to the matching settings page.
  String _actionLabelFor(AppLocalizations l10n, SetupStep step) =>
      step.needsSettings || !step.isActionable
          ? l10n.setupSettings
          : l10n.setupEnable;

  IconData _iconFor(SetupStep step) => switch (step.kind) {
        SetupKind.nearby => AppIcons.devices,
        SetupKind.notifications => AppIcons.bell,
        SetupKind.wifi => AppIcons.wifi,
        SetupKind.vpn => AppIcons.vpnShield,
        SetupKind.location => AppIcons.locationPin,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: CollapsingHeader(
          controller: _scrollController,
          title: widget.title,
          leading: Transform.translate(
            offset: const Offset(-7, 0),
            child: IconButton(
              onPressed: _leave,
              icon: Icon(backGlyph(context), size: 25),
              mouseCursor: SystemMouseCursors.click,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              alignment: Alignment.centerLeft,
            ),
          ),
          child: ListView(
            controller: _scrollController,
            padding: EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.md,
              top: CollapsingHeader.expandedHeight + AppSpacing.md,
              bottom: AppSpacing.xl,
            ),
            children: [
              Text(
                l10n.setupIntro,
                textAlign: TextAlign.start,
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
                  actionLabel: _actionLabelFor(l10n, step),
                  busy: _busyIndex == step.index,
                  onAction: () => _enable(step),
                ),
                if (step != _steps.last)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Container(height: 1, color: scheme.hairline),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One requirement in the gate list, styled like the permission rows: muted
/// icon, title, explanatory body, and an inline action on the trailing edge -
/// a Done status once met, or the button that fixes it while it is not.
class _SetupRow extends StatelessWidget {
  const _SetupRow({
    required this.icon,
    required this.step,
    required this.title,
    required this.body,
    required this.optionalLabel,
    required this.actionLabel,
    required this.busy,
    required this.onAction,
  });

  final IconData icon;
  final SetupStep step;
  final String title;
  final String body;

  /// The tag shown next to a check the transfer does not depend on.
  final String optionalLabel;

  /// Label for the trailing button while the step is unmet.
  final String actionLabel;

  /// True while this row's system prompt or settings jump is in flight.
  final bool busy;
  final VoidCallback onAction;

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
          child: step.granted
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(AppIcons.check, size: 14, color: tint),
                    const SizedBox(width: 4),
                    Text(
                      l10n.setupDone,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 12,
                        color: tint,
                      ),
                    ),
                  ],
                )
              : OutlinedButton(
                  style: clickCursorStyle.copyWith(
                    backgroundColor: WidgetStatePropertyAll(
                      scheme.surfaceContainerHigh,
                    ),
                    foregroundColor: WidgetStatePropertyAll(scheme.onSurface),
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 10),
                    ),
                    minimumSize: const WidgetStatePropertyAll(Size(0, 20)),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    side: const WidgetStatePropertyAll(BorderSide.none),
                  ),
                  onPressed: busy ? null : onAction,
                  child: busy
                      // A fixed slot keeps the spinner centered without
                      // resizing the button between labels.
                      ? const SizedBox(
                          width: 28,
                          height: 20,
                          child: Center(child: SpinnerIcon(size: 12)),
                        )
                      : Text(
                          actionLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
        ),
      ],
    );
    return row;
  }
}
