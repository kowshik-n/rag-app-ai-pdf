#!/bin/bash

# RAG AI App Setup Script for Digital Ocean
# Supports both IP-based and Domain-based HTTPS setup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 RAG AI PDF Chat - Digital Ocean Setup${NC}"
echo "=========================================="
echo ""

# Check if docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}📦 Installing Docker...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    usermod -aG docker root
fi

echo -e "${GREEN}✅ Docker is installed${NC}"

# Get the current IP
SERVER_IP=$(curl -s ifconfig.me)
echo -e "${YELLOW}Server IP: $SERVER_IP${NC}"
echo ""

# Ask user for setup preference
echo -e "${BLUE}Choose your setup:${NC}"
echo "1) IP-based access (http://$SERVER_IP) - No HTTPS"
echo "2) Custom domain with HTTPS - Requires domain ownership"
echo ""
read -p "Enter choice (1 or 2): " SETUP_CHOICE

echo ""

if [ "$SETUP_CHOICE" = "1" ]; then
    # IP-based setup (HTTP only)
    echo -e "${BLUE}🔧 Setting up for IP-based access: http://$SERVER_IP${NC}"
    echo ""
    
    # Update nginx config with IP
    echo -e "${YELLOW}Updating nginx configuration...${NC}"
    sed -i "s/YOUR_DOMAIN/$SERVER_IP/g" nginx/nginx.conf
    
    # Start services
    echo -e "${YELLOW}Starting services...${NC}"
    docker compose -f docker-compose.prod.yml up --build -d
    
    sleep 10
    
    echo ""
    echo -e "${GREEN}✅ Services started successfully!${NC}"
    echo ""
    echo -e "${YELLOW}📝 Access your application:${NC}"
    echo -e "${GREEN}http://$SERVER_IP${NC}"
    echo ""
    echo -e "${YELLOW}📝 Check service status:${NC}"
    echo "docker compose -f docker-compose.prod.yml ps"
    echo ""
    
elif [ "$SETUP_CHOICE" = "2" ]; then
    # Domain-based setup with HTTPS
    read -p "Enter your domain name (e.g., example.com): " DOMAIN
    read -p "Enter your email for SSL notifications: " EMAIL
    
    echo ""
    echo -e "${BLUE}🔍 Checking DNS configuration...${NC}"
    
    # Check DNS
    DOMAIN_IP=$(dig +short $DOMAIN 2>/dev/null | tail -1 || echo "")
    
    if [ -z "$DOMAIN_IP" ]; then
        echo -e "${RED}❌ DNS not configured for $DOMAIN${NC}"
        echo ""
        echo -e "${YELLOW}📝 Please configure DNS:${NC}"
        echo "If using DigitalOcean:"
        echo "1. Go to Networking → Domains"
        echo "2. Add domain: $DOMAIN"
        echo "3. Create A record: @ -> $SERVER_IP"
        echo ""
        echo "For other registrars:"
        echo "1. Add A record: $DOMAIN -> $SERVER_IP"
        echo "2. Wait 24-48 hours for DNS propagation"
        echo ""
        echo "Then run: $0"
        exit 1
    fi
    
    if [ "$DOMAIN_IP" != "$SERVER_IP" ]; then
        echo -e "${RED}❌ DNS mismatch!${NC}"
        echo "Domain $DOMAIN resolves to $DOMAIN_IP"
        echo "But server is at $SERVER_IP"
        echo ""
        echo -e "${YELLOW}📝 Update your DNS records to point to: $SERVER_IP${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ DNS configured correctly${NC}"
    echo ""
    
    # Create directories
    echo -e "${BLUE}📁 Creating certificate directories...${NC}"
    mkdir -p data/certbot/conf
    mkdir -p data/certbot/www
    
    # Update nginx config
    echo -e "${BLUE}🔧 Updating nginx configuration...${NC}"
    sed -i "s/YOUR_DOMAIN/$DOMAIN/g" nginx/nginx.conf
    
    # Start nginx for certificate challenge
    echo -e "${BLUE}🌐 Starting nginx for certificate challenge...${NC}"
    docker compose -f docker-compose.prod.yml up -d web
    sleep 5
    
    # Get SSL certificate
    echo -e "${BLUE}🔐 Requesting SSL certificate from Let's Encrypt...${NC}"
    docker run --rm \
        -v "$(pwd)/data/certbot/conf:/etc/letsencrypt" \
        -v "$(pwd)/data/certbot/www:/var/www/certbot" \
        -v "$(pwd)/nginx/nginx.conf:/app/nginx.conf" \
        certbot/certbot:latest certonly --webroot \
        --webroot-path=/var/www/certbot \
        --email "$EMAIL" \
        --agree-tos \
        --no-eff-email \
        -d "$DOMAIN" \
        -d "www.$DOMAIN"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ SSL certificate obtained!${NC}"
        echo ""
        
        # Add HTTPS configuration
        echo -e "${BLUE}🔧 Adding HTTPS configuration...${NC}"
        
        # Create HTTPS server block
        cat >> nginx/nginx.conf << 'EOF'

  # HTTPS server
  server {
    listen 443 ssl http2;
    server_name DOMAIN_PLACEHOLDER www.DOMAIN_PLACEHOLDER;

    # SSL certificates
    ssl_certificate /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/privkey.pem;

    # SSL Security settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    client_max_body_size 50m;
    client_body_timeout 120s;

    # API routes
    location /upload/pdf {
      proxy_pass http://server:8000;
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;
      proxy_http_version 1.1;
      proxy_set_header Connection "";
      proxy_connect_timeout 60s;
      proxy_send_timeout 120s;
      proxy_read_timeout 120s;
      proxy_buffering off;
    }

    location /chat {
      proxy_pass http://server:8000;
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;
      proxy_http_version 1.1;
      proxy_set_header Connection "";
      proxy_connect_timeout 60s;
      proxy_send_timeout 120s;
      proxy_read_timeout 120s;
      proxy_buffering off;
    }

    # Frontend routes
    location / {
      proxy_pass http://client:3000;
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;
      proxy_http_version 1.1;
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection "upgrade";
    }
  }

  # HTTP to HTTPS redirect
  server {
    listen 80;
    server_name DOMAIN_PLACEHOLDER www.DOMAIN_PLACEHOLDER;
    return 301 https://$host$request_uri;
  }
EOF

        # Replace domain placeholder
        sed -i "s/DOMAIN_PLACEHOLDER/$DOMAIN/g" nginx/nginx.conf

        # Restart services
        echo -e "${BLUE}🔄 Restarting services with HTTPS...${NC}"
        docker compose -f docker-compose.prod.yml down
        docker compose -f docker-compose.prod.yml up --build -d

        sleep 10

        echo ""
        echo -e "${GREEN}🎉 Setup complete!${NC}"
        echo ""
        echo -e "${YELLOW}✅ Your app is ready:${NC}"
        echo -e "${GREEN}https://$DOMAIN${NC}"
        echo -e "${GREEN}https://www.$DOMAIN${NC}"
        echo ""
        echo -e "${YELLOW}📝 SSL Certificate Details:${NC}"
        echo "Valid for: $DOMAIN and www.$DOMAIN"
        echo "Issuer: Let's Encrypt"
        echo "Auto-renewal: Enabled"
        echo ""

    else
        echo -e "${RED}❌ Failed to obtain SSL certificate${NC}"
        echo "Troubleshooting:"
        echo "1. Check DNS: dig $DOMAIN"
        echo "2. Ensure port 80 is open"
        echo "3. If using Cloudflare, set to DNS-only mode"
        exit 1
    fi
else
    echo -e "${RED}Invalid choice. Exiting.${NC}"
    exit 1
fi

echo -e "${BLUE}📊 Monitor your services:${NC}"
echo ""
echo "docker compose -f docker-compose.prod.yml ps"
echo "docker compose -f docker-compose.prod.yml logs -f"
echo ""
echo -e "${BLUE}🛑 Stop services:${NC}"
echo "docker compose -f docker-compose.prod.yml down"
