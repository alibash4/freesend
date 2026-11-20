import 'package:material_ui/material_ui.dart';
import 'package:scroll_animator/scroll_animator.dart';
import 'package:free_send/theme/uicons.dart';

import 'package:free_send/l10n/app_localizations.dart';
import 'package:free_send/theme/app_theme.dart';
import 'package:free_send/ui/screens/receive_screen.dart';
import 'package:free_send/ui/screens/send_screen.dart';
import 'package:free_send/ui/widgets/recent_transfers.dart';

/// The two ways into a transfer. Send carries the app's muted blue accent, the
/// same family the bottom navigation uses for its active tab.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onOpenSend, this.onOpenReceive});

  final VoidCallback? onOpenSend;
  final VoidCallback? onOpenReceive;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ScrollController _scrollController = AnimatedScrollController(
    animationFactory: const ChromiumEaseInOut(),
  );

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// The send control comes first; only the chosen entry navigates.
  Future<void> _openSend() async {
    final callback = widget.onOpenSend;
    if (callback == null) {
      final mode = await SendScreen.choose(context);
      if (mode == null || !mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SendScreen(initialMode: mode),
        ),
      );
      return;
    }
    // Shells that own navigation (the app wrapper) still get the tap and raise
    // the control themselves.
    callback();
  }

  void _open(VoidCallback? callback, Widget page) {
    if (callback != null) {
      callback();
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.md),
            Center(
              child: Image.asset('assets/freesend.png', height: 56),
            ),
            const SizedBox(height: AppSpacing.xl),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 600;
                final gap = compact ? AppSpacing.md : AppSpacing.xl;
                final available = constraints.maxWidth;
                // The two actions always sit inline; the cards scale to fit.
                final width = ((available - gap) / 2)
                    .clamp(compact ? 110.0 : 150.0, 230.0);
                final tabs = [
                  _FolderAction(
                    icon: UIcons.solidRounded.upload,
                    title: l10n.sendFile,
                    subtitle: l10n.transferData,
                    width: width,
                    fill:
                        dark ? AppColors.accentWashDark : AppColors.accentWash,
                    ink: dark ? AppColors.accentInkDark : AppColors.accentInk,
                    onTap: _openSend,
                  ),
                  _FolderAction(
                    icon: UIcons.solidRounded.download,
                    title: l10n.receiveFile,
                    subtitle: l10n.receiveData,
                    width: width,
                    fill: dark
                        ? AppColors.successWashDark
                        : AppColors.successWash,
                    ink: dark ? AppColors.successInkDark : AppColors.successInk,
                    onTap: () =>
                        _open(widget.onOpenReceive, const ReceiveScreen()),
                  ),
                ];
                final rowWidth = width * 2 + gap;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        tabs.first,
                        SizedBox(width: gap),
                        tabs.last,
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    SizedBox(
                      width: rowWidth,
                      child: const RecentTransfers(),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A simple rounded action card with centered content.
///
/// The fill is a single neutral token by default; [fill] and [ink] override it
/// for a muted accent variant.
class _FolderAction extends StatelessWidget {
  const _FolderAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.width,
    required this.onTap,
    this.fill,
    this.ink,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final double width;
  final VoidCallback onTap;

  /// Optional muted fill and content colour; the neutral card is the default.
  final Color? fill;
  final Color? ink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final cardFill =
        fill ?? (dark ? AppColors.neutral800 : AppColors.neutral100);
    final cardInk = ink ?? (dark ? AppColors.neutral100 : AppColors.neutral800);
    final height = width * 0.85;

    return Semantics(
      button: true,
      label: title,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Material(
          color: cardFill,
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            mouseCursor: SystemMouseCursors.click,
            onTap: onTap,
            borderRadius: BorderRadius.circular(28),
            splashColor: cardInk.withValues(alpha: 0.08),
            highlightColor: Colors.transparent,
            hoverColor: cardInk.withValues(alpha: 0.04),
            child: SizedBox(
              width: width,
              height: height,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: width * 0.067),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: width * 0.24, color: cardInk),
                    SizedBox(height: height * 0.025),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: cardInk,
                        fontSize: (width * 0.11).clamp(15.0, 18.0),
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: cardInk.withValues(alpha: 0.72),
                        fontSize: (width * 0.08).clamp(11.5, 13.0),
                        height: 1.3,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
