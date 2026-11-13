import 'package:material_ui/material_ui.dart';

import 'package:free_send/theme/app_icons.dart';

/// The app mark: a solid accent square holding a hotspot glyph.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(
        AppIcons.hotspot,
        color: scheme.onPrimary,
        size: size * 0.52,
      ),
    );
  }
}

class BrandTitle extends StatelessWidget {
  const BrandTitle({super.key, this.subtitle = false});

  final bool subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'FreeSend',
          style: theme.textTheme.titleLarge?.copyWith(
            letterSpacing: -0.3,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle)
          Text(
            'Hotspot-speed transfer',
            style: theme.textTheme.bodySmall,
          ),
      ],
    );
  }
}
