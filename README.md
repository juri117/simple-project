# Simple Project - Flutter Web App with PHP Backend

A Flutter web application with a PHP backend and SQLite database for user authentication.

## Features

- **Flutter Web App**: Modern, responsive login interface and project management
- **PHP Backend**: RESTful API for user authentication and project CRUD operations
- **SQLite Database**: Lightweight database for user and project management
- **Secure Authentication**: Password hashing and validation
- **Project Management**: Create, read, update, and delete projects with soft delete

## Project Structure

```
simple_project/
├── lib/
│   ├── main.dart              # Flutter app entry point
│   ├── login_screen.dart      # Login screen UI
│   └── projects_page.dart     # Project management UI
├── backend/
│   ├── init_db.php            # Database initialization script
│   ├── login.php              # Login API endpoint
│   ├── projects.php           # Projects CRUD API endpoint
│   ├── database.sqlite        # SQLite database (created after setup)
│   └── .htaccess              # Apache configuration
├── setup_web_server.sh        # Web server setup script
└── README.md                  # This file
```

## Prerequisites

- Flutter SDK (with web support)
- PHP 8.0+ with SQLite extension
- Apache web server (for deployment)
- Modern web browser

## Setup Instructions

### 1. Install Dependencies

```bash
# Install Flutter dependencies
flutter pub get

# Install PHP and SQLite (if not already installed)
sudo apt update
sudo apt install -y php-cli php-sqlite3
```

### 2. Initialize Database

```bash
cd backend
php init_db.php
```

This creates the SQLite database with a sample user:
- **Username**: admin
- **Password**: admin123

### 3. Development Setup

For development, you can run the Flutter app locally:

```bash
# Run Flutter web app
flutter run -d web-server --web-port 8080

# In another terminal, start a simple PHP server for the backend
cd backend
php -S localhost:8000
```

**Note**: You'll need to update the API URL in `lib/login_screen.dart` to point to `http://localhost:8000/login.php` for development.

### 4. Production Deployment

#### Option A: Using the Setup Script

```bash
# Run the web server setup script
sudo ./setup_web_server.sh

# Build the Flutter web app
flutter build web

# Deploy to web server
sudo cp -r build/web/* /var/www/html/
sudo cp -r backend /var/www/html/
```

#### Option B: Manual Setup

1. **Install Apache and PHP**:
   ```bash
   sudo apt install apache2 php libapache2-mod-php php-sqlite3
   sudo a2enmod rewrite headers
   sudo systemctl restart apache2
   ```

2. **Build and Deploy Flutter App**:
   ```bash
   flutter build web
   sudo cp -r build/web/* /var/www/html/
   sudo cp -r backend /var/www/html/
   ```

3. **Set Permissions**:
   ```bash
   sudo chown -R www-data:www-data /var/www/html/
   sudo chmod -R 755 /var/www/html/
   ```

## Usage

1. Open your web browser and navigate to `http://localhost`
2. Use the demo credentials:
   - Username: `admin`
   - Password: `admin123`
3. The app will authenticate against the SQLite database

## API Endpoints

### POST /backend/login.php

Authenticates a user with username and password.

**Request Body**:
```json
{
  "username": "admin",
  "password": "admin123"
}
```

**Success Response**:
```json
{
  "success": true,
  "message": "Login successful",
  "user": {
    "id": 1,
    "username": "admin"
  }
}
```

**Error Response**:
```json
{
  "success": false,
  "error": "Invalid username or password"
}
```

### GET /backend/projects.php

Retrieves all active projects.

**Response**:
```json
{
  "success": true,
  "projects": [
    {
      "id": 1,
      "name": "Software",
      "description": "Software development project for new application features",
      "status": "active",
      "created_at": "2025-08-05 19:10:40",
      "updated_at": "2025-08-05 19:10:40"
    }
  ]
}
```

### POST /backend/projects.php

Creates a new project.

**Request Body**:
```json
{
  "name": "New Project",
  "description": "Project description",
  "status": "active"
}
```

**Response**:
```json
{
  "success": true,
  "message": "Project created successfully",
  "project": {
    "id": 3,
    "name": "New Project",
    "description": "Project description",
    "status": "active",
    "created_at": "2025-08-05 19:10:40",
    "updated_at": "2025-08-05 19:10:40"
  }
}
```

### PUT /backend/projects.php

Updates an existing project.

**Request Body**:
```json
{
  "id": "1",
  "name": "Updated Project",
  "description": "Updated description",
  "status": "completed"
}
```

### DELETE /backend/projects.php

Soft deletes a project (sets deleted flag).

**Request Body**:
```json
{
  "id": "1"
}
```

## Security Features

- **Password Hashing**: Passwords are hashed using PHP's `password_hash()` function
- **SQL Injection Prevention**: Uses prepared statements for database queries
- **CORS Support**: Configured for cross-origin requests
- **Input Validation**: Server-side validation of user inputs

## Customization

### Adding New Users

You can add new users by modifying the `init_db.php` script or creating a registration endpoint.

### Styling

The Flutter app uses Material Design 3 with a custom color scheme. You can modify the colors in `lib/login_screen.dart` and `lib/main.dart`.

### Database Schema

The current database schema includes:
- `users` table with `id`, `username`, `password`, and `created_at` fields

## Troubleshooting

### Common Issues

1. **CORS Errors**: Ensure the `.htaccess` file is properly configured
2. **Database Connection**: Check that SQLite is installed and the database file is writable
3. **Apache Configuration**: Verify that mod_rewrite and mod_headers are enabled

### Logs

- Apache logs: `/var/log/apache2/error.log`
- PHP errors: Check Apache error logs or enable PHP error logging

## License

This project is open source and available under the MIT License.
