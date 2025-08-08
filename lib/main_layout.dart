import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'projects_page.dart';
import 'all_issues_page.dart';
import 'config.dart';
import 'timer_widget.dart';

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
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      border:
                          Border(bottom: BorderSide(color: Colors.grey[300]!)),
                    ),
                    child: Row(
                      children: [
                        const TimerWidget(),
                        const Spacer(),
                      ],
                    ),
                  ),
                // Main content with smooth transitions (only the page content animates)
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.1, 0),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeInOut,
                          )),
                          child: child,
                        ),
                      );
                    },
                    child: _pages[_selectedIndex],
                  ),
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
            decoration: const BoxDecoration(color: Color(0xFF667eea)),
            child: const Column(
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
                        ? const Color(0xFF667eea)
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
            decoration: BoxDecoration(color: Color(0xFF667eea)),
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
                        isSelected ? const Color(0xFF667eea) : Colors.grey[600],
                  ),
                  title: Text(
                    item.label,
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFF667eea)
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
