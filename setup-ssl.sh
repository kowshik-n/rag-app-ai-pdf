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
    -d "$DOMAIN"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ SSL certificate obtained successfully!${NC}"

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