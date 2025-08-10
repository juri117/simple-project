import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:convert';
import 'config.dart';
import 'time_tracking_service.dart';
import 'http_service.dart';

class FilterOption<T> {
  final T value;
  final String label;

  FilterOption(this.value, this.label);
}

class Project {
  final int id;
  final String name;
  final String description;
  final String status;
  final String createdAt;
  final String updatedAt;

  Project({
    required this.id,
    required this.name,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      status: json['status'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }
}

class Issue {
  final int id;
  final int projectId;
  final String title;
  final String description;
  final String status;
  final String priority;
  final String tags;
  final String createdAt;
  final String updatedAt;
  final String creatorName;
  final String? assigneeName;
  final String projectName; // Added project name for all issues view
  final int totalTimeSeconds; // Total time spent on this issue

  Issue({
    required this.id,
    required this.projectId,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    required this.creatorName,
    this.assigneeName,
    required this.projectName,
    this.totalTimeSeconds = 0,
  });

  factory Issue.fromJson(Map<String, dynamic> json) {
    return Issue(
      id: json['id'],
      projectId: json['project_id'],
      title: json['title'],
      description: json['description'] ?? '',
      status: json['status'],
      priority: json['priority'],
      tags: json['tags'] ?? '',
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      creatorName: json['creator_name'],
      assigneeName: json['assignee_name'],
      projectName: json['project_name'] ?? 'Unknown Project',
      totalTimeSeconds: json['total_time_seconds'] ?? 0,
    );
  }
}

class User {
  final int id;
  final String username;
  final String role;

  User({
    required this.id,
    required this.username,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      role: json['role'] ?? 'normal',
    );
  }
}

class IssueDescriptionWidget extends StatelessWidget {
  final String description;
  final int maxLines;

  const IssueDescriptionWidget({
    super.key,
    required this.description,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    if (description.isEmpty) {
      return const SizedBox.shrink();
    }

    // Check if the description contains markdown syntax
    final hasMarkdown = description.contains('**') ||
        description.contains('*') ||
        description.contains('#') ||
        description.contains('`') ||
        description.contains('[') ||
        description.contains('![') ||
        description.contains('- ') ||
        description.contains('1. ');

    if (hasMarkdown) {
      return MarkdownBody(
        data: description,
        shrinkWrap: true,
        fitContent: true,
        styleSheet: MarkdownStyleSheet(
          p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                height: 1.4,
              ),
          h1: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
          h2: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
          h3: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
          code: TextStyle(
            backgroundColor: Colors.grey[200],
            fontFamily: 'monospace',
            fontSize: 12,
          ),
          codeblockDecoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(4),
          ),
          blockquote: TextStyle(
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
          blockquoteDecoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: Colors.grey[400]!, width: 4),
            ),
            color: Colors.grey[50],
          ),
        ),
        selectable: false,
        onTapLink: (text, url, title) {
          // Handle link taps if needed
          if (url != null) {
            // You could add URL launcher here if needed
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Link: $url')),
            );
          }
        },
      );
    } else {
      // For plain text, use regular Text widget
      return Text(
        description,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }
  }
}

class AllIssuesPage extends StatefulWidget {
  final int? initialProjectId;
  final int? initialAssigneeId;
  final bool? initialKanbanView;

  const AllIssuesPage({
    super.key,
    this.initialProjectId,
    this.initialAssigneeId,
    this.initialKanbanView,
  });

  @override
  State<AllIssuesPage> createState() => _AllIssuesPageState();
}

class _AllIssuesPageState extends State<AllIssuesPage> {
  List<Issue> _issues = [];
  List<User> _users = [];
  List<Project> _projects = [];
  bool _isLoading = true;
  bool _isError = false;
  String _errorMessage = '';

  // View state
  bool _isKanbanView = false;

  // Filter state
  Set<int> _selectedProjects = {};
  Set<int> _selectedAssignees = {};
  Set<int> _selectedCreators = {};
  Set<String> _selectedStatuses = {};
  Set<String> _selectedTags = {};
  Set<String> _selectedPriorities = {};
  bool _urlFiltersParsed = false;

  @override
  void initState() {
    super.initState();
    // Set initial project filter if provided
    if (widget.initialProjectId != null) {
      _selectedProjects.add(widget.initialProjectId!);
    }
    // Set initial assignee filter if provided
    if (widget.initialAssigneeId != null) {
      _selectedAssignees.add(widget.initialAssigneeId!);
    }
    // Set initial view mode if provided
    if (widget.initialKanbanView != null) {
      _isKanbanView = widget.initialKanbanView!;
    }
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Parse URL parameters for filters after context is available
    if (!_urlFiltersParsed) {
      _parseUrlFilters();
      _urlFiltersParsed = true;
    }
  }

  @override
  void didUpdateWidget(AllIssuesPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if initial filters have changed
    bool filtersChanged = false;

    // Check project filter changes
    if (widget.initialProjectId != oldWidget.initialProjectId) {
      _selectedProjects.clear();
      if (widget.initialProjectId != null) {
        _selectedProjects.add(widget.initialProjectId!);
      }
      filtersChanged = true;
    }

    // Check assignee filter changes
    if (widget.initialAssigneeId != oldWidget.initialAssigneeId) {
      _selectedAssignees.clear();
      if (widget.initialAssigneeId != null) {
        _selectedAssignees.add(widget.initialAssigneeId!);
      }
      filtersChanged = true;
    }

    // Reload data if filters changed
    if (filtersChanged) {
      _loadData();
    } else {
      // Set default status filter if no status filters are selected
      if (_selectedStatuses.isEmpty) {
        // Use all possible statuses except 'closed' for default filter
        final allPossibleStatuses = [
          'new',
          'in_progress',
          'verification',
          'completed',
          'closed'
        ];
        _selectedStatuses =
            allPossibleStatuses.where((status) => status != 'closed').toSet();
        setState(() {}); // Trigger rebuild to show the default filter
      }
    }
  }

  void _parseUrlFilters() {
    try {
      final uri = GoRouterState.of(context).uri;
      if (uri.queryParameters['projects'] != null) {
        _selectedProjects = uri.queryParameters['projects']!
            .split(',')
            .where((id) => id.isNotEmpty)
            .map((id) => int.tryParse(id))
            .where((id) => id != null)
            .map((id) => id!)
            .toSet();
      }
      if (uri.queryParameters['assignees'] != null) {
        _selectedAssignees = uri.queryParameters['assignees']!
            .split(',')
            .where((id) => id.isNotEmpty)
            .map((id) => int.tryParse(id))
            .where((id) => id != null)
            .map((id) => id!)
            .toSet();
      }
      if (uri.queryParameters['creators'] != null) {
        _selectedCreators = uri.queryParameters['creators']!
            .split(',')
            .where((id) => id.isNotEmpty)
            .map((id) => int.tryParse(id))
            .where((id) => id != null)
            .map((id) => id!)
            .toSet();
      }
      if (uri.queryParameters['statuses'] != null) {
        _selectedStatuses = uri.queryParameters['statuses']!.split(',').toSet();
      }
      if (uri.queryParameters['priorities'] != null) {
        _selectedPriorities =
            uri.queryParameters['priorities']!.split(',').toSet();
      }
      if (uri.queryParameters['tags'] != null) {
        _selectedTags = uri.queryParameters['tags']!.split(',').toSet();
      }
      if (uri.queryParameters['view'] != null) {
        _isKanbanView = uri.queryParameters['view'] == 'kanban';
      }
    } catch (e) {
      // If router state is not available, skip URL parsing
      // This can happen when the widget is created as a child of another route
    }
  }

  void _updateUrlFilters() {
    try {
      final Map<String, String> queryParams = {};

      if (_selectedProjects.isNotEmpty) {
        queryParams['projects'] = _selectedProjects.join(',');
      }
      if (_selectedAssignees.isNotEmpty) {
        queryParams['assignees'] = _selectedAssignees.join(',');
      }
      if (_selectedCreators.isNotEmpty) {
        queryParams['creators'] = _selectedCreators.join(',');
      }
      if (_selectedStatuses.isNotEmpty) {
        queryParams['statuses'] = _selectedStatuses.join(',');
      }
      if (_selectedPriorities.isNotEmpty) {
        queryParams['priorities'] = _selectedPriorities.join(',');
      }
      if (_selectedTags.isNotEmpty) {
        queryParams['tags'] = _selectedTags.join(',');
      }
      if (_isKanbanView) {
        queryParams['view'] = 'kanban';
      }

      final uri = Uri(
          path: '/issues',
          queryParameters: queryParams.isEmpty ? null : queryParams);
      context.go(uri.toString());
    } catch (e) {
      // If router state is not available, skip URL update
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _isError = false;
    });

    bool hasError = false;
    String errorMsg = '';

    // Load issues from all projects
    try {
      await _loadAllIssues();
    } catch (e) {
      hasError = true;
      errorMsg = 'Failed to load issues: $e';
    }

    // Load users
    try {
      await _loadUsers();
    } catch (e) {
      hasError = true;
      errorMsg += '\nFailed to load users: $e';
    }

    // Load projects
    try {
      await _loadProjects();
    } catch (e) {
      hasError = true;
      errorMsg += '\nFailed to load projects: $e';
    }

    // Load time statistics if user is logged in
    if (UserSession.instance.isLoggedIn) {
      try {
        await _loadTimeStats();
      } catch (e) {
        // Don't fail the entire load for time stats
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (hasError) {
          _isError = true;
          _errorMessage = errorMsg;
        } else {
          // Set default status filter to exclude 'closed' status
          // Only set default if no status filters are already selected
          if (_selectedStatuses.isEmpty) {
            // Use all possible statuses except 'closed' for default filter
            final allPossibleStatuses = [
              'new',
              'in_progress',
              'verification',
              'completed',
              'closed'
            ];
            _selectedStatuses = allPossibleStatuses
                .where((status) => status != 'closed')
                .toSet();
          }
        }
      });
    }
  }

  Future<void> _loadAllIssues() async {
    final response = await HttpService().get(
      Config.instance.buildApiUrl('issues.php'),
    );

    // Handle authentication errors
    if (HttpService().handleAuthError(response)) {
      throw Exception('Authentication required. Please log in again.');
    }

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        if (mounted) {
          setState(() {
            _issues = (data['issues'] as List)
                .map((issue) => Issue.fromJson(issue))
                .toList();
          });
        }
      } else {
        throw Exception(data['error'] ?? 'Failed to load issues');
      }
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
    }
  }

  Future<void> _loadUsers() async {
    final response = await HttpService().get(
      Config.instance.buildApiUrl('users.php'),
    );

    // Handle authentication errors
    if (HttpService().handleAuthError(response)) {
      throw Exception('Authentication required. Please log in again.');
    }

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        if (mounted) {
          setState(() {
            _users = (data['users'] as List)
                .map((user) => User.fromJson(user))
                .toList();
          });
        }
      } else {
        throw Exception(data['error'] ?? 'Failed to load users');
      }
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
    }
  }

  Future<void> _loadProjects() async {
    final response = await HttpService().get(
      Config.instance.buildApiUrl('projects.php'),
    );

    // Handle authentication errors
    if (HttpService().handleAuthError(response)) {
      throw Exception('Authentication required. Please log in again.');
    }

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        if (mounted) {
          setState(() {
            _projects = (data['projects'] as List)
                .map((project) => Project.fromJson(project))
                .toList();
          });
        }
      } else {
        throw Exception(data['error'] ?? 'Failed to load projects');
      }
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
    }
  }

  Future<void> _loadTimeStats() async {
    if (!UserSession.instance.isLoggedIn) return;

    final stats = await TimeTrackingService.instance.getTimeStats(
      userId: UserSession.instance.userId,
    );

    if (stats != null && mounted) {
      // Update issues with time data
      final issueStats = Map<int, int>.fromEntries(
        (stats['issues'] as List).map((stat) => MapEntry(
              stat['issue_id'] as int,
              stat['total_seconds'] as int,
            )),
      );

      setState(() {
        _issues = _issues.map((issue) {
          final timeSpent = issueStats[issue.id] ?? 0;
          return Issue(
            id: issue.id,
            projectId: issue.projectId,
            title: issue.title,
            description: issue.description,
            status: issue.status,
            priority: issue.priority,
            tags: issue.tags,
            createdAt: issue.createdAt,
            updatedAt: issue.updatedAt,
            creatorName: issue.creatorName,
            assigneeName: issue.assigneeName,
            projectName: issue.projectName,
            totalTimeSeconds: timeSpent,
          );
        }).toList();
      });
    }
  }

  Future<void> _startTimer(Issue issue) async {
    if (!UserSession.instance.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to use time tracking'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final success = await TimeTrackingService.instance.startTimer(
      UserSession.instance.userId!,
      issue.id,
      issue.title,
      issue.projectName,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Timer started for: ${issue.title}'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to start timer'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _createIssue() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => IssueDialog(users: _users, projects: _projects),
    );

    if (result != null) {
      try {
        final response = await HttpService().post(
          Config.instance.buildApiUrl('issues.php'),
          body: result,
        );

        // Handle authentication errors
        if (HttpService().handleAuthError(response)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Authentication required. Please log in again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Issue created successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
            _loadAllIssues();
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(data['error'] ?? 'Failed to create issue'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _editIssue(Issue issue) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          IssueDialog(issue: issue, users: _users, projects: _projects),
    );

    if (result != null) {
      try {
        final response = await HttpService().put(
          Config.instance.buildApiUrl('issues.php'),
          body: result,
        );

        // Handle authentication errors
        if (HttpService().handleAuthError(response)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Authentication required. Please log in again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Issue updated successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
            _loadAllIssues();
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(data['error'] ?? 'Failed to update issue'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _updateIssueStatus(Issue issue, String newStatus) async {
    try {
      final response = await HttpService().put(
        Config.instance.buildApiUrl('issues.php'),
        body: {
          'id': issue.id.toString(),
          'project_id': issue.projectId.toString(),
          'title': issue.title,
          'description': issue.description,
          'status': newStatus,
          'priority': issue.priority,
          'tags': issue.tags,
          'assignee_id': issue.assigneeName != null
              ? _users
                  .firstWhere(
                    (user) => user.username == issue.assigneeName,
                    orElse: () => User(id: 0, username: '', role: 'normal'),
                  )
                  .id
                  .toString()
              : '',
        },
      );

      // Handle authentication errors
      if (HttpService().handleAuthError(response)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication required. Please log in again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Issue status updated to ${newStatus.replaceAll('_', ' ')}'),
                backgroundColor: Colors.green,
              ),
            );
          }
          _loadAllIssues();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(data['error'] ?? 'Failed to update issue status'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _cleanupCompletedIssues(List<Issue> completedIssues) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cleanup Completed Issues'),
        content: Text(
            'Are you sure you want to move ${completedIssues.length} completed issue${completedIssues.length == 1 ? '' : 's'} to closed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Cleanup'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Update all completed issues to closed status
        for (final issue in completedIssues) {
          await _updateIssueStatus(issue, 'closed');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Moved ${completedIssues.length} issue${completedIssues.length == 1 ? '' : 's'} to closed'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error during cleanup: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteIssue(Issue issue) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Issue'),
        content: Text('Are you sure you want to delete "${issue.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final response = await HttpService().delete(
          Config.instance.buildApiUrl('issues.php'),
          body: {'id': issue.id},
        );

        // Handle authentication errors
        if (HttpService().handleAuthError(response)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Authentication required. Please log in again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Issue deleted successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
            _loadAllIssues();
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(data['error'] ?? 'Failed to delete issue'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return Colors.blue;
      case 'in_progress':
        return Colors.orange;
      case 'verification':
        return Colors.purple;
      case 'completed':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  // Get unique values for filters
  Set<String> _getUniquePriorities() {
    return _issues.map((issue) => issue.priority).toSet();
  }

  Set<String> _getUniqueTags() {
    Set<String> allTags = {};
    for (var issue in _issues) {
      if (issue.tags.isNotEmpty) {
        allTags.addAll(
          issue.tags
              .split(',')
              .map((tag) => tag.trim())
              .where((tag) => tag.isNotEmpty),
        );
      }
    }
    return allTags;
  }

  Set<int> _getUniqueCreatorIds() {
    return _issues
        .map((issue) {
          final creator = _users.firstWhere(
            (user) => user.username == issue.creatorName,
            orElse: () => User(id: 0, username: '', role: 'normal'),
          );
          return creator.id;
        })
        .where((id) => id > 0)
        .toSet();
  }

  Set<int> _getUniqueAssigneeIds() {
    return _issues
        .map((issue) {
          if (issue.assigneeName != null) {
            final assignee = _users.firstWhere(
              (user) => user.username == issue.assigneeName,
              orElse: () => User(id: 0, username: '', role: 'normal'),
            );
            return assignee.id;
          }
          return 0;
        })
        .where((id) => id > 0)
        .toSet();
  }

  // Filter issues based on selected filters
  List<Issue> _getFilteredIssues() {
    return _issues.where((issue) {
      // Filter by project
      if (_selectedProjects.isNotEmpty &&
          !_selectedProjects.contains(issue.projectId)) {
        return false;
      }

      // Filter by status
      if (_selectedStatuses.isNotEmpty &&
          !_selectedStatuses.contains(issue.status)) {
        return false;
      }

      // Filter by priority
      if (_selectedPriorities.isNotEmpty &&
          !_selectedPriorities.contains(issue.priority)) {
        return false;
      }

      // Filter by tags
      if (_selectedTags.isNotEmpty) {
        final issueTags = issue.tags
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toSet();
        if (!_selectedTags.any(
          (selectedTag) => issueTags.contains(selectedTag),
        )) {
          return false;
        }
      }

      // Filter by creator
      if (_selectedCreators.isNotEmpty) {
        final creator = _users.firstWhere(
          (user) => user.username == issue.creatorName,
          orElse: () => User(id: 0, username: '', role: 'normal'),
        );
        if (!_selectedCreators.contains(creator.id)) {
          return false;
        }
      }

      // Filter by assignee
      if (_selectedAssignees.isNotEmpty) {
        if (issue.assigneeName == null) {
          return false;
        }
        final assignee = _users.firstWhere(
          (user) => user.username == issue.assigneeName,
          orElse: () => User(id: 0, username: '', role: 'normal'),
        );
        if (!_selectedAssignees.contains(assignee.id)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  void _clearAllFilters() {
    setState(() {
      _selectedProjects.clear();
      _selectedAssignees.clear();
      _selectedCreators.clear();
      _selectedStatuses.clear();
      _selectedTags.clear();
      _selectedPriorities.clear();
    });
    _updateUrlFilters();
  }

  void _copyFilteredUrl() {
    final Map<String, String> queryParams = {};

    if (_selectedProjects.isNotEmpty) {
      queryParams['projects'] = _selectedProjects.join(',');
    }
    if (_selectedAssignees.isNotEmpty) {
      queryParams['assignees'] = _selectedAssignees.join(',');
    }
    if (_selectedCreators.isNotEmpty) {
      queryParams['creators'] = _selectedCreators.join(',');
    }
    if (_selectedStatuses.isNotEmpty) {
      queryParams['statuses'] = _selectedStatuses.join(',');
    }
    if (_selectedPriorities.isNotEmpty) {
      queryParams['priorities'] = _selectedPriorities.join(',');
    }
    if (_selectedTags.isNotEmpty) {
      queryParams['tags'] = _selectedTags.join(',');
    }

    final uri = Uri(
        path: '/issues',
        queryParameters: queryParams.isEmpty ? null : queryParams);
    final url = uri.toString();

    // Copy to clipboard
    Clipboard.setData(ClipboardData(text: url));

    // Show snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Filtered URL copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  bool _hasActiveFilters() {
    return _selectedProjects.isNotEmpty ||
        _selectedAssignees.isNotEmpty ||
        _selectedCreators.isNotEmpty ||
        _selectedStatuses.isNotEmpty ||
        _selectedTags.isNotEmpty ||
        _selectedPriorities.isNotEmpty;
  }

  String _getProjectName(int projectId) {
    final project = _projects.firstWhere(
      (p) => p.id == projectId,
      orElse: () => Project(
        id: projectId,
        name: 'Unknown Project',
        description: '',
        status: '',
        createdAt: '',
        updatedAt: '',
      ),
    );
    return project.name;
  }

  void _showDescriptionDialog(Issue issue) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Description: ${issue.title}'),
        content: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 400),
          child: SingleChildScrollView(
            child: issue.description.isNotEmpty
                ? IssueDescriptionWidget(
                    description: issue.description,
                    maxLines: 100,
                  )
                : const Text(
                    'No description provided.',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactFilterPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        children: [
          // Filter row
          Row(
            children: [
              const Icon(Icons.filter_list, size: 16, color: Color(0xFF008080)),
              const SizedBox(width: 8),
              const Text(
                ':',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF008080),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildCompactProjectFilter(),
                      const SizedBox(width: 12),
                      _buildCompactStatusFilter(),
                      const SizedBox(width: 12),
                      _buildCompactPriorityFilter(),
                      const SizedBox(width: 12),
                      _buildCompactTagsFilter(),
                      const SizedBox(width: 12),
                      _buildCompactCreatorFilter(),
                      const SizedBox(width: 12),
                      _buildCompactAssigneeFilter(),
                    ],
                  ),
                ),
              ),
              if (_hasActiveFilters()) ...[
                IconButton(
                  onPressed: _clearAllFilters,
                  icon: const Icon(Icons.clear, size: 14),
                  //label: const Text('', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _copyFilteredUrl,
                  icon: const Icon(Icons.copy, size: 14),
                  //label: const Text('Copy URL', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                ),
              ],
            ],
          ),
          // Active filters chips
          if (_hasActiveFilters()) ...[
            const SizedBox(height: 8),
            _buildActiveFiltersIndicator(),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactProjectFilter() {
    return _buildCompactMultiSelectFilter(
      'Project',
      Icons.folder,
      _projects.map((p) => FilterOption(p.id, p.name)).toList(),
      _selectedProjects,
      (selected) {
        setState(() => _selectedProjects = selected);
        _updateUrlFilters();
      },
    );
  }

  Widget _buildCompactStatusFilter() {
    // Use all possible statuses instead of just unique ones from current data
    final allPossibleStatuses = [
      'new',
      'in_progress',
      'verification',
      'completed',
      'closed'
    ];

    return _buildCompactMultiSelectFilter(
      'Status',
      Icons.flag,
      allPossibleStatuses
          .map((s) => FilterOption(s, s.replaceAll('_', ' ').toUpperCase()))
          .toList(),
      _selectedStatuses,
      (selected) {
        setState(() => _selectedStatuses = selected);
        _updateUrlFilters();
      },
    );
  }

  Widget _buildCompactPriorityFilter() {
    return _buildCompactMultiSelectFilter(
      'Priority',
      Icons.priority_high,
      _getUniquePriorities()
          .map((p) => FilterOption(p, p.toUpperCase()))
          .toList(),
      _selectedPriorities,
      (selected) {
        setState(() => _selectedPriorities = selected);
        _updateUrlFilters();
      },
    );
  }

  Widget _buildCompactTagsFilter() {
    return _buildCompactMultiSelectFilter(
      'Tags',
      Icons.label,
      _getUniqueTags().map((t) => FilterOption(t, t)).toList(),
      _selectedTags,
      (selected) {
        setState(() => _selectedTags = selected);
        _updateUrlFilters();
      },
    );
  }

  Widget _buildCompactCreatorFilter() {
    final creators = _getUniqueCreatorIds().map((id) {
      final user = _users.firstWhere((u) => u.id == id);
      return FilterOption(id, user.username);
    }).toList();

    return _buildCompactMultiSelectFilter(
      'Created By',
      Icons.person,
      creators,
      _selectedCreators,
      (selected) {
        setState(() => _selectedCreators = selected);
        _updateUrlFilters();
      },
    );
  }

  Widget _buildCompactAssigneeFilter() {
    final assignees = _getUniqueAssigneeIds().map((id) {
      final user = _users.firstWhere((u) => u.id == id);
      return FilterOption(id, user.username);
    }).toList();

    return _buildCompactMultiSelectFilter(
      'Assignee',
      Icons.assignment_ind,
      assignees,
      _selectedAssignees,
      (selected) {
        setState(() => _selectedAssignees = selected);
        _updateUrlFilters();
      },
    );
  }

  Widget _buildCompactMultiSelectFilter<T>(
    String title,
    IconData icon,
    List<FilterOption<T>> options,
    Set<T> selectedValues,
    Function(Set<T>) onChanged,
  ) {
    final selectedCount = selectedValues.length;
    final displayText = selectedCount == 0
        ? title
        : selectedCount == 1
            ? options
                    .where((opt) => selectedValues.contains(opt.value))
                    .firstOrNull
                    ?.label ??
                title
            : '$title ($selectedCount)';

    return PopupMenuButton<T>(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selectedValues.isNotEmpty
              ? const Color(0xFF008080).withValues(alpha: 0.1)
              : Colors.white,
          border: Border.all(
            color: selectedValues.isNotEmpty
                ? const Color(0xFF008080)
                : Colors.grey[300]!,
            width: selectedValues.isNotEmpty ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selectedValues.isNotEmpty
                  ? const Color(0xFF008080)
                  : Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              displayText,
              style: TextStyle(
                fontSize: 12,
                color: selectedValues.isNotEmpty
                    ? const Color(0xFF008080)
                    : Colors.grey[700],
                fontWeight: selectedValues.isNotEmpty
                    ? FontWeight.w500
                    : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: selectedValues.isNotEmpty
                  ? const Color(0xFF008080)
                  : Colors.grey[600],
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<T>(
          enabled: false,
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        const PopupMenuDivider(),
        ...options.map((option) {
          final isSelected = selectedValues.contains(option.value);
          return PopupMenuItem<T>(
            value: option.value,
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 16,
                  color:
                      isSelected ? const Color(0xFF008080) : Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    option.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? const Color(0xFF008080)
                          : Colors.grey[700],
                      fontWeight:
                          isSelected ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
      onSelected: (value) {
        final newSelected = Set<T>.from(selectedValues);
        if (newSelected.contains(value)) {
          newSelected.remove(value);
        } else {
          newSelected.add(value);
        }
        onChanged(newSelected);
      },
    );
  }

  Widget _buildActiveFiltersIndicator() {
    final activeFilters = <Widget>[];

    if (_selectedProjects.isNotEmpty) {
      activeFilters.add(
        _buildFilterChip('Projects', _selectedProjects.length.toString()),
      );
    }
    if (_selectedStatuses.isNotEmpty) {
      activeFilters.add(
        _buildFilterChip('Status', _selectedStatuses.length.toString()),
      );
    }
    if (_selectedPriorities.isNotEmpty) {
      activeFilters.add(
        _buildFilterChip('Priority', _selectedPriorities.length.toString()),
      );
    }
    if (_selectedTags.isNotEmpty) {
      activeFilters.add(
        _buildFilterChip('Tags', _selectedTags.length.toString()),
      );
    }
    if (_selectedCreators.isNotEmpty) {
      activeFilters.add(
        _buildFilterChip('Created By', _selectedCreators.length.toString()),
      );
    }
    if (_selectedAssignees.isNotEmpty) {
      activeFilters.add(
        _buildFilterChip('Assignee', _selectedAssignees.length.toString()),
      );
    }

    if (activeFilters.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: activeFilters),
    );
  }

  Widget _buildFilterChip(String label, String count) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF008080),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label: $count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildKanbanBoard() {
    final filteredIssues = _getFilteredIssues();

    // Define all possible statuses in the desired order (excluding closed)
    final allPossibleStatuses = [
      'new',
      'in_progress',
      'verification',
      'completed'
    ];

    return RefreshIndicator(
      onRefresh: _loadAllIssues,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            height: constraints.maxHeight,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: allPossibleStatuses.map((status) {
                  final statusIssues = filteredIssues
                      .where((issue) => issue.status == status)
                      .toList();
                  return _buildKanbanColumn(
                      status, statusIssues, constraints.maxHeight);
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildKanbanColumn(
      String status, List<Issue> issues, double availableHeight) {
    return Container(
      width: 320,
      margin: const EdgeInsets.all(8),
      child: Column(
        children: [
          // Column header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getStatusColor(status),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    status.replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    issues.length.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (status == 'completed' && issues.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Move all completed issues to closed',
                    child: IconButton(
                      icon: const Icon(
                        Icons.cleaning_services,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: () => _cleanupCompletedIssues(issues),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Column content
          Expanded(
              child: Container(
            constraints: BoxConstraints(
              minHeight: 200,
              maxHeight: availableHeight - 100,
            ),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: DragTarget<Issue>(
              onWillAcceptWithDetails: (details) =>
                  details.data.status != status,
              onAcceptWithDetails: (details) {
                _updateIssueStatus(details.data, status);
              },
              builder: (context, candidateData, rejectedData) {
                return Container(
                  decoration: BoxDecoration(
                    color: candidateData.isNotEmpty
                        ? _getStatusColor(status).withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: issues.length,
                    itemBuilder: (context, index) {
                      return _buildKanbanCard(issues[index]);
                    },
                  ),
                );
              },
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildKanbanCard(Issue issue) {
    return Draggable<Issue>(
      data: issue,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _getStatusColor(issue.status)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                issue.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                issue.projectName,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              issue.title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              issue.projectName,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Priority badge
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(issue.priority),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    issue.priority.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                if (issue.totalTimeSeconds > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer,
                        size: 12,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 2),
                      Text(
                        TimeTrackingService.instance
                            .formatDurationHuman(issue.totalTimeSeconds),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Title
            Text(
              issue.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Project name
            Row(
              children: [
                Icon(
                  Icons.folder,
                  size: 12,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    issue.projectName,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF667eea),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Tags
            if (issue.tags.isNotEmpty)
              Row(
                children: [
                  const Icon(
                    Icons.label,
                    size: 12,
                    color: Color(0xFF757575),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      issue.tags,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF757575),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 4),
            // Assignee
            Row(
              children: [
                Icon(
                  Icons.person,
                  size: 12,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    issue.assigneeName ?? 'Unassigned',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  onPressed: () => _showDescriptionDialog(issue),
                  icon: const Icon(Icons.info, size: 16),
                  tooltip: 'View description',
                  style: IconButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF667eea).withValues(alpha: 0.1),
                    foregroundColor: const Color(0xFF667eea),
                    padding: const EdgeInsets.all(4),
                  ),
                ),
                if (UserSession.instance.isLoggedIn)
                  IconButton(
                    onPressed: () => _startTimer(issue),
                    icon: const Icon(Icons.play_arrow, size: 16),
                    tooltip: 'Start timer',
                    style: IconButton.styleFrom(
                      backgroundColor:
                          const Color(0xFF667eea).withValues(alpha: 0.1),
                      foregroundColor: const Color(0xFF667eea),
                      padding: const EdgeInsets.all(4),
                    ),
                  ),
                IconButton(
                  onPressed: () => _editIssue(issue),
                  icon: const Icon(Icons.edit, size: 16),
                  tooltip: 'Edit issue',
                  style: IconButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF667eea).withValues(alpha: 0.1),
                    foregroundColor: const Color(0xFF667eea),
                    padding: const EdgeInsets.all(4),
                  ),
                ),
                IconButton(
                  onPressed: () => _deleteIssue(issue),
                  icon: const Icon(Icons.delete, size: 16),
                  tooltip: 'Delete issue',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFFFEBEE),
                    foregroundColor: const Color(0xFFD32F2F),
                    padding: const EdgeInsets.all(4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedProjects.isNotEmpty && _selectedProjects.length == 1
              ? _getProjectName(_selectedProjects.first)
              : 'All Issues',
        ),
        backgroundColor: const Color(0xFF008080),
        foregroundColor: Colors.white,
        leading: MediaQuery.of(context).size.width < 768
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              )
            : null,
        actions: [
          // View toggle button
          IconButton(
            icon: Icon(_isKanbanView ? Icons.view_list : Icons.view_column),
            onPressed: () {
              setState(() {
                _isKanbanView = !_isKanbanView;
              });
              _updateUrlFilters(); // Update URL when view mode changes
            },
            tooltip:
                _isKanbanView ? 'Switch to List View' : 'Switch to Kanban View',
          ),
          if (_hasActiveFilters())
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _copyFilteredUrl,
              tooltip: 'Copy filtered URL',
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: Column(
        children: [
          // Compact filter panel (always visible)
          _buildCompactFilterPanel(),

          // Main content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _isError
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error loading issues',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _errorMessage,
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadData,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _issues.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.bug_report,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No issues found',
                                  style:
                                      Theme.of(context).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Create your first issue to get started',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          )
                        : _getFilteredIssues().isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.filter_list,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No issues match your filters',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Try adjusting your filter criteria',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: _clearAllFilters,
                                      child: const Text('Clear All Filters'),
                                    ),
                                  ],
                                ),
                              )
                            : _isKanbanView
                                ? _buildKanbanBoard()
                                : RefreshIndicator(
                                    onRefresh: _loadAllIssues,
                                    child: ListView.builder(
                                      padding: const EdgeInsets.all(16),
                                      itemCount: _getFilteredIssues().length,
                                      itemBuilder: (context, index) {
                                        final issue =
                                            _getFilteredIssues()[index];
                                        return Card(
                                            margin: const EdgeInsets.only(
                                                bottom: 16),
                                            child: Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    // Priority badge on the left
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            _getPriorityColor(
                                                                issue.priority),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                      child: Text(
                                                        issue.priority
                                                            .toUpperCase(),
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    // Main content
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            issue.title,
                                                            style:
                                                                const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 16,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 8),
                                                          // Project name
                                                          Row(
                                                            children: [
                                                              Icon(
                                                                Icons.folder,
                                                                size: 14,
                                                                color: Colors
                                                                    .grey[600],
                                                              ),
                                                              const SizedBox(
                                                                  width: 4),
                                                              Text(
                                                                issue
                                                                    .projectName,
                                                                style: Theme.of(
                                                                        context)
                                                                    .textTheme
                                                                    .bodySmall
                                                                    ?.copyWith(
                                                                      color: const Color(
                                                                          0xFF667eea),
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(
                                                              height: 8),
                                                          Row(
                                                            children: [
                                                              Container(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 4,
                                                                ),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: _getStatusColor(
                                                                      issue
                                                                          .status),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              12),
                                                                ),
                                                                child: Text(
                                                                  issue.status
                                                                      .replaceAll(
                                                                          '_',
                                                                          ' ')
                                                                      .toUpperCase(),
                                                                  style:
                                                                      const TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize:
                                                                        10,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  width: 8),
                                                              if (issue.tags
                                                                  .isNotEmpty) ...[
                                                                Icon(
                                                                  Icons.label,
                                                                  size: 14,
                                                                  color: Colors
                                                                          .grey[
                                                                      600],
                                                                ),
                                                                const SizedBox(
                                                                    width: 4),
                                                                Text(
                                                                  issue.tags,
                                                                  style: Theme.of(
                                                                          context)
                                                                      .textTheme
                                                                      .bodySmall
                                                                      ?.copyWith(
                                                                          color:
                                                                              Colors.grey[600]),
                                                                ),
                                                              ],
                                                            ],
                                                          ),
                                                          const SizedBox(
                                                              height: 8),
                                                          Row(
                                                            children: [
                                                              Icon(
                                                                Icons.person,
                                                                size: 14,
                                                                color: Colors
                                                                    .grey[600],
                                                              ),
                                                              const SizedBox(
                                                                  width: 4),
                                                              Text(
                                                                'By ${issue.creatorName}',
                                                                style: Theme.of(
                                                                        context)
                                                                    .textTheme
                                                                    .bodySmall
                                                                    ?.copyWith(
                                                                        color: Colors
                                                                            .grey[600]),
                                                              ),
                                                              if (issue
                                                                      .assigneeName !=
                                                                  null) ...[
                                                                const SizedBox(
                                                                    width: 16),
                                                                Icon(
                                                                  Icons
                                                                      .assignment_ind,
                                                                  size: 14,
                                                                  color: Colors
                                                                          .grey[
                                                                      600],
                                                                ),
                                                                const SizedBox(
                                                                    width: 4),
                                                                Text(
                                                                  'Assigned to ${issue.assigneeName}',
                                                                  style: Theme.of(
                                                                          context)
                                                                      .textTheme
                                                                      .bodySmall
                                                                      ?.copyWith(
                                                                          color:
                                                                              Colors.grey[600]),
                                                                ),
                                                              ],
                                                            ],
                                                          ),
                                                          const SizedBox(
                                                              height: 4),
                                                          Row(
                                                            children: [
                                                              Text(
                                                                'Created: ${issue.createdAt}',
                                                                style: Theme.of(
                                                                        context)
                                                                    .textTheme
                                                                    .bodySmall
                                                                    ?.copyWith(
                                                                        color: Colors
                                                                            .grey[600]),
                                                              ),
                                                              if (issue
                                                                      .totalTimeSeconds >
                                                                  0) ...[
                                                                const SizedBox(
                                                                    width: 16),
                                                                Icon(
                                                                  Icons.timer,
                                                                  size: 12,
                                                                  color: Colors
                                                                          .grey[
                                                                      600],
                                                                ),
                                                                const SizedBox(
                                                                    width: 4),
                                                                Text(
                                                                  TimeTrackingService
                                                                      .instance
                                                                      .formatDurationHuman(
                                                                          issue
                                                                              .totalTimeSeconds),
                                                                  style: Theme.of(
                                                                          context)
                                                                      .textTheme
                                                                      .bodySmall
                                                                      ?.copyWith(
                                                                        color: Colors
                                                                            .grey[600],
                                                                        fontWeight:
                                                                            FontWeight.w500,
                                                                      ),
                                                                ),
                                                              ],
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    // Right side action buttons
                                                    Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        // First row: info, start
                                                        Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            IconButton(
                                                              onPressed: () =>
                                                                  _showDescriptionDialog(
                                                                      issue),
                                                              icon: const Icon(
                                                                  Icons.info,
                                                                  size: 20),
                                                              tooltip:
                                                                  'View description',
                                                              style: IconButton
                                                                  .styleFrom(
                                                                backgroundColor: const Color(
                                                                        0xFF667eea)
                                                                    .withValues(
                                                                        alpha:
                                                                            0.1),
                                                                foregroundColor:
                                                                    const Color(
                                                                        0xFF667eea),
                                                              ),
                                                            ),
                                                            if (UserSession
                                                                .instance
                                                                .isLoggedIn) ...[
                                                              const SizedBox(
                                                                  width: 4),
                                                              IconButton(
                                                                onPressed: () =>
                                                                    _startTimer(
                                                                        issue),
                                                                icon: const Icon(
                                                                    Icons
                                                                        .play_arrow,
                                                                    size: 20),
                                                                tooltip:
                                                                    'Start timer',
                                                                style: IconButton
                                                                    .styleFrom(
                                                                  backgroundColor: const Color(
                                                                          0xFF667eea)
                                                                      .withValues(
                                                                          alpha:
                                                                              0.1),
                                                                  foregroundColor:
                                                                      const Color(
                                                                          0xFF667eea),
                                                                ),
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                            height: 4),
                                                        // Second row: edit, delete
                                                        Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            IconButton(
                                                              onPressed: () =>
                                                                  _editIssue(
                                                                      issue),
                                                              icon: const Icon(
                                                                  Icons.edit,
                                                                  size: 20),
                                                              tooltip:
                                                                  'Edit issue',
                                                              style: IconButton
                                                                  .styleFrom(
                                                                backgroundColor: const Color(
                                                                        0xFF667eea)
                                                                    .withValues(
                                                                        alpha:
                                                                            0.1),
                                                                foregroundColor:
                                                                    const Color(
                                                                        0xFF667eea),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                width: 4),
                                                            IconButton(
                                                              onPressed: () =>
                                                                  _deleteIssue(
                                                                      issue),
                                                              icon: const Icon(
                                                                  Icons.delete,
                                                                  size: 20),
                                                              tooltip:
                                                                  'Delete issue',
                                                              style: IconButton
                                                                  .styleFrom(
                                                                backgroundColor:
                                                                    Colors.red[
                                                                        50],
                                                                foregroundColor:
                                                                    Colors.red[
                                                                        700],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ]),
                                            ));
                                      },
                                    ),
                                  ),
          ),
          //),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createIssue,
        backgroundColor: const Color(0xFF008080),
        foregroundColor: Colors.white,
        heroTag: 'issues_fab',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class IssueDialog extends StatefulWidget {
  final Issue? issue;
  final List<User> users;
  final List<Project> projects;

  const IssueDialog({
    super.key,
    this.issue,
    required this.users,
    required this.projects,
  });

  @override
  State<IssueDialog> createState() => _IssueDialogState();
}

class _IssueDialogState extends State<IssueDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();
  String _status = 'new';
  String _priority = 'medium';
  int? _assigneeId;
  int? _selectedProjectId;
  bool _showDescriptionPreview = false;

  @override
  void initState() {
    super.initState();
    if (widget.issue != null) {
      _titleController.text = widget.issue!.title;
      _descriptionController.text = widget.issue!.description;
      _tagsController.text = widget.issue!.tags;
      _status = widget.issue!.status;
      _priority = widget.issue!.priority;
      // Find assignee ID by username
      final assignee = widget.users.firstWhere(
        (user) => user.username == widget.issue!.assigneeName,
        orElse: () => User(id: 0, username: '', role: 'normal'),
      );
      _assigneeId = assignee.id > 0 ? assignee.id : null;
      _selectedProjectId = widget.issue!.projectId;
    } else {
      // For new issues, select the first project by default
      if (widget.projects.isNotEmpty) {
        _selectedProjectId = widget.projects.first.id;
      }

      // Set the logged-in user as the default assignee for new issues
      if (UserSession.instance.isLoggedIn &&
          UserSession.instance.userId != null) {
        _assigneeId = UserSession.instance.userId;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.issue == null ? 'Create Issue' : 'Edit Issue'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Issue Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an issue title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _selectedProjectId,
                decoration: const InputDecoration(
                  labelText: 'Project',
                  border: OutlineInputBorder(),
                ),
                items: widget.projects.map((project) {
                  return DropdownMenuItem<int>(
                    value: project.id,
                    child: Text(project.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedProjectId = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a project';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Description (Markdown supported)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _showDescriptionPreview = !_showDescriptionPreview;
                          });
                        },
                        icon: Icon(_showDescriptionPreview
                            ? Icons.edit
                            : Icons.preview),
                        label:
                            Text(_showDescriptionPreview ? 'Edit' : 'Preview'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_showDescriptionPreview) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.grey[50],
                      ),
                      child: IssueDescriptionWidget(
                        description: _descriptionController.text.isEmpty
                            ? '*No description*'
                            : _descriptionController.text,
                        maxLines: 10,
                      ),
                    ),
                  ] else ...[
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText:
                            'Use **bold**, *italic*, `code`, # headers, - lists, etc.',
                      ),
                      maxLines: 6,
                      maxLength: 1000,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags (comma-separated)',
                  border: OutlineInputBorder(),
                  hintText: 'bug, frontend, urgent',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _status,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'new', child: Text('New')),
                        DropdownMenuItem(
                          value: 'in_progress',
                          child: Text('In Progress'),
                        ),
                        DropdownMenuItem(
                          value: 'verification',
                          child: Text('Verification'),
                        ),
                        DropdownMenuItem(
                          value: 'completed',
                          child: Text('Completed'),
                        ),
                        DropdownMenuItem(
                          value: 'closed',
                          child: Text('Closed'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _status = value!;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _priority,
                      decoration: const InputDecoration(
                        labelText: 'Priority',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('Low')),
                        DropdownMenuItem(
                          value: 'medium',
                          child: Text('Medium'),
                        ),
                        DropdownMenuItem(value: 'high', child: Text('High')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _priority = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(
                value: _assigneeId,
                decoration: const InputDecoration(
                  labelText: 'Assignee (optional)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Unassigned'),
                  ),
                  ...widget.users.map(
                    (user) => DropdownMenuItem<int?>(
                      value: user.id,
                      child: Text(user.username),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _assigneeId = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final data = {
                'project_id': _selectedProjectId.toString(),
                'title': _titleController.text.trim(),
                'description': _descriptionController.text.trim(),
                'status': _status,
                'priority': _priority,
                'tags': _tagsController.text.trim(),
                'assignee_id': _assigneeId,
              };

              if (widget.issue != null) {
                data['id'] = widget.issue!.id.toString();
              }

              Navigator.of(context).pop(data);
            }
          },
          child: Text(widget.issue == null ? 'Create' : 'Update'),
        ),
      ],
    );
  }
}
