import 'package:material_ui/material_ui.dart';

import 'package:free_send/l10n/app_localizations.dart';
import 'package:free_send/theme/app_icons.dart';
import 'package:free_send/ui/kit/app_bottom_nav.dart';
import 'package:free_send/ui/kit/app_page_container.dart';
import 'package:free_send/ui/kit/app_sidebar.dart';
import 'package:free_send/ui/kit/fade_on_change.dart';
import 'package:free_send/ui/screens/history_screen.dart';
import 'package:free_send/ui/screens/home_screen.dart';
import 'package:free_send/ui/screens/receive_screen.dart';
import 'package:free_send/ui/screens/send_screen.dart';
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
  late final PageController _pageController = PageController();

  void _setIndex(int index, {bool animate = false}) {
    if (index < 0 || index > 5) return;
    if (index < 4) {
      if (animate && _index < 4) {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 420),
          curve: const Cubic(0.22, 1, 0.36, 1),
        );
      } else {
        _pageController.jumpToPage(index);
        setState(() => _index = index);
      }
      return;
    }
    setState(() => _index = index);
  }

  void _selectAnimated(int index) => _setIndex(index, animate: true);
  void _selectImmediate(int index) => _setIndex(index);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

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
          child: Stack(
            children: [
              Offstage(
                offstage: _index >= 4,
                child: FadeOnChange(
                  index: _index,
                  animate: wide,
                  child: PageView(
                    controller: _pageController,
                    physics: MediaQuery.sizeOf(context).width >= 840
                        ? const NeverScrollableScrollPhysics()
                        : const _HeavyPageScrollPhysics(),
                    onPageChanged: (value) {
                      if (_index < 4 && value != _index) {
                        setState(() => _index = value);
                      }
                    },
                    children: [
                      HomeScreen(
                        onOpenSend: () => _setIndex(4),
                        onOpenReceive: () => _setIndex(5),
                      ),
                      const TransfersScreen(),
                      const HistoryScreen(),
                      const SettingsScreen(),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: FadeOnChange(
                  index: _index,
                  child: _index == 4
                      ? SendScreen(onBack: () => _setIndex(0))
                      : _index == 5
                          ? ReceiveScreen(onBack: () => _setIndex(0))
                          : const SizedBox.shrink(),
                ),
              ),
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
                        selectedIndex: _index < 4 ? _index : -1,
                        onSelected: _selectImmediate,
                      ),
                      Expanded(child: content),
                    ],
                  )
                : content,
          ),
          bottomNavigationBar: wide
              ? null
              : AppBottomNav(
                  selectedIndex: _index < 4 ? _index : -1,
                  onSelected: _selectAnimated,
                  items: items,
                ),
        );
      },
    );
  }
}

/// Shared horizontal page padding.
const kPagePadding = EdgeInsets.symmetric(horizontal: AppSpacing.md);

/// A heavier, slower spring for tab swipes: more mass and damping than the
/// default bounce, so the page settles with weight instead of snapping.
class _HeavyPageScrollPhysics extends PageScrollPhysics {
  const _HeavyPageScrollPhysics();

  @override
  SpringDescription get spring => const SpringDescription(
        mass: 1.4,
        stiffness: 90,
        damping: 18,
      );
}
