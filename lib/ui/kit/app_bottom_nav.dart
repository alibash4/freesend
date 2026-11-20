import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

import 'package:free_send/theme/app_theme.dart';

/// Bottom scroll clearance that keeps the last items reachable above the
/// floating pill: pill height + its gap + the system inset + a small buffer.
double floatingNavClearance(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom + 72;

/// A destination in [AppBottomNav]. Eva Icons provides both outline and fill
/// variants, so the active tab uses the filled icon without a pill or ripple.
@immutable
class AppNavItem {
  const AppNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Custom bottom navigation. No Material `NavigationBar`, indicator pill, ink
/// splash, or ripple. The bar is full-width with a single top hairline.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.floating = false,
  });

  final List<AppNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// When true the bar floats as a frosted-glass pill with a soft shadow
  /// instead of docking edge-to-edge behind a hairline.
  final bool floating;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final itemsRow = SizedBox(
      height: 56,
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: _AppNavItemView(
                item: items[i],
                selected: i == selectedIndex,
                onTap: () => onSelected(i),
              ),
            ),
        ],
      ),
    );

    if (floating) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: ClipRRect(
            // Concentric with the selected item's pill: AppRadii.field (10)
            // plus the ~5.5px gap between the 45px pill and the 56px bar.
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(
                    alpha: dark ? 0.55 : 0.60,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: dark
                        ? Colors.white.withValues(alpha: 0.08)
                        : scheme.hairline,
                  ),
                  boxShadow: dark
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.30),
                            blurRadius: 24,
                            spreadRadius: -8,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : const [
                          // All-around ambient shadow: a tight core plus a
                          // wide soft falloff, so the island lifts evenly.
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 10,
                            spreadRadius: -4,
                          ),
                          BoxShadow(
                            color: Color(0x0F000000),
                            blurRadius: 32,
                            spreadRadius: -12,
                          ),
                        ],
                ),
                child: itemsRow,
              ),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.hairline, width: 1),
        ),
      ),
      child: SafeArea(top: false, child: itemsRow),
    );
  }
}

class _AppNavItemView extends StatelessWidget {
  const _AppNavItemView({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final idle = dark ? AppColors.neutral300 : AppColors.neutral700;
    final color = selected ? AppColors.accent : idle;
    final labelColor = selected ? scheme.onSurface : idle;
    final activeBackground = dark
        ? Colors.white.withValues(
            alpha: scheme.isBlackVariant ? 0.05 : 0.08,
          )
        : AppColors.neutral100;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<Color?>(
                  tween: ColorTween(
                    end: selected
                        ? activeBackground
                        : activeBackground.withValues(alpha: 0),
                  ),
                  duration: AppMotion.base,
                  curve: AppMotion.standard,
                  builder: (context, background, _) => SizedBox(
                    width: 67,
                    height: 45,
                    child: Material(
                      color: background,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.field),
                      ),
                      child: InkWell(
                        onTap: onTap,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              selected ? item.activeIcon : item.icon,
                              size: 23,
                              color: color,
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                item.label,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.visible,
                                style: AppTypography.navLabel.copyWith(
                                  color: labelColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedContainer(
                  duration: AppMotion.base,
                  curve: AppMotion.standard,
                  width: selected ? 20 : 0,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
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
