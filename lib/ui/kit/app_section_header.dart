import 'package:material_ui/material_ui.dart';

import 'package:free_send/theme/app_theme.dart';

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.sectionTitle.copyWith(
                color: scheme.accentText,
              ),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}