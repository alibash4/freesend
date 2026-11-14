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
    return Container(
      width: 240,
      height: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.ink,
        border: const Border(
          right: BorderSide(color: Color(0xFF2C2C2C), width: 1),
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
                      color: AppColors.neutral100,
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
    final color = selected ? AppColors.accent : AppColors.neutral400;
    final labelColor = selected ? AppColors.neutral100 : AppColors.neutral400;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Material(
        color: selected
            ? Colors.white.withValues(alpha: 0.08)
            : AppColors.ink,
        borderRadius: BorderRadius.circular(AppRadii.field),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.field),
          hoverColor: Colors.white.withValues(alpha: 0.06),
          splashColor: AppColors.accent.withValues(alpha: 0.12),
          highlightColor: Colors.white.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 10,
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
    );
  }
}