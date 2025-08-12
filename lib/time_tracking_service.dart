import 'dart:convert';
import 'dart:async';
import 'config.dart';
import 'http_service.dart';

class TimeTrackingService {
  static TimeTrackingService? _instance;
  static TimeTrackingService get instance {
    _instance ??= TimeTrackingService._internal();
    return _instance!;
  }

  TimeTrackingService._internal();

  Timer? _timer;
  int? _activeStartTime;
  String? _activeIssueTitle;
  String? _activeProjectName;
  int? _activeIssueId;
  int _elapsedSeconds = 0;

  // Stream controller for timer updates
  final StreamController<Map<String, dynamic>> _timerController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get timerStream => _timerController.stream;

  // Getters for current state
  bool get isTimerActive => _activeStartTime != null;
  int? get activeStartTime => _activeStartTime;
  String? get activeIssueTitle => _activeIssueTitle;
  String? get activeProjectName => _activeProjectName;
  int? get activeIssueId => _activeIssueId;
  int get elapsedSeconds => _elapsedSeconds;

  // Start timer for an issue
  Future<bool> startTimer(
      int userId, int issueId, String issueTitle, String projectName) async {
    try {
      final response = await HttpService().post(
        Config.instance.buildApiUrl('time_tracking.php'),
        body: {
          'action': 'start',
          'user_id': userId,
          'issue_id': issueId,
        },
      );

      // Handle authentication errors
      if (await HttpService().handleAuthError(response)) {
        return false;
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _activeStartTime = data['start_time'];
          _activeIssueTitle = issueTitle;
          _activeProjectName = projectName;
          _activeIssueId = issueId;
          _elapsedSeconds = 0;

          _startTimer();
          _notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Stop the active timer
  Future<bool> stopTimer(int userId) async {
    try {
      final response = await HttpService().post(
        Config.instance.buildApiUrl('time_tracking.php'),
        body: {
          'action': 'stop',
          'user_id': userId,
        },
      );

      // Handle authentication errors
      if (await HttpService().handleAuthError(response)) {
        return false;
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _stopTimer();
          _clearActiveTimer();
          _notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Stop timer manually with custom duration
  Future<bool> stopTimerManual(int userId, int hours, int minutes) async {
    try {
      final response = await HttpService().post(
        Config.instance.buildApiUrl('time_tracking.php'),
        body: {
          'action': 'stop_manual',
          'user_id': userId,
          'hours': hours,
          'minutes': minutes,
        },
      );

      // Handle authentication errors
      if (await HttpService().handleAuthError(response)) {
        return false;
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _stopTimer();
          _clearActiveTimer();
          _notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Get active timer from server
  Future<Map<String, dynamic>?> getActiveTimer(int userId) async {
    try {
      final response = await HttpService().get(
        '${Config.instance.buildApiUrl('time_tracking.php')}?action=active&user_id=$userId',
      );

      // Handle authentication errors
      if (await HttpService().handleAuthError(response)) {
        return null;
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['timer'] != null) {
          final timer = data['timer'];
          _activeStartTime = timer['start_time'];
          _activeIssueTitle = timer['issue_title'];
          _activeProjectName = timer['project_name'];
          _activeIssueId = timer['issue_id'];

          // Calculate elapsed time
          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          _elapsedSeconds = now - _activeStartTime!;

          _startTimer();
          _notifyListeners();
          return timer;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get time statistics
  Future<Map<String, dynamic>?> getTimeStats({
    int? userId,
    int? issueId,
    int? projectId,
  }) async {
    try {
      final queryParams = <String, String>{'action': 'stats'};
      if (userId != null) queryParams['user_id'] = userId.toString();
      if (issueId != null) queryParams['issue_id'] = issueId.toString();
      if (projectId != null) queryParams['project_id'] = projectId.toString();

      final uri = Uri.parse(Config.instance.buildApiUrl('time_tracking.php'))
          .replace(queryParameters: queryParams);

      final response = await HttpService().get(uri.toString());

      // Handle authentication errors
      if (await HttpService().handleAuthError(response)) {
        return null;
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['stats'];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get timer entries for a specific issue
  Future<List<Map<String, dynamic>>?> getTimerEntries(int issueId) async {
    try {
      final uri = Uri.parse(Config.instance.buildApiUrl('time_tracking.php'))
          .replace(queryParameters: {
        'action': 'entries',
        'issue_id': issueId.toString()
      });

      final response = await HttpService().get(uri.toString());

      // Handle authentication errors
      if (await HttpService().handleAuthError(response)) {
        return null;
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['entries']);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Create a new timer entry
  Future<bool> createTimerEntry({
    required int userId,
    required int issueId,
    required int startTime,
    required int stopTime,
  }) async {
    try {
      final response = await HttpService().post(
        Config.instance.buildApiUrl('time_tracking.php'),
        body: {
          'action': 'create_entry',
          'user_id': userId,
          'issue_id': issueId,
          'start_time': startTime,
          'stop_time': stopTime,
        },
      );

      // Handle authentication errors
      if (await HttpService().handleAuthError(response)) {
        return false;
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Update an existing timer entry
  Future<bool> updateTimerEntry({
    required int entryId,
    required int startTime,
    required int stopTime,
  }) async {
    try {
      final response = await HttpService().post(
        Config.instance.buildApiUrl('time_tracking.php'),
        body: {
          'action': 'update_entry',
          'entry_id': entryId,
          'start_time': startTime,
          'stop_time': stopTime,
        },
      );

      // Handle authentication errors
      if (await HttpService().handleAuthError(response)) {
        return false;
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Delete a timer entry
  Future<bool> deleteTimerEntry(int entryId) async {
    try {
      final response = await HttpService().post(
        Config.instance.buildApiUrl('time_tracking.php'),
        body: {
          'action': 'delete_entry',
          'entry_id': entryId,
        },
      );

      // Handle authentication errors
      if (await HttpService().handleAuthError(response)) {
        return false;
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Format seconds to HH:MM:SS
  String formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  // Format seconds to human readable format
  String formatDurationHuman(int seconds) {
    if (seconds < 60) {
      return '${seconds}s';
    } else if (seconds < 3600) {
      final minutes = seconds ~/ 60;
      return '${minutes}m';
    } else {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      return '${hours}h ${minutes}m';
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedSeconds++;
      _notifyListeners();
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _clearActiveTimer() {
    _activeStartTime = null;
    _activeIssueTitle = null;
    _activeProjectName = null;
    _activeIssueId = null;
    _elapsedSeconds = 0;
  }

  void _notifyListeners() {
    _timerController.add({
      'isActive': isTimerActive,
      'elapsedSeconds': _elapsedSeconds,
      'issueTitle': _activeIssueTitle,
      'projectName': _activeProjectName,
      'issueId': _activeIssueId,
    });
  }

  void dispose() {
    _timer?.cancel();
    _timerController.close();
  }
}
