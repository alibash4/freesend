import 'package:material_ui/material_ui.dart';

import 'package:free_send/core/platform_env.dart';
import 'package:free_send/theme/app_icons.dart';
import 'package:free_send/theme/app_theme.dart';
import 'package:free_send/ui/screens/receive_screen.dart';
import 'package:free_send/ui/screens/send_screen.dart';
import 'package:free_send/ui/shell.dart';
import 'package:free_send/ui/widgets/common.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: kPagePadding,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cards = [
                  ActionCard(
                    title: 'Send',
                    description: PlatformEnv.canCreateHotspot
                        ? 'Create a hotspot and share the files you pick.'
                        : 'Share over your current network from this device.',
                    icon: AppIcons.send,
                    highlighted: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SendScreen(),
                      ),
                    ),
                    trailing: Icon(
                      AppIcons.forward,
                      size: 16,
                      color: theme.colorScheme.onPrimaryContainer.withValues(
                        alpha: 0.55,
                      ),
                    ),
                  ),
                  ActionCard(
                    title: 'Receive',
                    description:
                        'Find a nearby session and pull files to disk.',
                    icon: AppIcons.receive,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ReceiveScreen(),
                      ),
                    ),
                  ),
                ];
                if (constraints.maxWidth > 520) {
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: cards[0]),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: cards[1]),
                      ],
                    ),
                  );
                }
                return Column(
                  children: [
                    cards[0],
                    const SizedBox(height: AppSpacing.md),
                    cards[1],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
