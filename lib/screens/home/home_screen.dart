import 'package:flutter/material.dart';
import '../attendance/attendance_screen.dart';
import '../activity/activity_screen.dart';
import '../requests/requests_screen.dart';
import '../patroli/patroli_screen.dart';
import '../../widgets/offline_indicator.dart';
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
      body: Column(
        children: [
          const OfflineIndicator(),
          Expanded(
            child: PageView.builder(
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
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  context,
                  index: 0,
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home,
                  label: 'Home',
                ),
                _buildNavItem(
                  context,
                  index: 1,
                  icon: Icons.calendar_today_outlined,
                  selectedIcon: Icons.calendar_today,
                  label: 'Absensi',
                ),
                _buildNavItem(
                  context,
                  index: 2,
                  icon: Icons.assignment_outlined,
                  selectedIcon: Icons.assignment,
                  label: 'Aktivitas',
                ),
                _buildNavItem(
                  context,
                  index: 3,
                  icon: Icons.request_quote_outlined,
                  selectedIcon: Icons.request_quote,
                  label: 'Request',
                ),
                _buildNavItem(
                  context,
                  index: 4,
                  icon: Icons.security_outlined,
                  selectedIcon: Icons.security,
                  label: 'Patroli',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;
    final primaryColor = Theme.of(context).primaryColor;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => _onDestinationSelected(index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.grey[200] : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isSelected ? selectedIcon : icon,
                  color: isSelected ? primaryColor : Colors.grey[600],
                  size: 22,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? primaryColor : Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

