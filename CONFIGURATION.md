# Configuration System

This application uses a flexible configuration system that allows for deployment-specific overrides.

## Configuration Priority

The application loads configuration in the following order:

1. **Project Root `config.json`** (highest priority) - For deployment overrides
2. **Bundled Asset `assets/config.json`** (fallback) - Default configuration
3. **Hardcoded Fallback** (lowest priority) - Emergency fallback

## Deployment Configuration

To override the default configuration on your web server:

1. Create a `config.json` file in the project root (same directory as `pubspec.yaml`)
2. Add your deployment-specific configuration:

```json
{
  "backend": {
    "url": "https://your-production-backend-url.com"
  }
}
```

## Benefits

- **No Code Changes**: You can change configuration without rebuilding the app
- **Environment-Specific**: Different servers can have different configurations
- **Safe Fallbacks**: If the override file is missing or invalid, the app falls back to bundled config
- **Version Control Safe**: The override file is ignored by git (see `.gitignore`)

## Example Use Cases

- **Development**: Use bundled `assets/config.json` with localhost URLs
- **Staging**: Create `config.json` with staging server URLs
- **Production**: Create `config.json` with production server URLs

## File Structure

```
your-project/
├── assets/
│   └── config.json          # Default configuration (bundled)
├── config.json              # Deployment override (ignored by git)
├── pubspec.yaml
└── lib/
    └── config.dart          # Configuration loading logic
```

## Troubleshooting

- Check the console logs to see which configuration file was loaded
- Ensure the `config.json` file has valid JSON syntax
- The override file must be in the project root (same level as `pubspec.yaml`)
