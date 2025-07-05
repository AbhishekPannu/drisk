import 'package:drisk/screens/analytics_page.dart';
import 'package:drisk/screens/dream_list_page.dart';
import 'package:drisk/screens/log_dream_page.dart';
import 'package:drisk/widgets/animated_background.dart';
import 'package:flutter/material.dart';

class MainScreen extends StatefulWidget {
  final int initialPageIndex;

  const MainScreen({super.key, this.initialPageIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  late int _currentIndex;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialPageIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onNavItemTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void changePage(int index) {
    _onNavItemTapped(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DreamyBackground(
        vsync: this,
        child: PageView(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          children: [
            LogDreamPage(onDreamSaved: () => changePage(1)),
            const DreamListPage(),
            const AnalyticsPage(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onNavItemTapped,
        backgroundColor: Colors.black.withOpacity(0.8),
        selectedItemColor: Theme.of(context).colorScheme.secondary,
        unselectedItemColor: Colors.grey[400],
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            activeIcon: Icon(Icons.add_circle),
            label: 'Log Dream',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book_outlined),
            activeIcon: Icon(Icons.book),
            label: 'Journal',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            activeIcon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
        ],
      ),
    );
  }
}
