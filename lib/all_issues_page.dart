import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'config.dart';
import 'time_tracking_service.dart';
import 'http_service.dart';
import 'file_attachment.dart';
import 'tag.dart';

// Helper function to convert hex color string to Color
Color hexToColor(String hexString) {
  final buffer = StringBuffer();
  if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
  buffer.write(hexString.replaceFirst('#', ''));
  return Color(int.parse(buffer.toString(), radix: 16));
}

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
  final List<FileAttachment> attachments; // File attachments
  final List<Tag> tagObjects; // Tag objects with colors

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
    this.attachments = const [],
    this.tagObjects = const [],
  });

  factory Issue.fromJson(Map<String, dynamic> json) {
    List<FileAttachment> attachments = [];
    if (json['attachments'] != null) {
      try {
        attachments = (json['attachments'] as List)
            .map((attachment) => FileAttachment.fromJson(attachment))
            .toList();
      } catch (e) {
        // Error parsing attachments: $e
        attachments = [];
      }
    }

    List<Tag> tagObjects = [];
    if (json['tag_objects'] != null) {
      try {
        tagObjects = (json['tag_objects'] as List)
            .map((tag) => Tag.fromJson(tag))
            .toList();
        // Issue ${json['id']}: Parsed ${tagObjects.length} tag objects
      } catch (e) {
        // Error parsing tag objects: $e
        tagObjects = [];
      }
    } else {
      // Issue ${json['id']}: No tag_objects field found, tags string: "${json['tags']}"
    }

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
      attachments: attachments,
      tagObjects: tagObjects,
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
  String _searchText = ''; // Search text for filtering issue titles
  final TextEditingController _searchController = TextEditingController();
  bool _urlFiltersParsed = false;
  int? _issueIdToOpen; // Issue ID to open in details dialog

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
      if (uri.queryParameters['search'] != null) {
        _searchText = uri.queryParameters['search']!;
        _searchController.text = _searchText;
      }
      if (uri.queryParameters['view'] != null) {
        _isKanbanView = uri.queryParameters['view'] == 'kanban';
      }
      if (uri.queryParameters['issue_id'] != null) {
        final issueId = int.tryParse(uri.queryParameters['issue_id']!);
        if (issueId != null) {
          _issueIdToOpen = issueId;
        }
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
      if (_searchText.isNotEmpty) {
        queryParams['search'] = _searchText;
      }
      if (_isKanbanView) {
        queryParams['view'] = 'kanban';
      }
      if (_issueIdToOpen != null) {
        queryParams['issue_id'] = _issueIdToOpen.toString();
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

      // Check if we need to open an issue details dialog
      if (_issueIdToOpen != null) {
        _openIssueDetailsAfterLoad();
      }
    }
  }

  void _openIssueDetailsAfterLoad() {
    try {
      final issueToOpen = _issues.firstWhere(
        (issue) => issue.id == _issueIdToOpen,
        orElse: () => throw Exception('Issue not found'),
      );

      // Clear the issue ID to prevent reopening on subsequent loads
      _issueIdToOpen = null;

      // Use a post-frame callback to ensure the widget is fully built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showDescriptionDialog(issueToOpen);
        }
      });
    } catch (e) {
      // If issue not found, show a snackbar and clear the ID
      _issueIdToOpen = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Issue not found: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadAllIssues() async {
    final response = await HttpService().get(
      Config.instance.buildApiUrl('issues.php'),
    );

    // Handle authentication errors
    if (await HttpService().handleAuthError(response)) {
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
    if (await HttpService().handleAuthError(response)) {
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
    if (await HttpService().handleAuthError(response)) {
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
            attachments: issue.attachments,
            tagObjects: issue.tagObjects,
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
        if (await HttpService().handleAuthError(response)) {
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
        if (await HttpService().handleAuthError(response)) {
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
      if (await HttpService().handleAuthError(response)) {
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
        if (await HttpService().handleAuthError(response)) {
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

  // ignore: unused_element
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

  TextStyle _getTitleStyle(String priority, {double fontSize = 16}) {
    switch (priority.toLowerCase()) {
      case 'high':
        return TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
        );
      case 'medium':
        return TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: fontSize,
        );
      case 'low':
        return TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: fontSize,
          color: Colors.grey[500],
        );
      default:
        return TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: fontSize,
        );
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

      // Filter by search text
      if (_searchText.isNotEmpty) {
        if (!issue.title.toLowerCase().contains(_searchText.toLowerCase())) {
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
      _searchText = '';
      _searchController.clear();
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
    if (_searchText.isNotEmpty) {
      queryParams['search'] = _searchText;
    }

    final baseUrl = Config.instance.baseUrl;
    final queryString = queryParams.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final url = queryParams.isEmpty
        ? '$baseUrl/#/issues'
        : '$baseUrl/#/issues?$queryString';

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
        _selectedPriorities.isNotEmpty ||
        _searchText.isNotEmpty;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      builder: (context) => IssueDetailDialog(issue: issue),
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
              // Search field
              SizedBox(
                width: 200,
                height: 32,
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchText = value;
                    });
                    _updateUrlFilters();
                  },
                  decoration: InputDecoration(
                    hintText: 'Search titles...',
                    hintStyle:
                        const TextStyle(fontSize: 12, color: Colors.grey),
                    prefixIcon:
                        const Icon(Icons.search, size: 16, color: Colors.grey),
                    suffixIcon: _searchText.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              setState(() {
                                _searchText = '';
                                _searchController.clear();
                              });
                              _updateUrlFilters();
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    enabledBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                      borderSide: BorderSide(color: Color(0xFF008080)),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 12),
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
    if (_searchText.isNotEmpty) {
      activeFilters.add(
        _buildFilterChip('Search', '"$_searchText"'),
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
          final horizontalScrollController = ScrollController();
          return SizedBox(
            height: constraints.maxHeight,
            child: RawScrollbar(
              thumbColor: Colors.grey[600],
              trackColor: Colors.grey[300],
              controller: horizontalScrollController,
              thumbVisibility: true,
              trackVisibility: true,
              thickness: 12,
              radius: const Radius.circular(6),
              child: SingleChildScrollView(
                controller: horizontalScrollController,
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
            ),
          );
        },
      ),
    );
  }

  Widget _buildKanbanColumn(
      String status, List<Issue> issues, double availableHeight) {
    final scrollController = ScrollController();

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
                  child: RawScrollbar(
                    thumbColor: _getStatusColor(status),
                    trackColor: _getStatusColor(status).withValues(alpha: 0.2),
                    controller: scrollController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    thickness: 12,
                    radius: const Radius.circular(6),
                    child: ListView.builder(
                      controller: scrollController,
                      primary: false,
                      padding: const EdgeInsets.all(8),
                      itemCount: issues.length,
                      itemBuilder: (context, index) {
                        return _buildKanbanCard(issues[index]);
                      },
                    ),
                  ),
                );
              },
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildIssuesListView() {
    final filteredIssues = _getFilteredIssues();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredIssues.length,
        itemBuilder: (context, index) {
          final issue = filteredIssues[index];
          return _buildIssueCard(issue);
        },
      ),
    );
  }

  Widget _buildIssueCard(Issue issue) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(issue.status),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                issue.status.replaceAll('_', ' ').toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                issue.title,
                style: _getTitleStyle(issue.priority, fontSize: 16),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (issue.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                issue.description,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.folder, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  issue.projectName,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.person, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  (issue.assigneeName ?? '').isNotEmpty
                      ? issue.assigneeName!
                      : 'Unassigned',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                ...issue.tagObjects
                    .map((tag) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: hexToColor(tag.color).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  hexToColor(tag.color).withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            tag.shortName,
                            style: TextStyle(
                              fontSize: 9,
                              color: hexToColor(tag.color),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )))
                    .toList(),
                const Spacer(),
                Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  issue.createdAt,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: SizedBox(
          //width: 120, // Fixed width to prevent overflow
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Start Timer button
              //if (UserSession.instance.isLoggedIn)
              IconButton(
                onPressed: () => _showDescriptionDialog(issue),
                icon: const Icon(Icons.info, size: 14),
                //label: const Text('Details', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[50],
                  foregroundColor: Colors.blue[700],
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                    side: const BorderSide(color: Colors.blue, width: 1),
                  ),
                ),
                // ),
              ),
              /*
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _startTimer(issue),
                icon: const Icon(Icons.play_arrow, size: 14),
                //label: const Text('T', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[50],
                  foregroundColor: Colors.green[700],
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                    side: const BorderSide(color: Colors.green, width: 1),
                  ),
                ),
                //),
              ),
              */
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18),
                tooltip: 'More options',
                onSelected: (value) {
                  switch (value) {
                    case 'start timer':
                      _startTimer(issue);
                      break;
                    case 'edit':
                      _editIssue(issue);
                      break;
                    case 'delete':
                      _deleteIssue(issue);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'start timer',
                    child: Row(
                      children: [
                        Icon(Icons.play_arrow),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _getStatusColor(issue.status)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            /*
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 4, right: 6),
                              decoration: BoxDecoration(
                                color: _getPriorityColor(issue.priority),
                                shape: BoxShape.circle,
                              ),
                            ),
                            */
                            Expanded(
                              child: Text(
                                issue.title,
                                style: _getTitleStyle(issue.priority,
                                    fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.folder,
                              size: 11,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                issue.projectName,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF667eea),
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /*
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 4, right: 6),
                            decoration: BoxDecoration(
                              color: _getPriorityColor(issue.priority)
                                  .withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                          ),
                          */
                          Expanded(
                            child: Text(
                              issue.title,
                              style:
                                  _getTitleStyle(issue.priority, fontSize: 13)
                                      .copyWith(
                                color: Colors.grey[600],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.folder,
                            size: 11,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              issue.projectName,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
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
            // Two-column layout: content on left, menu on right
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left column: all content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title with priority dot
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /*
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 4, right: 6),
                            decoration: BoxDecoration(
                              color: _getPriorityColor(issue.priority),
                              shape: BoxShape.circle,
                            ),
                          ),
                          */
                          Expanded(
                            child: Text(
                              issue.title,
                              style:
                                  _getTitleStyle(issue.priority, fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Project and assignee info
                      Row(
                        children: [
                          Icon(
                            Icons.folder,
                            size: 11,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              issue.projectName,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF667eea),
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (issue.totalTimeSeconds > 0) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.timer,
                              size: 11,
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
                        ],
                      ),
                      const SizedBox(height: 3),
                      // Assignee and tags in one line
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.person,
                            size: 11,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 3),
                          //Expanded(
                          //  child:
                          Text(
                            issue.assigneeName ?? 'Unassigned',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          //),
                          if (issue.tagObjects.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            ...issue.tagObjects
                                .map((tag) => Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: hexToColor(tag.color)
                                            .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: hexToColor(tag.color)
                                              .withValues(alpha: 0.5),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        tag.shortName,
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: hexToColor(tag.color),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    )))
                                .toList(),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Right column: menu button
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 16),
                  tooltip: 'More options',
                  onSelected: (value) {
                    switch (value) {
                      case 'description':
                        _showDescriptionDialog(issue);
                        break;
                      case 'timer':
                        if (UserSession.instance.isLoggedIn) {
                          _startTimer(issue);
                        }
                        break;
                      case 'edit':
                        _editIssue(issue);
                        break;
                      case 'delete':
                        _deleteIssue(issue);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'description',
                      child: Row(
                        children: [
                          Icon(Icons.info, size: 16),
                          SizedBox(width: 8),
                          Text('View description'),
                        ],
                      ),
                    ),
                    if (UserSession.instance.isLoggedIn)
                      const PopupMenuItem(
                        value: 'timer',
                        child: Row(
                          children: [
                            Icon(Icons.play_arrow, size: 16),
                            SizedBox(width: 8),
                            Text('Start timer'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 16),
                          SizedBox(width: 8),
                          Text('Edit issue'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete,
                              size: 16, color: Color(0xFFD32F2F)),
                          SizedBox(width: 8),
                          Text('Delete issue',
                              style: TextStyle(color: Color(0xFFD32F2F))),
                        ],
                      ),
                    ),
                  ],
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
    return Column(
      children: [
        // Header section that mimics AppBar functionality
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _selectedProjects.isNotEmpty && _selectedProjects.length == 1
                      ? _getProjectName(_selectedProjects.first)
                      : 'All Issues',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // View toggle button
              IconButton(
                icon: Icon(_isKanbanView ? Icons.view_list : Icons.view_column),
                onPressed: () {
                  setState(() {
                    _isKanbanView = !_isKanbanView;
                  });
                  _updateUrlFilters(); // Update URL when view mode changes
                },
                tooltip: _isKanbanView
                    ? 'Switch to List View'
                    : 'Switch to Kanban View',
              ),
              if (_hasActiveFilters())
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: _copyFilteredUrl,
                  tooltip: 'Copy filtered URL',
                ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _createIssue,
                tooltip: 'Create New Issue',
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadData,
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        // Body content
        Expanded(
          child: Column(
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
                                  style:
                                      Theme.of(context).textTheme.headlineSmall,
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
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Create your first issue to get started',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  ],
                                ),
                              )
                            : _isKanbanView
                                ? _buildKanbanBoard()
                                : _buildIssuesListView(),
              ),
            ],
          ),
        ),
      ],
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
  List<FileAttachment> _attachments = [];
  bool _isUploading = false;
  List<Tag> _projectTags = [];
  List<String> _selectedTags = [];

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
      _attachments = List.from(widget.issue!.attachments);

      // Initialize selected tags from existing issue tags
      if (widget.issue!.tags.isNotEmpty) {
        _selectedTags =
            widget.issue!.tags.split(',').map((tag) => tag.trim()).toList();
      }

      // Load project tags for existing issues
      _loadProjectTags(widget.issue!.projectId);
    } else {
      // For new issues, select the first project by default
      if (widget.projects.isNotEmpty) {
        _selectedProjectId = widget.projects.first.id;
        _loadProjectTags(widget.projects.first.id);
      }

      // Set the logged-in user as the default assignee for new issues
      if (UserSession.instance.isLoggedIn &&
          UserSession.instance.userId != null) {
        _assigneeId = UserSession.instance.userId;
      }
    }
  }

  Future<void> _loadProjectTags(int projectId) async {
    try {
      final response = await HttpService().get(
          '${Config.instance.buildApiUrl('project_tags.php')}?project_id=$projectId');
      final data = json.decode(response.body);

      if (data['success']) {
        setState(() {
          _projectTags = (data['tags'] as List)
              .map((tagJson) => Tag.fromJson(tagJson))
              .toList();
        });
      }
    } catch (e) {
      // Silently handle errors
    }
  }

  void _addTag(String tagName) {
    if (!_selectedTags.contains(tagName)) {
      setState(() {
        _selectedTags.add(tagName);
        _tagsController.text = _selectedTags.join(', ');
      });
    }
  }

  void _removeTag(String tagName) {
    setState(() {
      _selectedTags.remove(tagName);
      _tagsController.text = _selectedTags.join(', ');
    });
  }

  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _isUploading = true;
        });

        for (final file in result.files) {
          if (file.path != null) {
            try {
              // For new issues, we'll need to create the issue first
              if (widget.issue == null) {
                // Store the file path for later upload after issue creation
                // For now, we'll show a message that files can only be uploaded after creation
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Files can be uploaded after the issue is created'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
                break;
              } else {
                // Upload file for existing issue
                final attachment = await FileUploadService().uploadFile(
                  widget.issue!.id,
                  file.path!,
                );
                if (attachment != null) {
                  setState(() {
                    _attachments.add(attachment);
                  });
                }
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to upload ${file.name}: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking files: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _removeAttachment(FileAttachment attachment) {
    setState(() {
      _attachments.remove(attachment);
    });
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
                  if (value != null) {
                    _loadProjectTags(value);
                  }
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
              // Tags input field hidden - using clickable tags instead
              if (_projectTags.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Project Tags:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _projectTags.map((tag) {
                    final isSelected = _selectedTags.contains(tag.shortName);
                    return GestureDetector(
                      onTap: () {
                        if (isSelected) {
                          _removeTag(tag.shortName);
                        } else {
                          _addTag(tag.shortName);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _parseColor(tag.color)
                              : _parseColor(tag.color).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _parseColor(tag.color),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          tag.shortName,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : _parseColor(tag.color),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
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
              const SizedBox(height: 16),
              // File attachments section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Attachments',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      if (widget.issue !=
                          null) // Only show upload button for existing issues
                        ElevatedButton.icon(
                          onPressed: _isUploading ? null : _pickAndUploadFiles,
                          icon: _isUploading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.upload_file),
                          label: Text(
                              _isUploading ? 'Uploading...' : 'Upload Files'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[50],
                            foregroundColor: Colors.blue[700],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_attachments.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.grey[50],
                      ),
                      child: Column(
                        children: _attachments.map((attachment) {
                          return FileAttachmentWidget(
                            attachment: attachment,
                            onDelete: widget.issue != null
                                ? () => _removeAttachment(attachment)
                                : null,
                          );
                        }).toList(),
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.grey[50],
                      ),
                      child: Text(
                        widget.issue != null
                            ? 'No attachments. Click "Upload Files" to add files.'
                            : 'Files can be uploaded after the issue is created.',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ],
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

class IssueDetailDialog extends StatefulWidget {
  final Issue issue;

  const IssueDetailDialog({
    super.key,
    required this.issue,
  });

  @override
  State<IssueDetailDialog> createState() => _IssueDetailDialogState();
}

class _IssueDetailDialogState extends State<IssueDetailDialog> {
  List<Map<String, dynamic>> _timerEntries = [];
  bool _isLoadingEntries = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTimerEntries();
  }

  Future<void> _loadTimerEntries() async {
    setState(() {
      _isLoadingEntries = true;
      _errorMessage = null;
    });

    try {
      final entries =
          await TimeTrackingService.instance.getTimerEntries(widget.issue.id);
      if (mounted) {
        setState(() {
          _timerEntries = entries ?? [];
          _isLoadingEntries = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load timer entries: $e';
          _isLoadingEntries = false;
        });
      }
    }
  }

  void _copyIssueLink() {
    final baseUrl = Config.instance.baseUrl;
    final queryParams = {'issue_id': widget.issue.id.toString()};
    final queryString = queryParams.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final url = '$baseUrl/#/issues?$queryString';

    Clipboard.setData(ClipboardData(text: url));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Issue link copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _formatDateTime(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return timestamp;
    }
  }

  String _formatUnixTime(int unixTime) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(unixTime * 1000);
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.issue.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _copyIssueLink(),
                  icon: const Icon(Icons.link),
                  tooltip: 'Copy issue link',
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Issue Information Section
                    _buildInfoSection('Issue Information', [
                      _buildInfoRow('Project', widget.issue.projectName),
                      _buildInfoRow(
                          'Status',
                          widget.issue.status
                              .replaceAll('_', ' ')
                              .toUpperCase()),
                      _buildInfoRow(
                          'Priority', widget.issue.priority.toUpperCase()),
                      _buildInfoRow('Creator', widget.issue.creatorName),
                      _buildInfoRow('Assignee',
                          widget.issue.assigneeName ?? 'Unassigned'),
                      _buildInfoRow(
                          'Created', _formatDateTime(widget.issue.createdAt)),
                      _buildInfoRow(
                          'Updated', _formatDateTime(widget.issue.updatedAt)),
                      if (widget.issue.totalTimeSeconds > 0)
                        _buildInfoRow(
                            'Total Time',
                            TimeTrackingService.instance.formatDurationHuman(
                                widget.issue.totalTimeSeconds)),
                    ]),

                    const SizedBox(height: 24),

                    // Tags Section
                    if (widget.issue.tagObjects.isNotEmpty) ...[
                      _buildInfoSection('Tags', [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: widget.issue.tagObjects.map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: hexToColor(tag.color)
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: hexToColor(tag.color)
                                      .withValues(alpha: 0.5),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                tag.shortName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: hexToColor(tag.color),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ]),
                      const SizedBox(height: 24),
                    ],

                    // Description Section
                    _buildInfoSection('Description', [
                      widget.issue.description.isNotEmpty
                          ? IssueDescriptionWidget(
                              description: widget.issue.description,
                              maxLines: 100,
                            )
                          : const Text(
                              'No description provided.',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey,
                              ),
                            ),
                    ]),

                    const SizedBox(height: 24),

                    // Attachments Section
                    if (widget.issue.attachments.isNotEmpty) ...[
                      _buildInfoSection('Attachments', [
                        ...widget.issue.attachments.map((attachment) {
                          return FileAttachmentWidget(
                            attachment: attachment,
                          );
                        }).toList(),
                      ]),
                      const SizedBox(height: 24),
                    ],

                    // Timer Entries Section
                    _buildTimerEntriesSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF008080),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerEntriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Timer Entries',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF008080),
              ),
            ),
            const Spacer(),
            if (UserSession.instance.isLoggedIn)
              ElevatedButton.icon(
                onPressed: () => _showAddTimerEntryDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Entry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF008080),
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: _isLoadingEntries
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Column(
                      children: [
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _loadTimerEntries,
                          child: const Text('Retry'),
                        ),
                      ],
                    )
                  : _timerEntries.isEmpty
                      ? const Text(
                          'No timer entries found.',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey,
                          ),
                        )
                      : Column(
                          children: _timerEntries.map((entry) {
                            return _buildTimerEntryCard(entry);
                          }).toList(),
                        ),
        ),
      ],
    );
  }

  Widget _buildTimerEntryCard(Map<String, dynamic> entry) {
    final startTime = entry['start_time'] as int;
    final stopTime = entry['stop_time'] as int?;
    final durationSeconds = entry['duration_seconds'] as int;
    final userName = entry['user_name'] as String;
    final isActive = stopTime == null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'By $userName',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatUnixTime(startTime)} - ${isActive ? 'Active' : _formatUnixTime(stopTime)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (!isActive) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF008080),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  TimeTrackingService.instance
                      .formatDurationHuman(durationSeconds),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'ACTIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: UserSession.instance.isLoggedIn
            ? PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _showEditTimerEntryDialog(entry);
                      break;
                    case 'delete':
                      _deleteTimerEntry(entry);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  Future<void> _showAddTimerEntryDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => TimerEntryDialog(
        issueId: widget.issue.id,
        isNewEntry: true,
      ),
    );

    if (result != null) {
      await _loadTimerEntries();
    }
  }

  Future<void> _showEditTimerEntryDialog(Map<String, dynamic> entry) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => TimerEntryDialog(
        issueId: widget.issue.id,
        entry: entry,
        isNewEntry: false,
      ),
    );

    if (result != null) {
      await _loadTimerEntries();
    }
  }

  Future<void> _deleteTimerEntry(Map<String, dynamic> entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Timer Entry'),
        content:
            const Text('Are you sure you want to delete this timer entry?'),
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
        final success =
            await TimeTrackingService.instance.deleteTimerEntry(entry['id']);
        if (success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Timer entry deleted successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
          await _loadTimerEntries();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to delete timer entry'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

class TimerEntryDialog extends StatefulWidget {
  final int issueId;
  final Map<String, dynamic>? entry;
  final bool isNewEntry;

  const TimerEntryDialog({
    super.key,
    required this.issueId,
    this.entry,
    required this.isNewEntry,
  });

  @override
  State<TimerEntryDialog> createState() => _TimerEntryDialogState();
}

class _TimerEntryDialogState extends State<TimerEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  DateTime _startDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  DateTime _endDate = DateTime.now();
  TimeOfDay _endTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    if (!widget.isNewEntry && widget.entry != null) {
      final startTime = DateTime.fromMillisecondsSinceEpoch(
          widget.entry!['start_time'] * 1000);
      final stopTime = DateTime.fromMillisecondsSinceEpoch(
          widget.entry!['stop_time'] * 1000);

      _startDate = DateTime(startTime.year, startTime.month, startTime.day);
      _startTime = TimeOfDay(hour: startTime.hour, minute: startTime.minute);
      _endDate = DateTime(stopTime.year, stopTime.month, stopTime.day);
      _endTime = TimeOfDay(hour: stopTime.hour, minute: stopTime.minute);
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isNewEntry ? 'Add Timer Entry' : 'Edit Timer Entry'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Start Date and Time
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Start Date'),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () => _selectDate(context, true),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                  '${_startDate.day}/${_startDate.month}/${_startDate.year}'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Start Time'),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () => _selectTime(context, true),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                  '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // End Date and Time
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('End Date'),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () => _selectDate(context, false),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                  '${_endDate.day}/${_endDate.month}/${_endDate.year}'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('End Time'),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () => _selectTime(context, false),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                  '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final startDateTime = DateTime(
                _startDate.year,
                _startDate.month,
                _startDate.day,
                _startTime.hour,
                _startTime.minute,
              );
              final endDateTime = DateTime(
                _endDate.year,
                _endDate.month,
                _endDate.day,
                _endTime.hour,
                _endTime.minute,
              );

              if (endDateTime.isBefore(startDateTime)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('End time must be after start time'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final startTime = startDateTime.millisecondsSinceEpoch ~/ 1000;
              final stopTime = endDateTime.millisecondsSinceEpoch ~/ 1000;

              try {
                bool success;
                if (widget.isNewEntry) {
                  success = await TimeTrackingService.instance.createTimerEntry(
                    userId: UserSession.instance.userId!,
                    issueId: widget.issueId,
                    startTime: startTime,
                    stopTime: stopTime,
                  );
                } else {
                  success = await TimeTrackingService.instance.updateTimerEntry(
                    entryId: widget.entry!['id'],
                    startTime: startTime,
                    stopTime: stopTime,
                  );
                }

                if (success) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(widget.isNewEntry
                            ? 'Timer entry created successfully'
                            : 'Timer entry updated successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                  Navigator.of(context).pop({'success': true});
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(widget.isNewEntry
                            ? 'Failed to create timer entry'
                            : 'Failed to update timer entry'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            }
          },
          child: Text(widget.isNewEntry ? 'Create' : 'Update'),
        ),
      ],
    );
  }
}
