#!/bin/bash

echo "Setting up web server for Simple Project..."

# Check if Apache is installed
if ! command -v apache2 &> /dev/null; then
    echo "Installing Apache2..."
    sudo apt update
    sudo apt install -y apache2
fi

# Check if PHP is installed
if ! command -v php &> /dev/null; then
    echo "Installing PHP and required extensions..."
    sudo apt install -y php libapache2-mod-php php-sqlite3
fi

# Enable required Apache modules
echo "Enabling Apache modules..."
sudo a2enmod rewrite
sudo a2enmod headers

# Create a simple Apache configuration for the project
echo "Creating Apache configuration..."
sudo tee /etc/apache2/sites-available/simple-project.conf > /dev/null <<EOF
<VirtualHost *:80>
    ServerName localhost
    DocumentRoot /var/www/html
    
    # Serve Flutter web app
    Alias / /var/www/html/
    
    # Serve PHP backend
    Alias /backend /var/www/html/backend
    
    <Directory /var/www/html/backend>
        AllowOverride All
        Require all granted
    </Directory>
    
    <Directory /var/www/html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

# Enable the site
sudo a2ensite simple-project.conf

# Restart Apache
echo "Restarting Apache..."
sudo systemctl restart apache2

echo "Web server setup complete!"
echo ""
echo "To deploy your Flutter web app:"
echo "1. Build the Flutter web app: flutter build web"
echo "2. Copy the build/web contents to /var/www/html/"
echo "3. Copy the backend folder to /var/www/html/backend/"
echo ""
echo "The app will be available at: http://localhost"
echo "The PHP backend will be available at: http://localhost/backend/" 