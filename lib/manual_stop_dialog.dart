import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'time_tracking_service.dart';
import 'config.dart';

class ManualStopDialog extends StatefulWidget {
  final String issueTitle;
  final String projectName;

  const ManualStopDialog({
    super.key,
    required this.issueTitle,
    required this.projectName,
  });

  @override
  State<ManualStopDialog> createState() => _ManualStopDialogState();
}

class _ManualStopDialogState extends State<ManualStopDialog> {
  final _formKey = GlobalKey<FormState>();
  final _hoursController = TextEditingController();
  final _minutesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Set default values to 0
    _hoursController.text = '0';
    _minutesController.text = '0';
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final hours = int.tryParse(_hoursController.text) ?? 0;
    final minutes = int.tryParse(_minutesController.text) ?? 0;

    if (hours == 0 && minutes == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a duration greater than 0'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (UserSession.instance.isLoggedIn &&
          UserSession.instance.userId != null) {
        final success = await TimeTrackingService.instance.stopTimerManual(
          UserSession.instance.userId!,
          hours,
          minutes,
        );

        if (success && mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Timer stopped: ${hours}h ${minutes}m'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to stop timer'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Stop Timer Manually'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set the actual time you stopped working on:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.issueTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.projectName,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _hoursController,
                    decoration: const InputDecoration(
                      labelText: 'Hours',
                      border: OutlineInputBorder(),
                      suffixText: 'h',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      final hours = int.tryParse(value);
                      if (hours == null || hours < 0 || hours > 24) {
                        return '0-24';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _minutesController,
                    decoration: const InputDecoration(
                      labelText: 'Minutes',
                      border: OutlineInputBorder(),
                      suffixText: 'm',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      final minutes = int.tryParse(value);
                      if (minutes == null || minutes < 0 || minutes > 59) {
                        return '0-59';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'This will set the timer duration to exactly ${_hoursController.text}h ${_minutesController.text}m',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Stop Timer'),
        ),
      ],
    );
  }
}
