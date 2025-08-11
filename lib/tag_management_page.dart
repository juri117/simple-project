import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'dart:convert';
import 'config.dart';
import 'http_service.dart';
import 'tag.dart';

class TagManagementPage extends StatefulWidget {
  const TagManagementPage({super.key});

  @override
  State<TagManagementPage> createState() => _TagManagementPageState();
}

class _TagManagementPageState extends State<TagManagementPage> {
  List<Tag> _tags = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response =
          await HttpService().get(Config.instance.buildApiUrl('tags.php'));
      final data = json.decode(response.body);

      if (data['success']) {
        setState(() {
          _tags = (data['tags'] as List)
              .map((tagJson) => Tag.fromJson(tagJson))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = data['error'] ?? 'Failed to load tags';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading tags: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _createTag() async {
    final result = await showDialog<Tag>(
      context: context,
      builder: (context) => const TagEditDialog(),
    );

    if (result != null) {
      await _loadTags();
    }
  }

  Future<void> _editTag(Tag tag) async {
    final result = await showDialog<Tag>(
      context: context,
      builder: (context) => TagEditDialog(tag: tag),
    );

    if (result != null) {
      await _loadTags();
    }
  }

  Future<void> _deleteTag(Tag tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disable Tag'),
        content: Text(
            'Are you sure you want to disable the tag "${tag.shortName}"? This will remove it from all projects and issues.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Disable'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final response = await HttpService().delete(
          Config.instance.buildApiUrl('tags.php'),
          body: {'id': tag.id},
        );

        final data = json.decode(response.body);

        if (data['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Tag "${tag.shortName}" disabled successfully')),
          );
          await _loadTags();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['error'] ?? 'Failed to disable tag')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error disabling tag: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tag Management'),
        actions: [
          IconButton(
            onPressed: _loadTags,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadTags,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _tags.isEmpty
                  ? const Center(
                      child: Text(
                        'No tags found. Create your first tag!',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _tags.length,
                      itemBuilder: (context, index) {
                        final tag = _tags[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: _parseColor(tag.color),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            title: Text(
                              tag.shortName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: tag.description.isNotEmpty
                                ? Text(tag.description)
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () => _editTag(tag),
                                  icon: const Icon(Icons.edit),
                                  tooltip: 'Edit tag',
                                ),
                                IconButton(
                                  onPressed: () => _deleteTag(tag),
                                  icon: const Icon(Icons.delete),
                                  tooltip: 'Disable tag',
                                  color: Colors.red,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createTag,
        child: const Icon(Icons.add),
        tooltip: 'Create new tag',
      ),
    );
  }

  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
  }
}

class TagEditDialog extends StatefulWidget {
  final Tag? tag;

  const TagEditDialog({super.key, this.tag});

  @override
  State<TagEditDialog> createState() => _TagEditDialogState();
}

class _TagEditDialogState extends State<TagEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _shortNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  Color _selectedColor = Colors.blue;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.tag != null) {
      _shortNameController.text = widget.tag!.shortName;
      _descriptionController.text = widget.tag!.description;
      _selectedColor = _parseColor(widget.tag!.color);
    }
  }

  @override
  void dispose() {
    _shortNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2)}';
  }

  Future<void> _saveTag() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final tagData = {
        'short_name': _shortNameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'color': _colorToHex(_selectedColor),
      };

      if (widget.tag != null) {
        tagData['id'] = widget.tag!.id.toString();
      }

      final response = widget.tag != null
          ? await HttpService().put(
              Config.instance.buildApiUrl('tags.php'),
              body: tagData,
            )
          : await HttpService().post(
              Config.instance.buildApiUrl('tags.php'),
              body: tagData,
            );

      final data = json.decode(response.body);

      if (data['success']) {
        if (mounted) {
          Navigator.of(context).pop(widget.tag != null
              ? Tag.fromJson(data['tag'])
              : Tag.fromJson(data['tag']));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['error'] ?? 'Failed to save tag')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving tag: $e')),
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.tag != null ? 'Edit Tag' : 'Create Tag'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _shortNameController,
              decoration: const InputDecoration(
                labelText: 'Short Name',
                hintText: 'e.g., bug, feature, enhancement',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Short name is required';
                }
                if (value.trim().length > 20) {
                  return 'Short name must be 20 characters or less';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Optional description of the tag',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Color: '),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Pick a color'),
                        content: SingleChildScrollView(
                          child: ColorPicker(
                            pickerColor: _selectedColor,
                            onColorChanged: (color) {
                              setState(() {
                                _selectedColor = color;
                              });
                            },
                            pickerAreaHeightPercent: 0.8,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _selectedColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveTag,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.tag != null ? 'Update' : 'Create'),
        ),
      ],
    );
  }
}
