#!/bin/bash

echo "🚀 Deploying Simple Project..."

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: Please run this script from the Flutter project root directory"
    exit 1
fi

# Build the Flutter web app
echo "📦 Building Flutter web app..."
flutter build web

if [ $? -ne 0 ]; then
    echo "❌ Error: Flutter build failed"
    exit 1
fi

# Check if Apache is running
if ! systemctl is-active --quiet apache2; then
    echo "⚠️  Warning: Apache is not running. Starting Apache..."
    sudo systemctl start apache2
fi

# Create web directory if it doesn't exist
sudo mkdir -p /var/www/html

# Deploy Flutter web app
echo "📤 Deploying Flutter web app..."
sudo cp -r build/web/* /var/www/html/

# Deploy PHP backend
echo "📤 Deploying PHP backend..."
sudo cp -r backend /var/www/html/

# Set proper permissions
echo "🔐 Setting permissions..."
sudo chown -R www-data:www-data /var/www/html/
sudo chmod -R 755 /var/www/html/
sudo chmod 664 /var/www/html/backend/database.sqlite

# Initialize database if it doesn't exist
if [ ! -f "/var/www/html/backend/database.sqlite" ]; then
    echo "🗄️  Initializing database..."
    cd /var/www/html/backend
    sudo -u www-data php init_db.php
    cd - > /dev/null
fi

echo "✅ Deployment complete!"
echo ""
echo "🌐 Your app is now available at:"
echo "   - Flutter Web App: http://localhost"
echo "   - PHP Backend: http://localhost/backend/"
echo ""
echo "🔑 Demo credentials:"
echo "   - Username: admin"
echo "   - Password: admin123"
echo ""
echo "📝 To test the API directly:"
echo "   curl -X POST http://localhost/backend/login.php \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"username\":\"admin\",\"password\":\"admin123\"}'" 