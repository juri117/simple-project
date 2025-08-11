import 'dart:convert';
import 'package:flutter/material.dart';
import 'config.dart';
import 'http_service.dart';

class FileAttachment {
  final int id;
  final int issueId;
  final String originalFilename;
  final String storedFilename;
  final int fileSize;
  final String mimeType;
  final String createdAt;
  final String uploadedByName;

  FileAttachment({
    required this.id,
    required this.issueId,
    required this.originalFilename,
    required this.storedFilename,
    required this.fileSize,
    required this.mimeType,
    required this.createdAt,
    required this.uploadedByName,
  });

  factory FileAttachment.fromJson(Map<String, dynamic> json) {
    return FileAttachment(
      id: json['id'] ?? 0,
      issueId: json['issue_id'] ?? 0,
      originalFilename: json['original_filename'] ?? '',
      storedFilename: json['stored_filename'] ?? '',
      fileSize: json['file_size'] ?? 0,
      mimeType: json['mime_type'] ?? 'application/octet-stream',
      createdAt: json['created_at'] ?? '',
      uploadedByName: json['uploaded_by_name'] ?? 'Unknown',
    );
  }

  String get fileSizeFormatted {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  bool get isImage {
    return mimeType.startsWith('image/');
  }

  String get fileUrl {
    return Config.instance.buildApiUrl('serve_file.php?id=$id');
  }
}

class FileUploadService {
  static final FileUploadService _instance = FileUploadService._internal();
  factory FileUploadService() => _instance;
  FileUploadService._internal();

  Future<List<FileAttachment>> getAttachments(int issueId) async {
    try {
      final response = await HttpService().get(
        Config.instance.buildApiUrl('get_attachments.php?issue_id=$issueId'),
      );

      if (await HttpService().handleAuthError(response)) {
        throw Exception('Authentication required. Please log in again.');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return (data['attachments'] as List)
              .map((attachment) => FileAttachment.fromJson(attachment))
              .toList();
        } else {
          throw Exception(data['error'] ?? 'Failed to load attachments');
        }
      } else {
        throw Exception(
            'HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      throw Exception('Failed to load attachments: $e');
    }
  }

  Future<FileAttachment?> uploadFile(int issueId, String filePath) async {
    try {
      final request = await HttpService().createMultipartRequest(
        Config.instance.buildApiUrl('upload_file.php'),
        'POST',
      );

      // Add the file
      final file = await HttpService().createMultipartFile(filePath);
      request.files.add(file);

      // Add the issue ID
      request.fields['issue_id'] = issueId.toString();

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = json.decode(responseBody);
        print('Upload response: $data'); // Debug log
        if (data['success'] == true && data['attachment'] != null) {
          try {
            return FileAttachment.fromJson(data['attachment']);
          } catch (e) {
            print('Error parsing attachment: $e');
            print('Attachment data: ${data['attachment']}');
            throw Exception('Failed to parse attachment data: $e');
          }
        } else {
          throw Exception(data['error'] ?? 'Failed to upload file');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: $responseBody');
      }
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }
}

class FileAttachmentWidget extends StatelessWidget {
  final FileAttachment attachment;
  final VoidCallback? onDelete;

  const FileAttachmentWidget({
    super.key,
    required this.attachment,
    this.onDelete,
  });

  Future<void> _deleteAttachment() async {
    try {
      final response = await HttpService().delete(
        Config.instance.buildApiUrl('delete_attachment.php'),
        body: {'id': attachment.id},
      );

      if (await HttpService().handleAuthError(response)) {
        throw Exception('Authentication required. Please log in again.');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          // Call the onDelete callback to update the UI
          onDelete?.call();
        } else {
          throw Exception(data['error'] ?? 'Failed to delete attachment');
        }
      } else {
        throw Exception(
            'HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      // Show error message - we'll just call onDelete to let the parent handle errors
      // The parent widget can show error messages in its context
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _buildFileIcon(),
        title: Text(
          attachment.originalFilename,
          style: const TextStyle(fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${attachment.fileSizeFormatted} • ${attachment.uploadedByName}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            Text(
              attachment.createdAt,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () => _downloadFile(context),
              tooltip: 'Download file',
            ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: _deleteAttachment,
                tooltip: 'Delete file',
              ),
          ],
        ),
        onTap: () => _openFile(context),
      ),
    );
  }

  Widget _buildFileIcon() {
    if (attachment.isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          attachment.fileUrl,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.image, color: Colors.grey),
            );
          },
        ),
      );
    }

    IconData iconData;
    Color iconColor;

    switch (attachment.mimeType) {
      case 'application/pdf':
        iconData = Icons.picture_as_pdf;
        iconColor = Colors.red;
        break;
      case 'text/plain':
      case 'text/csv':
        iconData = Icons.description;
        iconColor = Colors.blue;
        break;
      case 'application/zip':
      case 'application/x-rar-compressed':
        iconData = Icons.archive;
        iconColor = Colors.orange;
        break;
      default:
        iconData = Icons.insert_drive_file;
        iconColor = Colors.grey;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(iconData, color: iconColor, size: 20),
    );
  }

  void _openFile(BuildContext context) {
    if (attachment.isImage) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: Text(attachment.originalFilename),
            ),
            body: Center(
              child: InteractiveViewer(
                child: Image.network(
                  attachment.fileUrl,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Text('Failed to load image'),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      _downloadFile(context);
    }
  }

  void _downloadFile(BuildContext context) {
    // For web, this will trigger a download
    // For mobile, you might want to use a different approach
    final url = Uri.parse(attachment.fileUrl);
    // You could use url_launcher or similar package here
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening ${attachment.originalFilename}...'),
      ),
    );
  }
}
