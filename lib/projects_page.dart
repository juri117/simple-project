import 'package:flutter/material.dart';
import 'dart:convert';
import 'config.dart';
import 'time_tracking_service.dart';
import 'http_service.dart';
import 'tag.dart';

class Project {
  final int id;
  final String name;
  final String description;
  final String status;
  final String createdAt;
  final String updatedAt;
  final int totalTimeSeconds; // Total time spent on all issues in this project
  final List<Tag> tags; // Tags assigned to this project

  Project({
    required this.id,
    required this.name,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.totalTimeSeconds = 0,
    this.tags = const [],
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    List<Tag> tags = [];
    if (json['tags'] != null && json['tags'] is List) {
      try {
        tags = (json['tags'] as List)
            .map((tagJson) => Tag.fromJson(tagJson))
            .toList();
      } catch (e) {
        print('Error parsing tags for project ${json['id']}: $e');
        tags = [];
      }
    }

    return Project(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? 'active',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      totalTimeSeconds: json['total_time_seconds'] ?? 0,
      tags: tags,
    );
  }
}

class ProjectsPage extends StatefulWidget {
  final Function(int)? onProjectTap;

  const ProjectsPage({super.key, this.onProjectTap});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  List<Project> _projects = [];
  bool _isLoading = true;
  bool _isError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();

    // Add a small delay to ensure session is properly initialized
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _loadProjects();
      }
    });
  }

  Future<void> _loadProjects() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _isError = false;
      });
    }

    try {
      final url = Config.instance.buildApiUrl('projects.php');

      final response = await HttpService().get(url);

      // Handle authentication errors
      if (await HttpService().handleAuthError(response)) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isError = true;
            _errorMessage = 'Authentication required. Please log in again.';
          });
        }
        return;
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              try {
                _projects = (data['projects'] as List).map((project) {
                  print('Parsing project: ${project['name']}');
                  return Project.fromJson(project);
                }).toList();
              } catch (e) {
                print('Error parsing projects: $e');
                setState(() {
                  _isError = true;
                  _errorMessage = 'Error parsing project data: $e';
                });
              }
            });
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
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _isError = true;
              _errorMessage = data['error'] ?? 'Failed to load projects';
              _isLoading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isError = true;
            _errorMessage =
                'HTTP ${response.statusCode}: ${response.reasonPhrase}';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isError = true;
          _errorMessage = 'Connection error: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadTimeStats() async {
    if (!UserSession.instance.isLoggedIn) return;

    final stats = await TimeTrackingService.instance.getTimeStats(
      userId: UserSession.instance.userId,
    );

    if (stats != null && mounted) {
      // Update projects with time data
      final projectStats = Map<int, int>.fromEntries(
        (stats['projects'] as List).map((stat) => MapEntry(
              stat['project_id'] as int,
              stat['total_seconds'] as int,
            )),
      );

      setState(() {
        _projects = _projects.map((project) {
          final timeSpent = projectStats[project.id] ?? 0;
          return Project(
            id: project.id,
            name: project.name,
            description: project.description,
            status: project.status,
            createdAt: project.createdAt,
            updatedAt: project.updatedAt,
            totalTimeSeconds: timeSpent,
          );
        }).toList();
      });
    }
  }

  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
  }

  Future<void> _createProject() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const ProjectDialog(),
    );

    if (result != null) {
      try {
        final url = Config.instance.buildApiUrl('projects.php');

        final response = await HttpService().post(url, body: result);

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
                  content: Text('Project created successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
            _loadProjects();
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(data['error'] ?? 'Failed to create project'),
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

  Future<void> _editProject(Project project) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => ProjectDialog(project: project),
    );

    if (result != null) {
      try {
        final url = Config.instance.buildApiUrl('projects.php');

        final response = await HttpService().put(url, body: result);

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
                  content: Text('Project updated successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
            _loadProjects();
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(data['error'] ?? 'Failed to update project'),
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

  Future<void> _deleteProject(Project project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text('Are you sure you want to delete "${project.name}"?'),
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
        final url = Config.instance.buildApiUrl('projects.php');

        final response =
            await HttpService().delete(url, body: {'id': project.id});

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
                  content: Text('Project deleted successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
            _loadProjects();
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(data['error'] ?? 'Failed to delete project'),
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
              const Text(
                'Projects',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _createProject,
                tooltip: 'Create New Project',
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadProjects,
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        // Body content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _isError
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading projects',
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
                            onPressed: _loadProjects,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _projects.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.folder_open,
                                  size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text(
                                'No projects yet',
                                style:
                                    Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Create your first project to get started',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadProjects,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _projects.length,
                            itemBuilder: (context, index) {
                              final project = _projects[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                child: InkWell(
                                  onTap: () {
                                    if (widget.onProjectTap != null) {
                                      widget.onProjectTap!(project.id);
                                    }
                                  },
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(16),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            project.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: project.status == 'active'
                                                ? Colors.green
                                                : Colors.orange,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            project.status.toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (project.description.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            project.description,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium,
                                          ),
                                        ],
                                        if (project.tags.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 4,
                                            runSpacing: 4,
                                            children: project.tags.map((tag) {
                                              return Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: _parseColor(tag.color)
                                                      .withOpacity(0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color:
                                                        _parseColor(tag.color),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Text(
                                                  tag.shortName,
                                                  style: TextStyle(
                                                    color:
                                                        _parseColor(tag.color),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Text(
                                              'Created: ${project.createdAt}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                      color: Colors.grey[600]),
                                            ),
                                            if (project.totalTimeSeconds >
                                                0) ...[
                                              const SizedBox(width: 16),
                                              Icon(
                                                Icons.timer,
                                                size: 12,
                                                color: Colors.grey[600],
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                TimeTrackingService.instance
                                                    .formatDurationHuman(project
                                                        .totalTimeSeconds),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: Colors.grey[600],
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                              ),
                                            ],
                                            const Spacer(),
                                            Icon(
                                              Icons.arrow_forward_ios,
                                              size: 16,
                                              color: Colors.grey[600],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    trailing: PopupMenuButton<String>(
                                      onSelected: (value) {
                                        switch (value) {
                                          case 'edit':
                                            _editProject(project);
                                            break;
                                          case 'delete':
                                            _deleteProject(project);
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
                                              Icon(Icons.delete,
                                                  color: Colors.red),
                                              SizedBox(width: 8),
                                              Text(
                                                'Delete',
                                                style: TextStyle(
                                                    color: Colors.red),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}

class ProjectDialog extends StatefulWidget {
  final Project? project;

  const ProjectDialog({super.key, this.project});

  @override
  State<ProjectDialog> createState() => _ProjectDialogState();
}

class _ProjectDialogState extends State<ProjectDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _status = 'active';
  List<Tag> _allTags = [];
  List<int> _selectedTagIds = [];
  bool _isLoadingTags = true;

  @override
  void initState() {
    super.initState();
    if (widget.project != null) {
      _nameController.text = widget.project!.name;
      _descriptionController.text = widget.project!.description;
      _status = widget.project!.status;
      _selectedTagIds = widget.project!.tags.map((tag) => tag.id).toList();
    }
    _loadTags();
  }

  Future<void> _loadTags() async {
    try {
      final response =
          await HttpService().get(Config.instance.buildApiUrl('tags.php'));
      final data = json.decode(response.body);

      if (data['success']) {
        setState(() {
          _allTags = (data['tags'] as List)
              .map((tagJson) => Tag.fromJson(tagJson))
              .toList();
          _isLoadingTags = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingTags = false;
      });
    }
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
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.project == null ? 'Create Project' : 'Edit Project'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Project Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a project name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(
                      value: 'completed', child: Text('Completed')),
                  DropdownMenuItem(value: 'on-hold', child: Text('On Hold')),
                ],
                onChanged: (value) {
                  setState(() {
                    _status = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Tags',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_isLoadingTags)
                const Center(child: CircularProgressIndicator())
              else
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Column(
                      children: _allTags.map((tag) {
                        final isSelected = _selectedTagIds.contains(tag.id);

                        return CheckboxListTile(
                          title: Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: _parseColor(tag.color),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(tag.shortName),
                            ],
                          ),
                          subtitle: tag.description.isNotEmpty
                              ? Text(tag.description)
                              : null,
                          value: isSelected,
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                _selectedTagIds.add(tag.id);
                              } else {
                                _selectedTagIds.remove(tag.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
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
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final data = {
                'name': _nameController.text.trim(),
                'description': _descriptionController.text.trim(),
                'status': _status,
                'tag_ids': _selectedTagIds,
              };

              if (widget.project != null) {
                data['id'] = widget.project!.id.toString();
              }

              Navigator.of(context).pop(data);
            }
          },
          child: Text(widget.project == null ? 'Create' : 'Update'),
        ),
      ],
    );
  }
}
