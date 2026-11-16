import 'package:material_ui/material_ui.dart';

import 'package:free_send/theme/app_theme.dart';
import 'package:free_send/ui/kit/app_bottom_nav.dart';

/// Desktop navigation rail. Uses the same items and colour language as the
/// mobile bottom island, but as a persistent vertical list.
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<AppNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 240,
      height: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surface,
        border: BorderDirectional(
          end: BorderSide(
            color: dark ? const Color(0xFF2C2C2C) : scheme.hairline,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            child: Row(
              children: [
                Image.asset('assets/freesend.png', height: 32),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'FreeSend',
                    style: AppTypography.pageTitle.copyWith(
                      color: dark ? AppColors.neutral100 : AppColors.neutral800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
              ),
              children: [
                for (var i = 0; i < items.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: _SidebarItemView(
                      item: items[i],
                      selected: i == selectedIndex,
                      onTap: () => onSelected(i),
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

class _SidebarItemView extends StatelessWidget {
  const _SidebarItemView({
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
    final color = selected ? AppColors.accent : scheme.onSurfaceVariant;
    final labelColor = selected ? scheme.onSurface : scheme.onSurfaceVariant;
    final hoverColor =
        dark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04);
    final highlightColor =
        dark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04);
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Row(
          children: [
            SizedBox(
              width: 12,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: AnimatedContainer(
                  duration: AppMotion.base,
                  curve: AppMotion.standard,
                  width: 3,
                  height: selected ? 20 : 0,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Material(
                color: selected
                    ? (dark
                        ? Colors.white.withValues(alpha: 0.08)
                        : AppColors.neutral100)
                    : scheme.surface,
                borderRadius: BorderRadius.circular(AppRadii.field),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  mouseCursor: SystemMouseCursors.click,
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(AppRadii.field),
                  hoverColor: hoverColor,
                  splashColor: scheme.accentText.withValues(alpha: 0.12),
                  highlightColor: highlightColor,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected ? item.activeIcon : item.icon,
                          size: 21,
                          color: color,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.navLabel.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
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
          ],
        ),
      ),
    );
  }
}