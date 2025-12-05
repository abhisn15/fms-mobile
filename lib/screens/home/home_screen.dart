import 'package:flutter/material.dart';
import '../attendance/attendance_screen.dart';
import '../activity/activity_screen.dart';
import '../requests/requests_screen.dart';
import '../patroli/patroli_screen.dart';
import 'home_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  PageController? _pageController;
  List<AnimationController>? _animationControllers;

  final List<Widget> _screens = [
    const HomeTab(),
    const AttendanceScreen(),
    const ActivityScreen(),
    const RequestsScreen(),
    const PatroliScreen(),
  ];

  void _initializeControllers() {
    if (_pageController == null) {
      _pageController = PageController(initialPage: 0);
    }
    if (_animationControllers == null) {
      _animationControllers = List.generate(
        _screens.length,
        (index) => AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 300),
        ),
      );
      // Start animation for initial screen
      _animationControllers![0].forward();
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  @override
  void dispose() {
    _pageController?.dispose();
    if (_animationControllers != null) {
      for (var controller in _animationControllers!) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    // Animate the new screen
    _animationControllers?[index].forward(from: 0.0);
  }

  void _onDestinationSelected(int index) {
    _pageController?.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Ensure controllers are initialized (for hot reload)
    _initializeControllers();
    
    if (_pageController == null || _animationControllers == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      body: PageView.builder(
        controller: _pageController!,
        onPageChanged: _onPageChanged,
        itemCount: _screens.length,
        itemBuilder: (context, index) {
          return FadeTransition(
            opacity: _animationControllers![index],
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.1, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: _animationControllers![index],
                curve: Curves.easeOut,
              )),
              child: _screens[index],
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        height: 70, // Make bottom bar taller
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onDestinationSelected,
          height: 56,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_today),
              label: 'Absensi',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment),
              label: 'Aktivitas',
            ),
            NavigationDestination(
              icon: Icon(Icons.request_quote_outlined),
              selectedIcon: Icon(Icons.request_quote),
              label: 'Request',
            ),
            NavigationDestination(
              icon: Icon(Icons.security_outlined),
              selectedIcon: Icon(Icons.security),
              label: 'Patroli',
            ),
          ],
        ),
      ),
    );
  }
}

