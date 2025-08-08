import 'package:flutter/material.dart';
import 'time_tracking_service.dart';
import 'config.dart';
import 'manual_stop_dialog.dart';

class TimerWidget extends StatefulWidget {
  const TimerWidget({super.key});

  @override
  State<TimerWidget> createState() => _TimerWidgetState();
}

class _TimerWidgetState extends State<TimerWidget> {
  Map<String, dynamic> _timerState = {
    'isActive': false,
    'elapsedSeconds': 0,
    'issueTitle': null,
    'projectName': null,
    'issueId': null,
  };

  @override
  void initState() {
    super.initState();
    // Add a small delay to ensure session is properly initialized
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _loadActiveTimer();
      }
    });
    _subscribeToTimerUpdates();
  }

  void _loadActiveTimer() async {
    if (UserSession.instance.isLoggedIn &&
        UserSession.instance.userId != null &&
        UserSession.instance.sessionToken != null) {
      await TimeTrackingService.instance
          .getActiveTimer(UserSession.instance.userId!);
    }
  }

  void _subscribeToTimerUpdates() {
    TimeTrackingService.instance.timerStream.listen((state) {
      if (mounted) {
        setState(() {
          _timerState = state;
        });
      }
    });
  }

  Future<void> _stopTimer() async {
    if (UserSession.instance.isLoggedIn &&
        UserSession.instance.userId != null) {
      final success = await TimeTrackingService.instance
          .stopTimer(UserSession.instance.userId!);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Timer stopped'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _showManualStopDialog() async {
    if (_timerState['issueTitle'] != null &&
        _timerState['projectName'] != null) {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => ManualStopDialog(
          issueTitle: _timerState['issueTitle'],
          projectName: _timerState['projectName'],
        ),
      );

      if (result == true && mounted) {
        // Timer was stopped manually, no need to show additional message
        // as the dialog already shows a success message
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_timerState['isActive']) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Timer icon
          Icon(
            Icons.timer,
            size: 16,
            color: Colors.orange[700],
          ),
          const SizedBox(width: 8),

          // Issue info
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _timerState['issueTitle'] ?? 'Unknown Issue',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[700],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (_timerState['projectName'] != null)
                Text(
                  _timerState['projectName'],
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.orange[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
          const SizedBox(width: 8),

          // Timer display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange[700],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              TimeTrackingService.instance
                  .formatDuration(_timerState['elapsedSeconds']),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Stop button with menu
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'stop':
                  _stopTimer();
                  break;
                case 'stop_manual':
                  _showManualStopDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'stop',
                child: Row(
                  children: [
                    Icon(Icons.stop, size: 16),
                    SizedBox(width: 8),
                    Text('Stop Now'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'stop_manual',
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 16),
                    SizedBox(width: 8),
                    Text('Set Manual Time'),
                  ],
                ),
              ),
            ],
            tooltip: 'Stop timer options',
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red[700],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.stop,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
