# Simple Project

A Flutter web application for project and issue management.

## Features

- **Project Management**: Create, edit, and manage projects
- **Issue Tracking**: Create, assign, and track issues with full CRUD operations
- **User Management**: Manage users and assign issues
- **Advanced Filtering**: Filter issues by project, status, priority, tags, creator, and assignee
- **Markdown Support**: Rich text formatting in issue descriptions

## Markdown Support

Issue descriptions now support markdown formatting! You can use the following markdown features:

### Text Formatting
- **Bold text**: `**bold**` or `__bold__`
- *Italic text*: `*italic*` or `_italic_`
- `Inline code`: Use backticks
- ~~Strikethrough~~: `~~text~~`

### Headers
- # H1 Header
- ## H2 Header  
- ### H3 Header

### Lists
- Unordered lists: `- item` or `* item`
- Ordered lists: `1. item`

### Code Blocks
```
Use triple backticks for code blocks
```

### Links
[Link text](URL)

### Blockquotes
> Use > for blockquotes

### Preview Mode
When creating or editing issues, you can toggle between "Edit" and "Preview" modes to see how your markdown will be rendered.

## Getting Started

1. Start the PHP backend server:
   ```bash
   cd backend
   php -S localhost:8000
   ```

2. Run the Flutter web app:
   ```bash
   flutter run -d chrome
   ```

3. Open your browser and navigate to `http://localhost:3000`

## Database Setup

The application uses SQLite for data storage. The database will be automatically created when you first run the application.

## API Endpoints

- `GET /projects.php` - Get all projects
- `POST /projects.php` - Create a new project
- `PUT /projects.php` - Update a project
- `DELETE /projects.php` - Delete a project

- `GET /issues.php` - Get all issues
- `POST /issues.php` - Create a new issue
- `PUT /issues.php` - Update an issue
- `DELETE /issues.php` - Delete an issue

- `GET /users.php` - Get all users
- `POST /users.php` - Create a new user
- `PUT /users.php` - Update a user
- `DELETE /users.php` - Delete a user

## Technologies Used

- **Frontend**: Flutter Web
- **Backend**: PHP with SQLite
- **Markdown Rendering**: flutter_markdown package
- **Routing**: go_router
- **HTTP Client**: http package
