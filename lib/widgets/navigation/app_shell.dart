import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

const List<NavigationDestination> destinations = [
  NavigationDestination(
    icon: Icon(Icons.home_outlined),
    selectedIcon: Icon(Icons.home),
    label: 'Home',
  ),
  NavigationDestination(
    icon: Icon(Icons.hub_outlined),
    selectedIcon: Icon(Icons.hub),
    label: 'Networks',
  ),
  NavigationDestination(
    icon: Icon(Icons.bookmark_outline),
    selectedIcon: Icon(Icons.bookmark),
    label: 'Bookmarks',
  ),
  NavigationDestination(
    icon: Icon(Icons.settings_outlined),
    selectedIcon: Icon(Icons.settings),
    label: 'Settings',
  ),
];

const List<NavigationRailDestination> railDestinations = [
  NavigationRailDestination(
    icon: Icon(Icons.home_outlined),
    selectedIcon: Icon(Icons.home),
    label: Text('Home'),
  ),
  NavigationRailDestination(
    icon: Icon(Icons.hub_outlined),
    selectedIcon: Icon(Icons.hub),
    label: Text('Networks'),
  ),
  NavigationRailDestination(
    icon: Icon(Icons.bookmark_outline),
    selectedIcon: Icon(Icons.bookmark),
    label: Text('Bookmarks'),
  ),
  NavigationRailDestination(
    icon: Icon(Icons.settings_outlined),
    selectedIcon: Icon(Icons.settings),
    label: Text('Settings'),
  ),
];

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
