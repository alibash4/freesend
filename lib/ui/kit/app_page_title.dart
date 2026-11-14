import 'package:material_ui/material_ui.dart';

import 'package:free_send/ui/kit/tokens.dart';

/// The one page title style for every screen.
class AppPageTitle extends StatelessWidget {
  const AppPageTitle(this.text, {super.key, this.textAlign});

  final String text;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      textAlign: textAlign,
      style: AppTypography.pageTitle.copyWith(
        color: dark ? AppColors.neutral200 : AppColors.neutral800,
      ),
    );
  }
}