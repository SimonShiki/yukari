import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  final int currentIndex;

  const AppShell({super.key, required this.child, required this.currentIndex});

  void _onDestinationSelected(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/networks');
        break;
      case 2:
        context.go('/bookmarks');
        break;
      case 3:
        context.go('/settings');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final destinations = [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: context.l10n.navHome,
      ),
      NavigationDestination(
        icon: Icon(Icons.hub_outlined),
        selectedIcon: Icon(Icons.hub),
        label: context.l10n.navNetworks,
      ),
      NavigationDestination(
        icon: Icon(Icons.bookmark_outline),
        selectedIcon: Icon(Icons.bookmark),
        label: context.l10n.navBookmarks,
      ),
      NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: context.l10n.navSettings,
      ),
    ];

    final railDestinations = [
      NavigationRailDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: Text(context.l10n.navHome),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.hub_outlined),
        selectedIcon: Icon(Icons.hub),
        label: Text(context.l10n.navNetworks),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.bookmark_outline),
        selectedIcon: Icon(Icons.bookmark),
        label: Text(context.l10n.navBookmarks),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: Text(context.l10n.navSettings),
      ),
    ];

    final bool useRail = MediaQuery.of(context).size.width >= 600;

    if (useRail) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
              selectedIndex: currentIndex,
              onDestinationSelected: (index) =>
                  _onDestinationSelected(context, index),
              labelType: NavigationRailLabelType.all,
              destinations: railDestinations,
            ),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) =>
            _onDestinationSelected(context, index),
        destinations: destinations,
      ),
    );
  }
}
