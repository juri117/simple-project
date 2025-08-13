# Time Tracking Implementation

## Overview
This document describes the implementation of time tracking functionality for the project management application. The feature allows users to track time spent on issues and view time statistics across projects and issues.

## Features Implemented

### 1. Database Schema
- **Table**: `time_tracking`
- **Fields**:
  - `id` (INTEGER PRIMARY KEY)
  - `user_id` (INTEGER NOT NULL) - References users table
  - `issue_id` (INTEGER NOT NULL) - References issues table
  - `start_time` (INTEGER NOT NULL) - Unix timestamp
  - `stop_time` (INTEGER) - Unix timestamp (NULL if active)
  - `created_at` (DATETIME) - Record creation timestamp

### 2. Backend API (`time_tracking.php`)

#### Endpoints:
- **POST** `/time_tracking.php` - Start/Stop/Abort timers
- **GET** `/time_tracking.php?action=active&user_id=X` - Get active timer
- **GET** `/time_tracking.php?action=stats&user_id=X&issue_id=Y&project_id=Z` - Get time statistics

#### Features:
- Start timer for an issue (automatically stops any active timer for the same user)
- Stop active timer
- Abort active timer (delete without saving time)
- Get current active timer with issue and project details
- Get time statistics for issues and projects
- Support for filtering by user, issue, or project

### 3. Frontend Implementation

#### Time Tracking Service (`lib/time_tracking_service.dart`)
- Singleton service for managing timer state
- Real-time timer updates using StreamController
- API integration for start/stop/get active timer
- Time formatting utilities (HH:MM:SS and human-readable)

#### Timer Widget (`lib/timer_widget.dart`)
- Displays active timer in the header
- Shows issue name, project name, elapsed time, and stop button
- Real-time updates every second
- Only visible when timer is active

#### Updated Pages:

##### Issues Page (`lib/all_issues_page.dart`)
- Added start timer button (play icon) for each issue
- Displays total time spent on each issue
- Loads time statistics when user is logged in
- Only shows timer controls for logged-in users

##### Projects Page (`lib/projects_page.dart`)
- Displays total time spent on all issues in each project
- Loads time statistics when user is logged in

##### Main Layout (`lib/main_layout.dart`)
- Added timer widget to header area
- Only visible when user is logged in and timer is active

### 4. Updated Backend APIs

#### Issues API (`backend/issues.php`)
- Added `total_time_seconds` field to issue responses
- Calculates total time from completed time tracking entries

#### Projects API (`backend/projects.php`)
- Added `total_time_seconds` field to project responses
- Calculates total time from all issues in the project

## Usage

### Starting a Timer
1. Navigate to the Issues page
2. Click the play button (▶️) next to any issue
3. Timer starts and appears in the header
4. Any previously active timer is automatically stopped

### Stopping a Timer
1. Click the stop button (⏹️) in the header timer widget
2. Choose from the following options:
   - **Stop Now**: Stops the timer and saves the elapsed time
   - **Set Manual Time**: Allows setting a custom duration for the timer
   - **Abort & Delete**: Cancels the timer and deletes the record without saving any time

### Aborting a Timer
1. Click the stop button (⏹️) in the header timer widget
2. Select "Abort & Delete" from the dropdown menu
3. The timer is immediately cancelled and no time is recorded

### Viewing Time Statistics
- **Issues**: Total time spent is displayed next to each issue
- **Projects**: Total time spent is displayed for each project
- **Header**: Shows active timer with real-time countdown

## Technical Details

### Timer Behavior
- Only one timer can be active per user at a time
- Starting a new timer automatically stops the previous one
- Timers use Unix timestamps for precision
- Real-time updates every second in the UI

### Data Flow
1. User clicks start timer → API call to start timer
2. Timer service updates local state
3. Timer widget displays in header
4. Real-time updates via StreamController
5. User clicks stop → Choose from stop options:
   - **Stop Now**: API call to stop timer, time is saved
   - **Set Manual Time**: API call to stop timer with custom duration
   - **Abort & Delete**: API call to abort timer, record is deleted
6. Timer disappears from header
7. Time statistics are updated on next page load

### Security
- Timer operations require user authentication
- Users can only manage their own timers
- Time statistics are filtered by user when specified

## Database Queries

### Time Statistics Query
```sql
SELECT 
    tt.issue_id,
    i.title as issue_title,
    p.name as project_name,
    SUM(CASE WHEN tt.stop_time IS NOT NULL THEN tt.stop_time - tt.start_time ELSE 0 END) as total_seconds
FROM time_tracking tt
JOIN issues i ON tt.issue_id = i.id
JOIN projects p ON i.project_id = p.id
WHERE tt.user_id = ? AND i.deleted = 0
GROUP BY tt.issue_id, i.title, p.name
```

### Active Timer Query
```sql
SELECT tt.*, i.title as issue_title, p.name as project_name
FROM time_tracking tt
JOIN issues i ON tt.issue_id = i.id
JOIN projects p ON i.project_id = p.id
WHERE tt.user_id = ? AND tt.stop_time IS NULL
ORDER BY tt.start_time DESC
LIMIT 1
```

## Future Enhancements
- Time tracking reports and analytics
- Export time data to CSV/PDF
- Time tracking categories/tags
- Integration with external time tracking tools
- Bulk time entry operations
- Time tracking reminders and notifications
