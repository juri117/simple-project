import 'package:flutter/material.dart';
import 'dart:convert';
import 'config.dart';
import 'http_service.dart';
import 'all_issues_page.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  List<User> _users = [];
  bool _isLoading = true;
  String? _error;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    _loadUsers();
  }

  void _checkUserRole() {
    final userRole = UserSession.instance.userRole;
    setState(() {
      _isAdmin = userRole == 'admin';
    });
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await HttpService().get(
        Config.instance.buildApiUrl('users.php'),
      );

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
          setState(() {
            _users = (data['users'] as List)
                .map((user) => User.fromJson(user))
                .toList();
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = data['error'] ?? 'Failed to load users';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = 'Failed to load users';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showCreateUserDialog,
              tooltip: 'Create New User',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUsers,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_users.isEmpty) {
      return const Center(
        child: Text('No users found'),
      );
    }

    return ListView.builder(
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getRoleColor(user.role),
              child: Text(
                user.username[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(user.username),
            subtitle: Text('Role: ${_getRoleDisplayName(user.role)}'),
            trailing: _isAdmin
                ? PopupMenuButton<String>(
                    onSelected: (value) => _handleUserAction(value, user),
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
                        value: 'change_password',
                        child: Row(
                          children: [
                            Icon(Icons.lock),
                            SizedBox(width: 8),
                            Text('Change Password'),
                          ],
                        ),
                      ),
                      if (user.id != UserSession.instance.userId)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete',
                                  style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                    ],
                  )
                : user.id == UserSession.instance.userId
                    ? IconButton(
                        icon: const Icon(Icons.lock),
                        onPressed: () => _showChangePasswordDialog(user),
                        tooltip: 'Change Password',
                      )
                    : null,
          ),
        );
      },
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'normal':
        return Colors.blue;
      case 'deactivated':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'admin':
        return 'Administrator';
      case 'normal':
        return 'Normal User';
      case 'deactivated':
        return 'Deactivated';
      default:
        return role;
    }
  }

  void _handleUserAction(String action, User user) {
    switch (action) {
      case 'edit':
        _showEditUserDialog(user);
        break;
      case 'change_password':
        _showChangePasswordDialog(user);
        break;
      case 'delete':
        _showDeleteUserDialog(user);
        break;
    }
  }

  void _showCreateUserDialog() {
    showDialog(
      context: context,
      builder: (context) => const CreateUserDialog(),
    ).then((_) => _loadUsers());
  }

  void _showEditUserDialog(User user) {
    showDialog(
      context: context,
      builder: (context) => EditUserDialog(user: user),
    ).then((_) => _loadUsers());
  }

  void _showChangePasswordDialog(User user) {
    showDialog(
      context: context,
      builder: (context) => ChangePasswordDialog(user: user),
    );
  }

  void _showDeleteUserDialog(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
            'Are you sure you want to delete user "${user.username}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _deleteUser(user);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(User user) async {
    try {
      final response = await HttpService()
          .delete(Config.instance.buildApiUrl('users.php?id=${user.id}'));

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
                content: Text('User "${user.username}" deleted successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
          _loadUsers();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(data['error'] ?? 'Failed to delete user'),
                backgroundColor: Colors.red,
              ),
            );
          }
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

class CreateUserDialog extends StatefulWidget {
  const CreateUserDialog({super.key});

  @override
  State<CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'normal';
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New User'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a username';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'normal', child: Text('Normal User')),
                  DropdownMenuItem(
                      value: 'admin', child: Text('Administrator')),
                  DropdownMenuItem(
                      value: 'deactivated', child: Text('Deactivated')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value!;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createUser,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await HttpService()
          .post(Config.instance.buildApiUrl('users.php'), body: {
        'username': _usernameController.text.trim(),
        'password': _passwordController.text,
        'role': _selectedRole,
      });

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
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('User created successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(data['error'] ?? 'Failed to create user'),
                backgroundColor: Colors.red,
              ),
            );
          }
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
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

class EditUserDialog extends StatefulWidget {
  final User user;

  const EditUserDialog({super.key, required this.user});

  @override
  State<EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<EditUserDialog> {
  late String _selectedRole;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.user.role;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit User: ${widget.user.username}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: _selectedRole,
            decoration: const InputDecoration(
              labelText: 'Role',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'normal', child: Text('Normal User')),
              DropdownMenuItem(value: 'admin', child: Text('Administrator')),
              DropdownMenuItem(
                  value: 'deactivated', child: Text('Deactivated')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedRole = value!;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _updateUser,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Update'),
        ),
      ],
    );
  }

  Future<void> _updateUser() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await HttpService()
          .put(Config.instance.buildApiUrl('users.php'), body: {
        'id': widget.user.id,
        'role': _selectedRole,
      });

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
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('User updated successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(data['error'] ?? 'Failed to update user'),
                backgroundColor: Colors.red,
              ),
            );
          }
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
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

class ChangePasswordDialog extends StatefulWidget {
  final User user;

  const ChangePasswordDialog({super.key, required this.user});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isOwnPassword = false;

  @override
  void initState() {
    super.initState();
    _isOwnPassword = widget.user.id == UserSession.instance.userId;
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          'Change Password${_isOwnPassword ? '' : ' for ${widget.user.username}'}'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isOwnPassword) ...[
                TextFormField(
                  controller: _currentPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Current Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your current password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _newPasswordController,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a new password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm the new password';
                  }
                  if (value != _newPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _changePassword,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Change Password'),
        ),
      ],
    );
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      Map<String, dynamic> requestData;

      if (_isOwnPassword) {
        // User changing their own password
        requestData = {
          'current_password': _currentPasswordController.text,
          'new_password': _newPasswordController.text,
        };

        final response = await HttpService().post(
            Config.instance.buildApiUrl('change_password.php'),
            body: requestData);

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
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Password changed successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(data['error'] ?? 'Failed to change password'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      } else {
        // Admin changing another user's password
        requestData = {
          'id': widget.user.id,
          'password': _newPasswordController.text,
        };

        final response = await HttpService()
            .put(Config.instance.buildApiUrl('users.php'), body: requestData);

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
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Password changed successfully for ${widget.user.username}'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(data['error'] ?? 'Failed to change password'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
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
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
