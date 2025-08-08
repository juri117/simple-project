#!/bin/bash

# Flutter Web App Deployment Script for subdirectory /sp/
# This script builds the Flutter web app for deployment to http://diaven.de/sp/

echo "🚀 Starting Flutter web app deployment to /sp/ subdirectory..."

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Build for web with base href for /sp/ subdirectory
echo "🔨 Building Flutter web app for /sp/ subdirectory..."
flutter build web --base-href /sp/

# Create .htaccess file for HTTPS redirection and Flutter routing
echo "🔒 Creating .htaccess file for HTTPS redirection..."
cat > build/web/.htaccess << 'EOF'
# Force HTTPS redirection
RewriteEngine On
RewriteCond %{HTTPS} off
RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]

# Handle Flutter routing - serve index.html for all routes
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule ^(.*)$ index.html [QSA,L]

# Security headers
Header always set X-Content-Type-Options nosniff
Header always set X-Frame-Options DENY
Header always set X-XSS-Protection "1; mode=block"
Header always set Referrer-Policy "strict-origin-when-cross-origin"

# Cache static assets
<FilesMatch "\.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$">
    ExpiresActive On
    ExpiresDefault "access plus 1 year"
    Header set Cache-Control "public, immutable"
</FilesMatch>
EOF

echo "✅ Build completed successfully!"
echo ""
echo "📁 Built files are located in: build/web/"
echo ""
echo "🌐 To deploy to https://diaven.de/sp/:"
echo "   1. Upload the contents of build/web/ to your server's /sp/ directory"
echo "   2. The .htaccess file will automatically redirect HTTP to HTTPS"
echo "   3. Make sure your backend is accessible at https://diaven.de/backend"
echo ""
echo "📋 Example deployment commands:"
echo "   # Using rsync (if you have SSH access):"
echo "   rsync -avz build/web/ user@diaven.de:/path/to/your/web/root/sp/"
echo ""
echo "   # Using scp:"
echo "   scp -r build/web/* user@diaven.de:/path/to/your/web/root/sp/"
echo ""
echo "🔧 Server configuration notes:"
echo "   - The .htaccess file will handle HTTPS redirection automatically"
echo "   - Ensure your web server (Apache) has mod_rewrite enabled"
echo "   - The /sp/ directory should be accessible via https://diaven.de/sp/"
echo "   - All assets will be served from /sp/ (e.g., /sp/main.dart.js)"
echo ""
echo "🔒 HTTPS redirection is now configured!"
echo "   - HTTP requests will be automatically redirected to HTTPS"
echo "   - Security headers are included for better protection"
echo "   - Static assets are cached for better performance"
echo ""
echo "🎯 Your app will be available at: https://diaven.de/sp/" 