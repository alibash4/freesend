import 'package:material_ui/material_ui.dart';

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
    final items = [
      AppNavItem(
        label: 'Home',
        icon: AppIcons.home,
        activeIcon: AppIcons.homeActive,
      ),
      AppNavItem(
        label: 'Transfers',
        icon: AppIcons.zap,
        activeIcon: AppIcons.transfersActive,
      ),
      AppNavItem(
        label: 'History',
        icon: AppIcons.history,
        activeIcon: AppIcons.historyActive,
      ),
      AppNavItem(
        label: 'Settings',
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
