#!/bin/bash

# SSL Certificate Setup Script for RAG AI PDF Chat
# This script helps you set up HTTPS with Let's Encrypt

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 RAG AI PDF Chat - HTTPS Setup${NC}"
echo "=================================="

# Check if domain is provided
if [ -z "$1" ]; then
    echo -e "${RED}❌ Error: Please provide your domain name${NC}"
    echo "Usage: $0 yourdomain.com"
    exit 1
fi

DOMAIN=$1
EMAIL=${2:-"admin@$DOMAIN"}

echo -e "${YELLOW}📋 Domain: $DOMAIN${NC}"
echo -e "${YELLOW}📧 Email: $EMAIL${NC}"
echo ""

# Check DNS resolution
echo -e "${BLUE}🔍 Checking DNS resolution...${NC}"
SERVER_IP=$(curl -s ifconfig.me)
DOMAIN_IP=$(dig +short $DOMAIN | tail -1)

if [ -z "$DOMAIN_IP" ]; then
    echo -e "${RED}❌ Error: DNS not configured for $DOMAIN${NC}"
    echo "Please add an A record in your DNS settings:"
    echo "  $DOMAIN -> $SERVER_IP"
    exit 1
fi

if [ "$DOMAIN_IP" != "$SERVER_IP" ]; then
    echo -e "${RED}❌ Error: DNS mismatch${NC}"
    echo "Domain $DOMAIN resolves to $DOMAIN_IP but server is at $SERVER_IP"
    echo "Please update your DNS A record to point to $SERVER_IP"
    exit 1
fi

echo -e "${GREEN}✅ DNS configured correctly${NC}"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Error: Docker is not running${NC}"
    exit 1
fi

# Create necessary directories
echo -e "${BLUE}📁 Creating directories...${NC}"
mkdir -p data/certbot/conf
mkdir -p data/certbot/www

# Update nginx config with domain
echo -e "${BLUE}🔧 Updating nginx configuration...${NC}"
sed -i "s/YOUR_DOMAIN/$DOMAIN/g" nginx/nginx.conf

# Start nginx temporarily for certificate challenge
echo -e "${BLUE}🌐 Starting nginx for certificate challenge...${NC}"
docker compose -f docker-compose.prod.yml up -d web

# Wait for nginx to start
sleep 5

# Get SSL certificate
echo -e "${BLUE}🔐 Getting SSL certificate from Let's Encrypt...${NC}"
docker run --rm -v "$(pwd)/data/certbot/conf:/etc/letsencrypt" \
    -v "$(pwd)/data/certbot/www:/var/www/certbot" \
    certbot/certbot:latest certonly --webroot \
    --webroot-path=/var/www/certbot \
    --email "$EMAIL" \
    --agree-tos \
    --no-eff-email \
    -d "$DOMAIN" \
    -d "www.$DOMAIN"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ SSL certificate obtained successfully!${NC}"

    # Add HTTPS server block to nginx config
    echo -e "${BLUE}🔧 Adding HTTPS configuration...${NC}"
    cat >> nginx/nginx.conf << EOF

  # HTTPS server
  server {
    listen 443 ssl;
    server_name $DOMAIN www.$DOMAIN;

    # SSL certificates
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    client_max_body_size 50m;
    client_body_timeout 120s;

    # API routes
    location /upload/pdf {
      proxy_pass http://server;
      proxy_set_header Host \$host;
      proxy_set_header X-Real-IP \$remote_addr;
      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto \$scheme;
      proxy_http_version 1.1;
      proxy_set_header Connection "";
      proxy_connect_timeout 60s;
      proxy_send_timeout 120s;
      proxy_read_timeout 120s;
      proxy_buffering off;
    }

    location /chat {
      proxy_pass http://server;
      proxy_set_header Host \$host;
      proxy_set_header X-Real-IP \$remote_addr;
      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto \$scheme;
      proxy_http_version 1.1;
      proxy_set_header Connection "";
      proxy_connect_timeout 60s;
      proxy_send_timeout 120s;
      proxy_read_timeout 120s;
      proxy_buffering off;
    }

    # Frontend routes
    location / {
      proxy_pass http://client;
      proxy_set_header Host \$host;
      proxy_set_header X-Real-IP \$remote_addr;
      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto \$scheme;
      proxy_http_version 1.1;
      proxy_set_header Connection "";
      proxy_set_header Upgrade \$http_upgrade;
      proxy_set_header Connection "upgrade";
    }

    # Static files caching
    location ~* \\.(js|css|png|jpg|jpeg|gif|ico|svg)\$ {
      proxy_pass http://client;
      expires 1y;
      add_header Cache-Control "public, immutable";
    }
  }
EOF

    # Update HTTP server to redirect to HTTPS
    sed -i 's/# HTTP server (temporary - will redirect to HTTPS once SSL is ready)/# HTTP to HTTPS redirect/' nginx/nginx.conf
    sed -i '/server_name ragai.buzz www.ragai.buzz _;/a\    return 301 https://$host$request_uri;' nginx/nginx.conf

    # Restart services with SSL
    echo -e "${BLUE}🔄 Restarting services with HTTPS...${NC}"
    docker compose -f docker-compose.prod.yml down
    docker compose -f docker-compose.prod.yml up -d

    echo ""
    echo -e "${GREEN}🎉 Setup complete!${NC}"
    echo -e "${GREEN}🌐 Your app is now available at: https://$DOMAIN${NC}"
    echo ""
    echo -e "${YELLOW}📝 Next steps:${NC}"
    echo "1. Point your domain's DNS A record to your server's IP: $(curl -s ifconfig.me)"
    echo "2. Set up automatic certificate renewal:"
    echo "   crontab -e"
    echo "   Add: 0 12 * * * /usr/bin/docker run --rm -v $(pwd)/data/certbot/conf:/etc/letsencrypt -v $(pwd)/data/certbot/www:/var/www/certbot certbot/certbot:latest renew --webroot --webroot-path=/var/www/certbot && docker compose -f docker-compose.prod.yml restart web"
else
    echo -e "${RED}❌ Failed to obtain SSL certificate${NC}"
    echo "Please check your DNS configuration and try again."
    exit 1
fi
    echo "2. Wait for DNS propagation (can take up to 24 hours)"
    echo "3. Test your site: https://$DOMAIN"
    echo ""
    echo -e "${YELLOW}🔄 Certificate renewal:${NC}"
    echo "Certificates auto-renew. To manually renew:"
    echo "docker compose -f docker-compose.prod.yml run --rm certbot renew"
    echo "docker compose -f docker-compose.prod.yml restart web"

else
    echo -e "${RED}❌ Failed to obtain SSL certificate${NC}"
    echo "Make sure:"
    echo "1. Your domain DNS points to this server"
    echo "2. Port 80 is accessible from the internet"
    echo "3. The domain is not behind Cloudflare proxy (set to DNS only)"
    exit 1
fi