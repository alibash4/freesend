import 'package:material_ui/material_ui.dart';

import 'package:free_send/l10n/app_localizations.dart';
import 'package:free_send/theme/app_icons.dart';
import 'package:free_send/ui/kit/app_bottom_nav.dart';
import 'package:free_send/ui/kit/app_page_container.dart';
import 'package:free_send/ui/kit/app_sidebar.dart';
import 'package:free_send/ui/screens/history_screen.dart';
import 'package:free_send/ui/screens/home_screen.dart';
import 'package:free_send/ui/screens/transfers_screen.dart';
import 'package:free_send/ui/screens/settings_screen.dart';
import 'package:free_send/theme/app_theme.dart';

/// Three-tab shell: the transfer entry points live on Home, detail screens are
/// pushed on top so a session keeps running while the user navigates.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = [
      AppNavItem(
        label: l10n.navHome,
        icon: AppIcons.home,
        activeIcon: AppIcons.homeActive,
      ),
      AppNavItem(
        label: l10n.navTransfers,
        icon: AppIcons.zap,
        activeIcon: AppIcons.transfersActive,
      ),
      AppNavItem(
        label: l10n.navHistory,
        icon: AppIcons.history,
        activeIcon: AppIcons.historyActive,
      ),
      AppNavItem(
        label: l10n.navSettings,
        icon: AppIcons.settings,
        activeIcon: AppIcons.settingsActive,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 840;
        final content = AppPageContainer(
          child: IndexedStack(
            index: _index,
            children: const [
              HomeScreen(),
              TransfersScreen(),
              HistoryScreen(),
              SettingsScreen(),
            ],
          ),
        );

        return Scaffold(
          extendBody: false,
          body: SafeArea(
            bottom: false,
            child: wide
                ? Row(
                    children: [
                      AppSidebar(
                        items: items,
                        selectedIndex: _index,
                        onSelected: (value) =>
                            setState(() => _index = value),
                      ),
                      Expanded(child: content),
                    ],
                  )
                : content,
          ),
          bottomNavigationBar: wide
              ? null
              : AppBottomNav(
                  selectedIndex: _index,
                  onSelected: (value) => setState(() => _index = value),
                  items: items,
                ),
        );
      },
    );
  }
}

/// Shared horizontal page padding.
const kPagePadding = EdgeInsets.symmetric(horizontal: AppSpacing.md);
