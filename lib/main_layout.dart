import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'projects_page.dart';
import 'all_issues_page.dart';
import 'user_management_page.dart';
import 'config.dart';
import 'timer_widget.dart';
import 'http_service.dart';

class MainLayout extends StatefulWidget {
  final int initialIndex;

  const MainLayout({super.key, this.initialIndex = 0});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  late int _selectedIndex;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int? _selectedProjectId;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _validateSelectedIndex();
  }

  void _validateSelectedIndex() {
    final pagesLength = _pages.length;
    if (_selectedIndex >= pagesLength) {
      setState(() {
        _selectedIndex = 0;
      });
    }
  }

  List<NavigationItem> get _navigationItems {
    final items = [
      NavigationItem(icon: Icons.folder, label: 'Projects', index: 0),
      NavigationItem(icon: Icons.bug_report, label: 'All Issues', index: 1),
    ];

    // Only show "My Issues" if user is logged in
    if (UserSession.instance.isLoggedIn) {
      items.add(
          NavigationItem(icon: Icons.person, label: 'My Issues', index: 2));
    }

    // Only show "User Management" if user is admin
    if (UserSession.instance.isLoggedIn &&
        UserSession.instance.userRole == 'admin') {
      items.add(NavigationItem(
          icon: Icons.people, label: 'User Management', index: 3));
    }

    return items;
  }

  List<Widget> get _pages {
    final pages = [
      ProjectsPage(
        key: const ValueKey('projects'),
        onProjectTap: _navigateToProjectIssues,
      ),
      AllIssuesPage(
        key: const ValueKey('all-issues'),
        initialProjectId: _selectedProjectId,
      ),
    ];

    // Add My Issues page if user is logged in
    if (UserSession.instance.isLoggedIn) {
      pages.add(AllIssuesPage(
        key: const ValueKey('my-issues'),
        initialProjectId: _selectedProjectId,
        initialAssigneeId: UserSession.instance.userId,
      ));
    }

    // Add User Management page if user is admin
    if (UserSession.instance.isLoggedIn &&
        UserSession.instance.userRole == 'admin') {
      pages.add(const UserManagementPage(
        key: ValueKey('user-management'),
      ));
    }

    return pages;
  }

  void _navigateToProjectIssues(int projectId) {
    setState(() {
      _selectedProjectId = projectId;
      _selectedIndex = 1; // Switch to All Issues page
    });
    // Update URL when navigating to issues with project filter
    final uri = Uri(
        path: '/issues', queryParameters: {'projects': projectId.toString()});
    context.go(uri.toString());
  }

  void _navigateToPage(int index) {
    setState(() {
      _selectedIndex = index;
      // Clear project filter when navigating to All Issues from sidebar
      if (index == 1) {
        _selectedProjectId = null;
      }
      // Clear project filter when navigating to My Issues from sidebar
      if (index == 2) {
        _selectedProjectId = null;
      }
    });

    // Update URL based on navigation
    if (index == 0) {
      context.go('/projects');
    } else if (index == 1) {
      context.go('/issues');
    } else if (index == 2) {
      // Navigate to My Issues with assignee filter
      final currentUserId = UserSession.instance.userId;
      if (currentUserId != null) {
        final uri = Uri(
            path: '/issues',
            queryParameters: {'assignees': currentUserId.toString()});
        context.go(uri.toString());
      } else {
        context.go('/issues');
      }
    } else if (index == 3) {
      // Navigate to User Management
      context.go('/user-management');
    }
  }

  @override
  Widget build(BuildContext context) {
    _validateSelectedIndex();
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      body: Row(
        children: [
          // Sidebar for desktop
          if (MediaQuery.of(context).size.width >= 768) _buildSidebar(),
          // Main content
          Expanded(
            child: Column(
              children: [
                // Timer widget in header (static, outside of AnimatedSwitcher)
                if (UserSession.instance.isLoggedIn)
                  Container(
                    key: const ValueKey('timer_header'),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFAFAFA),
                      border:
                          Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
                    ),
                    child: const Row(
                      children: [
                        TimerWidget(),
                        Spacer(),
                      ],
                    ),
                  ),
                // Main content with instant transitions (no animation)
                Expanded(
                  child: _pages[_selectedIndex],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 250,
      color: const Color(0xFF2d3748),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: Color(0xFF008080)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Project Manager',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Manage your projects and issues',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                if (UserSession.instance.isLoggedIn) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          UserSession.instance.username ?? 'User',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Navigation items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _navigationItems.length,
              itemBuilder: (context, index) {
                final item = _navigationItems[index];
                final isSelected = _selectedIndex == item.index;

                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF008080)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    leading: Icon(
                      item.icon,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    onTap: () {
                      _navigateToPage(item.index);
                    },
                  ),
                );
              },
            ),
          ),
          // Logout button (only show if user is logged in)
          if (UserSession.instance.isLoggedIn)
            Container(
              margin: const EdgeInsets.all(8),
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.white70),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.white70),
                ),
                onTap: _logout,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          // Header
          const DrawerHeader(
            decoration: BoxDecoration(color: Color(0xFF008080)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Project Manager',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Manage your projects and issues',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          // Navigation items
          Expanded(
            child: ListView.builder(
              itemCount: _navigationItems.length,
              itemBuilder: (context, index) {
                final item = _navigationItems[index];
                final isSelected = _selectedIndex == item.index;

                return ListTile(
                  leading: Icon(
                    item.icon,
                    color:
                        isSelected ? const Color(0xFF008080) : Colors.grey[600],
                  ),
                  title: Text(
                    item.label,
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFF008080)
                          : Colors.grey[800],
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  onTap: () {
                    _navigateToPage(item.index);
                    Navigator.of(context).pop(); // Close drawer
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    try {
      await HttpService().post(
        Config.instance.buildApiUrl('logout.php'),
      );

      // Clear user session regardless of response
      UserSession.instance.clearUser();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logged out successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate to login page
        context.go('/login');
      }
    } catch (e) {
      // Clear user session even if logout request fails
      UserSession.instance.clearUser();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logged out (error: $e)'),
            backgroundColor: Colors.orange,
          ),
        );
        // Navigate to login page
        context.go('/login');
      }
    }
  }
}

class NavigationItem {
  final IconData icon;
  final String label;
  final int index;

  NavigationItem({
    required this.icon,
    required this.label,
    required this.index,
  });
}
