# Authentication System Implementation

This document describes the simple session-based authentication system implemented for the project management application.

## Overview

The authentication system provides:
- Session-based authentication using secure tokens
- Automatic session expiration (24 hours)
- Protection for all API endpoints except login
- Automatic cleanup of expired sessions
- Seamless integration with the Flutter frontend

## Backend Components

### 1. Session Manager (`backend/session_manager.php`)
- Handles session creation, validation, and cleanup
- Uses secure random tokens (32 bytes, hex encoded)
- Sessions expire after 24 hours
- Database table: `sessions`

### 2. Authentication Middleware (`backend/auth_middleware.php`)
- Provides `requireAuth()` function for protected endpoints
- Validates Authorization header with Bearer token
- Returns user information for authenticated requests
- Automatically handles 401 responses for invalid sessions

### 3. Protected Endpoints
All API endpoints now require authentication except:
- `login.php` - Login endpoint
- `init_db.php` - Database initialization
- `check_db.php` - Database status check

Protected endpoints include:
- `users.php` - User management
- `projects.php` - Project CRUD operations
- `issues.php` - Issue CRUD operations
- `time_tracking.php` - Time tracking operations
- `logout.php` - Session termination

### 4. Database Schema
```sql
CREATE TABLE sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    session_token TEXT UNIQUE NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users (id)
);
```

## Frontend Components

### 1. HTTP Service (`lib/http_service.dart`)
- Centralized HTTP client with automatic authentication
- Automatically adds Authorization header with session token
- Handles 401 responses by clearing user session
- Provides consistent error handling across the app

### 2. User Session Management (`lib/config.dart`)
- Singleton class for managing user session state
- Stores user ID, username, and session token
- Provides `isLoggedIn` property for authentication checks
- Handles session clearing on logout

### 3. Authentication Flow
1. User enters credentials on login screen
2. Backend validates credentials and creates session
3. Frontend stores session token in UserSession
4. All subsequent requests include Authorization header
5. Backend validates session token on each request
6. On logout, session is destroyed and frontend clears state

## Setup Instructions

### 1. Initialize Sessions Table
```bash
cd backend
php init_sessions.php
```

### 2. Optional: Set up Session Cleanup
Add to crontab for automatic cleanup:
```bash
# Clean up expired sessions daily at 2 AM
0 2 * * * cd /path/to/backend && php cleanup_sessions.php
```

### 3. Test Authentication
1. Start the backend server
2. Open the Flutter app
3. Login with valid credentials
4. Verify that protected endpoints work
5. Test logout functionality

## Security Features

- **Secure Token Generation**: Uses `random_bytes(32)` for session tokens
- **Session Expiration**: Automatic expiration after 24 hours
- **Database Cleanup**: Expired sessions are automatically removed
- **Header Validation**: Strict validation of Authorization headers
- **Error Handling**: Graceful handling of authentication failures

## API Usage

### Login
```http
POST /login.php
Content-Type: application/json

{
  "username": "user",
  "password": "password"
}
```

Response:
```json
{
  "success": true,
  "message": "Login successful",
  "user": {
    "id": 1,
    "username": "user"
  },
  "session_token": "abc123..."
}
```

### Protected Endpoints
```http
GET /projects.php
Authorization: Bearer abc123...
Content-Type: application/json
```

### Logout
```http
POST /logout.php
Authorization: Bearer abc123...
```

## Error Handling

### 401 Unauthorized
- Invalid or missing Authorization header
- Expired session token
- Non-existent session

### Frontend Response
- Automatically clears user session
- Redirects to login page
- Shows appropriate error message

## Maintenance

### Session Cleanup
Run periodically to remove expired sessions:
```bash
php cleanup_sessions.php
```

### Database Monitoring
Check session table size:
```sql
SELECT COUNT(*) FROM sessions;
SELECT COUNT(*) FROM sessions WHERE expires_at <= datetime('now');
```

## Future Enhancements

- Session refresh mechanism
- Remember me functionality
- Multi-device session management
- Session activity logging
- Rate limiting for login attempts
