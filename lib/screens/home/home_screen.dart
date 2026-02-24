import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../attendance/attendance_screen.dart';
import '../activity/activity_screen.dart';
import '../requests/requests_screen.dart';
import '../patroli/patroli_screen.dart';
import '../settings/settings_screen.dart';
import '../team/team_screen.dart';
import '../incident_report/incident_report_screen.dart';
import '../../widgets/offline_indicator.dart';
import '../../providers/auth_provider.dart';
import '../../providers/checkpoint_provider.dart';
import '../../models/user_model.dart';
import '../../services/global_update_checker.dart';
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
  bool _hasCheckedUpdate = false;
  bool _showMoreMenu = false;
  AnimationController? _moreMenuController;
  Animation<Offset>? _moreMenuSlide;
  Animation<double>? _moreMenuFade;
  String? _lastCheckpointUserId;

  // Helper untuk mendapatkan screens. Patroli hanya disertakan bila posisi mengandung kata kunci security.
  List<Widget> _getScreens(bool showPatroli) {
    final screens = <Widget>[
      const HomeTab(),
      const AttendanceScreen(),
      const ActivityScreen(),
      const RequestsScreen(),
      const IncidentReportScreen(),
    ];
    if (showPatroli) {
      screens.add(const PatroliScreen());
    }
    screens.add(const TeamScreen());
    screens.add(const SettingsScreen());
    return screens;
  }

  // Hanya 3 tab utama di bottom bar + Lainnya (buka sheet)
  List<_NavItemData> _getMainNavItems() {
    return [
      _NavItemData(
        index: 0,
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        label: 'Home',
      ),
      _NavItemData(
        index: 1,
        icon: Icons.calendar_today_outlined,
        selectedIcon: Icons.calendar_today,
        label: 'Absensi',
      ),
      _NavItemData(
        index: 2,
        icon: Icons.assignment_outlined,
        selectedIcon: Icons.assignment,
        label: 'Aktivitas',
      ),
      _NavItemData(
        index: -1,
        icon: Icons.apps_rounded,
        selectedIcon: Icons.apps,
        label: 'Lainnya',
      ),
    ];
  }

  // Item-item yang muncul di sheet "Lainnya". Patroli hanya muncul bila posisi mengandung kata kunci security.
  List<_NavItemData> _getMoreNavItems(bool showPatroli) {
    final items = [
      _NavItemData(
        index: 3,
        icon: Icons.request_quote_outlined,
        selectedIcon: Icons.request_quote,
        label: 'Request',
      ),
      _NavItemData(
        index: 4,
        icon: Icons.report_outlined,
        selectedIcon: Icons.report,
        label: 'Laporan Kejadian',
      ),
    ];
    if (showPatroli) {
      items.add(
        _NavItemData(
          index: 5,
          icon: Icons.security_outlined,
          selectedIcon: Icons.security,
          label: 'Patroli',
        ),
      );
    }
    items.add(
      _NavItemData(
        index: showPatroli ? 6 : 5,
        icon: Icons.groups_outlined,
        selectedIcon: Icons.groups,
        label: 'Team',
      ),
    );
    items.add(
      _NavItemData(
        index: showPatroli ? 7 : 6,
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        label: 'Pengaturan',
      ),
    );
    return items;
  }

  void _initializeControllers(int screenCount) {
    if (_pageController == null) {
      _pageController = PageController(initialPage: 0);
    }
    if (_animationControllers == null ||
        _animationControllers!.length != screenCount) {
      if (_animationControllers != null) {
        for (var controller in _animationControllers!) {
          controller.dispose();
        }
      }
      _animationControllers = List.generate(
        screenCount,
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
    _moreMenuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _moreMenuSlide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _moreMenuController!,
            curve: Curves.easeOutCubic,
          ),
        );
    _moreMenuFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _moreMenuController!, curve: Curves.easeOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Start global update checker when dashboard is ready (only once)
    if (!_hasCheckedUpdate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        GlobalUpdateChecker.startAutoCheck(context);
        _hasCheckedUpdate = true;
      });
    }
  }

  @override
  void dispose() {
    GlobalUpdateChecker.stopAutoCheck();
    _pageController?.dispose();
    _moreMenuController?.dispose();
    if (_animationControllers != null) {
      for (var controller in _animationControllers!) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  void _openMoreMenu(bool isSecurity) {
    setState(() => _showMoreMenu = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _moreMenuController?.forward();
    });
  }

  void _closeMoreMenu() {
    _moreMenuController?.reverse().then((_) {
      if (mounted) setState(() => _showMoreMenu = false);
    });
  }

  void _selectMoreItem(int index) {
    _closeMoreMenu();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onDestinationSelected(index);
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    // Animate the new screen
    _animationControllers?[index].forward(from: 0.0);
    if (index == 0) {
      GlobalUpdateChecker.checkNow(context);
    }
  }

  void _onDestinationSelected(int index) {
    _pageController?.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  static bool _showPatroliMenu(User? user) {
    if (user == null) return false;
    final positionName = user.position?.name;
    if (positionName == null || positionName.trim().isEmpty) return false;
    final lower = positionName.toLowerCase();
    // Patroli hanya untuk posisi security (bukan mengikuti flag checkpoint site).
    return lower.contains('security') ||
        lower.contains('satpam') ||
        lower.contains('guard') ||
        lower.contains('penjaga') ||
        lower.contains('patrol');
  }

  void _bootstrapCheckpointForUser(User? user) {
    final userId = user?.id;
    if (userId == null) {
      if (_lastCheckpointUserId != null) {
        _lastCheckpointUserId = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Provider.of<CheckpointProvider>(context, listen: false).clear();
        });
      }
      return;
    }

    if (_lastCheckpointUserId == userId) return;
    _lastCheckpointUserId = userId;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final checkpointProvider = Provider.of<CheckpointProvider>(
        context,
        listen: false,
      );
      checkpointProvider.clear();
      await checkpointProvider.loadCheckpoint(force: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.user;
        _bootstrapCheckpointForUser(user);
        final showPatroli = _showPatroliMenu(user);

        final screens = _getScreens(showPatroli);
        final navItems = _getMainNavItems();

        if (_currentIndex >= screens.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final safeIndex = screens.length - 1;
            setState(() => _currentIndex = safeIndex);
            _pageController?.jumpToPage(safeIndex);
          });
        }

        // Ensure controllers are initialized (for hot reload)
        _initializeControllers(screens.length);

        if (_pageController == null || _animationControllers == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Stack(
          children: [
            Scaffold(
              body: Column(
                children: [
                  const OfflineIndicator(),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController!,
                      onPageChanged: _onPageChanged,
                      itemCount: screens.length,
                      itemBuilder: (context, index) {
                        final child = KeyedSubtree(
                          key: ValueKey<int>(index),
                          child: screens[index],
                        );
                        // Only animate the current page to avoid lifecycle assertion
                        // when off-screen pages are deactivated during tab switch.
                        if (index == _currentIndex) {
                          return FadeTransition(
                            opacity: _animationControllers![index],
                            child: SlideTransition(
                              position:
                                  Tween<Offset>(
                                    begin: const Offset(0.1, 0),
                                    end: Offset.zero,
                                  ).animate(
                                    CurvedAnimation(
                                      parent: _animationControllers![index],
                                      curve: Curves.easeOut,
                                    ),
                                  ),
                              child: child,
                            ),
                          );
                        }
                        return RepaintBoundary(child: child);
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: navItems
                          .map(
                            (item) => _buildNavItem(
                              context,
                              index: item.index,
                              icon: item.icon,
                              selectedIcon: item.selectedIcon,
                              label: item.label,
                              isSecurity: showPatroli,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ),
            ),
            if (_showMoreMenu) _buildMoreMenuOverlay(context, showPatroli),
          ],
        );
      },
    );
  }

  Widget _buildMoreMenuOverlay(BuildContext context, bool isSecurity) {
    final moreItems = _getMoreNavItems(isSecurity);
    const primaryColor = Color(0xFF1E88E5);
    const double iconSize = 56.0;
    const double borderWidth = 2.5;

    return Positioned.fill(
      child: GestureDetector(
        onTap: _closeMoreMenu,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.black38,
          child: SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FadeTransition(
                opacity: _moreMenuFade!,
                child: SlideTransition(
                  position: _moreMenuSlide!,
                  child: GestureDetector(
                    onTap: () {}, // prevent tap through to close
                    child: Container(
                      margin: const EdgeInsets.only(
                        bottom: 70,
                        left: 20,
                        right: 20,
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 24,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 20,
                        runSpacing: 20,
                        children: moreItems.map((item) {
                          final isSelected = _currentIndex == item.index;
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _selectMoreItem(item.index),
                              borderRadius: BorderRadius.circular(
                                iconSize / 2 + borderWidth,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: iconSize + borderWidth * 2,
                                    height: iconSize + borderWidth * 2,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? primaryColor.withOpacity(0.12)
                                          : Colors.grey[50],
                                      border: Border.all(
                                        color: isSelected
                                            ? primaryColor
                                            : Colors.grey[300]!,
                                        width: borderWidth,
                                      ),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        isSelected
                                            ? item.selectedIcon
                                            : item.icon,
                                        size: 28,
                                        color: isSelected
                                            ? primaryColor
                                            : Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: 72,
                                    child: Text(
                                      item.label,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? primaryColor
                                            : Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
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
    bool isSecurity = false,
  }) {
    final isLainnya = index == -1;
    final isSelected = !isLainnya && _currentIndex == index;
    const primaryColor = Color(0xFF1E88E5);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (isLainnya) {
            _openMoreMenu(isSecurity);
          } else {
            _onDestinationSelected(index);
          }
        },
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
                  color: isSelected
                      ? primaryColor.withOpacity(0.15)
                      : (isLainnya ? Colors.grey[100] : Colors.transparent),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isSelected || isLainnya ? selectedIcon : icon,
                  color: isSelected
                      ? primaryColor
                      : (isLainnya ? Colors.grey[600] : Colors.grey[600]),
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

// Helper class untuk navigation item data
class _NavItemData {
  final int index;
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  _NavItemData({
    required this.index,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}
