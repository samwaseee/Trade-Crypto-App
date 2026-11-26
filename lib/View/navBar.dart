import 'package:material_ui/material_ui.dart';
import 'package:my_crypto/View/assistant_screen.dart';
import 'package:my_crypto/View/home.dart';
import 'package:my_crypto/View/news_screen.dart';
import 'package:my_crypto/View/notification_screen.dart';
import 'package:my_crypto/View/profile_screen.dart';

class NavBar extends StatefulWidget {
  const NavBar({super.key});

  @override
  State<NavBar> createState() => _NavBarState();
}

class _NavBarState extends State<NavBar> {
  int _currentIndex = 0;
  final List<bool> _visited = [true, false, false, false, false];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _visited[0] ? const Home() : const SizedBox.shrink(),
          _visited[1] ? const NewsScreen() : const SizedBox.shrink(),
          _visited[2] ? const NotificationScreen() : const SizedBox.shrink(),
          _visited[3]
              ? AssistantScreen(isActive: _currentIndex == 3)
              : const SizedBox.shrink(),
          _visited[4] ? const ProfileScreen() : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _DemoStrip(),
          NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (value) {
              setState(() {
                _currentIndex = value;
                _visited[value] = true;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.newspaper_outlined),
                selectedIcon: Icon(Icons.newspaper),
                label: 'News',
              ),
              NavigationDestination(
                icon: Icon(Icons.notifications_outlined),
                selectedIcon: Icon(Icons.notifications),
                label: 'Notifications',
              ),
              NavigationDestination(
                icon: Icon(Icons.auto_awesome_outlined),
                selectedIcon: Icon(Icons.auto_awesome),
                label: 'Assistant',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DemoStrip extends StatelessWidget {
  const _DemoStrip();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      color: colorScheme.tertiaryContainer,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: Semantics(
          label: 'DEMO MODE · Virtual money only, no real trades',
          child: Text(
            'DEMO MODE · Virtual money only, no real trades',
            style: textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onTertiaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}
