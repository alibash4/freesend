import 'package:material_ui/material_ui.dart';

import 'package:free_send/l10n/app_localizations.dart';
import 'package:free_send/services/permissions/transfer_setup.dart';
import 'package:free_send/theme/app_icons.dart';
import 'package:free_send/theme/app_theme.dart';

/// Full-screen gate shown before a send or a receive when a required grant
/// is still off. [title] is the only copy that changes between the two.
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

  /// Pushes the gate when Android is missing a grant. Returns true once the
  /// required ones are on, or when this platform has nothing to ask for.
  static Future<bool> ensure(BuildContext context, {required String title}) async {
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
    await TransferSetup.enable(step.index);
    if (!mounted) return;
    setState(() => _busyIndex = null);
    await _reload();
  }

  /// The copy for a step. The grant itself carries no text so the service
  /// stays free of any localization.
  String _titleFor(AppLocalizations l10n, SetupStep step) =>
      switch (step.index) {
        1 => l10n.setupNearbyTitle,
        2 => l10n.setupNotificationsTitle,
        3 => l10n.setupCameraTitle,
        4 => l10n.setupVpnTitle,
        5 => l10n.setupLocationTitle,
        _ => '',
      };

  String _bodyFor(AppLocalizations l10n, SetupStep step) =>
      switch (step.index) {
        1 => l10n.setupNearbyBody,
        2 => l10n.setupNotificationsBody,
        3 => l10n.setupCameraBody,
        4 => l10n.setupVpnBody,
        5 => l10n.setupLocationBody,
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final active = _steps.cast<SetupStep?>().firstWhere(
          (step) => step != null && !step.granted && step.mustGrant,
          orElse: () => null,
        );

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: widget.onLeave ?? () => Navigator.of(context).pop(false),
                icon: Icon(AppIcons.back),
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                widget.title,
                style: AppTypography.pageTitle.copyWith(
                  fontSize: 28,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.setupIntro,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.45,
                    ),
              ),
              const SizedBox(height: AppSpacing.xl),
              for (final step in _steps) ...[
                _StepRow(
                  step: step,
                  title: _titleFor(l10n, step),
                  body: _bodyFor(l10n, step),
                  optionalLabel: l10n.setupOptional,
                  locked:
                      active != null && step.mustGrant && step.index > active.index,
                  busy: _busyIndex == step.index,
                  onEnable: () => _enable(step),
                ),
                if (step != _steps.last)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
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

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.title,
    required this.body,
    required this.optionalLabel,
    required this.locked,
    required this.busy,
    required this.onEnable,
  });

  final SetupStep step;
  final String title;
  final String body;

  /// The tag shown next to a step the transfer does not depend on.
  final String optionalLabel;
  final bool locked;
  final bool busy;
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final titleColor = step.granted
        ? scheme.onSurface
        : locked
            ? scheme.onSurfaceVariant.withValues(alpha: 0.55)
            : scheme.onSurface;
    final bodyColor = locked
        ? scheme.onSurfaceVariant.withValues(alpha: 0.45)
        : scheme.onSurfaceVariant;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: step.granted
                ? Icon(AppIcons.check, size: 18, color: AppColors.success)
                : Text(
                    '${step.index}',
                    style: AppTypography.sectionTitle.copyWith(
                      color: locked ? bodyColor : scheme.onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: AppTypography.sectionTitle.copyWith(
                        color: titleColor,
                      ),
                    ),
                  ),
                  if (!step.mustGrant) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      optionalLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: bodyColor,
                      height: 1.4,
                    ),
              ),
            ],
          ),
        ),
        if (!step.granted && !locked)
          TextButton(
            onPressed: busy ? null : onEnable,
            style: TextButton.styleFrom(
              foregroundColor: scheme.accentText,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(48, 48),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: busy
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.6,
                      color: scheme.accentText,
                    ),
                  )
                : Text(
                    step.needsSettings ? l10n.setupSettings : l10n.setupEnable,
                  ),
          ),
      ],
    );
  }
}
