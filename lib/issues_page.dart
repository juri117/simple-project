import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Issue {
  final int id;
  final String title;
  final String description;
  final String status;
  final String priority;
  final String tags;
  final String createdAt;
  final String updatedAt;
  final String creatorName;
  final String? assigneeName;

  Issue({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    required this.creatorName,
    this.assigneeName,
  });

  factory Issue.fromJson(Map<String, dynamic> json) {
    return Issue(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      status: json['status'],
      priority: json['priority'],
      tags: json['tags'] ?? '',
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      creatorName: json['creator_name'],
      assigneeName: json['assignee_name'],
    );
  }
}

class User {
  final int id;
  final String username;

  User({required this.id, required this.username});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(id: json['id'], username: json['username']);
  }
}

class IssuesPage extends StatefulWidget {
  final int projectId;
  final String projectName;

  const IssuesPage({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<IssuesPage> createState() => _IssuesPageState();
}

class _IssuesPageState extends State<IssuesPage> {
  List<Issue> _issues = [];
  List<User> _users = [];
  bool _isLoading = true;
  bool _isError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _isError = false;
    });

    bool hasError = false;
    String errorMsg = '';

    // Load issues
    try {
      await _loadIssues();
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

    setState(() {
      _isLoading = false;
      if (hasError) {
        _isError = true;
        _errorMessage = errorMsg;
      }
    });
  }

  Future<void> _loadIssues() async {
    print('Loading issues for project ${widget.projectId}');
    final response = await http.get(
      Uri.parse(
        'http://localhost:8000/issues.php?project_id=${widget.projectId}',
      ),
      headers: {'Content-Type': 'application/json'},
    );
    print('Issues response status: ${response.statusCode}');
    print('Issues response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        setState(() {
          _issues = (data['issues'] as List)
              .map((issue) => Issue.fromJson(issue))
              .toList();
        });
      } else {
        throw Exception(data['error'] ?? 'Failed to load issues');
      }
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
    }
  }

  Future<void> _loadUsers() async {
    print('Loading users');
    final response = await http.get(
      Uri.parse('http://localhost:8000/users.php'),
      headers: {'Content-Type': 'application/json'},
    );
    print('Users response status: ${response.statusCode}');
    print('Users response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        setState(() {
          _users = (data['users'] as List)
              .map((user) => User.fromJson(user))
              .toList();
        });
      } else {
        throw Exception(data['error'] ?? 'Failed to load users');
      }
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
    }
  }

  Future<void> _createIssue() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          IssueDialog(users: _users, projectId: widget.projectId),
    );

    if (result != null) {
      try {
        final response = await http.post(
          Uri.parse('http://localhost:8000/issues.php'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(result),
        );

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
            _loadIssues();
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
          IssueDialog(issue: issue, users: _users, projectId: widget.projectId),
    );

    if (result != null) {
      try {
        final response = await http.put(
          Uri.parse('http://localhost:8000/issues.php'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(result),
        );

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
            _loadIssues();
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
        final response = await http.delete(
          Uri.parse('http://localhost:8000/issues.php'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'id': issue.id}),
        );

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
            _loadIssues();
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
      case 'open':
        return Colors.blue;
      case 'in_progress':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Issues - ${widget.projectName}'),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isError
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
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
                  const Icon(Icons.bug_report, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No issues yet',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first issue to get started',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadIssues,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _issues.length,
                itemBuilder: (context, index) {
                  final issue = _issues[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              issue.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getPriorityColor(issue.priority),
                              borderRadius: BorderRadius.circular(12),
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
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (issue.description.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              issue.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(issue.status),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  issue.status
                                      .replaceAll('_', ' ')
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (issue.tags.isNotEmpty) ...[
                                Icon(
                                  Icons.label,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  issue.tags,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: Colors.grey[600]),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.person,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'By ${issue.creatorName}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: Colors.grey[600]),
                              ),
                              if (issue.assigneeName != null) ...[
                                const SizedBox(width: 16),
                                Icon(
                                  Icons.assignment_ind,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Assigned to ${issue.assigneeName}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: Colors.grey[600]),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Created: ${issue.createdAt}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          switch (value) {
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
                                Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createIssue,
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class IssueDialog extends StatefulWidget {
  final Issue? issue;
  final List<User> users;
  final int projectId;

  const IssueDialog({
    super.key,
    this.issue,
    required this.users,
    required this.projectId,
  });

  @override
  State<IssueDialog> createState() => _IssueDialogState();
}

class _IssueDialogState extends State<IssueDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();
  String _status = 'open';
  String _priority = 'medium';
  int? _assigneeId;

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
        orElse: () => User(id: 0, username: ''),
      );
      _assigneeId = assignee.id > 0 ? assignee.id : null;
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
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Markdown supported)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
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
                        DropdownMenuItem(value: 'open', child: Text('Open')),
                        DropdownMenuItem(
                          value: 'in_progress',
                          child: Text('In Progress'),
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
                'project_id': widget.projectId.toString(),
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
