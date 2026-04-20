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

# Create a temporary docker-compose override for certbot challenge
echo -e "${BLUE}🔧 Creating temporary nginx configuration...${NC}"
cat > docker-compose.certbot.yml << 'EOF'
version: '3.8'
services:
  web:
    image: nginx:stable-alpine
    ports:
      - '80:80'
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./data/certbot/www:/var/www/certbot:rw
EOF

# Start nginx with certbot volume for challenge
echo -e "${BLUE}🌐 Starting nginx for certificate challenge...${NC}"
docker compose -f docker-compose.certbot.yml up -d

# Wait for nginx to start
sleep 5

# Verify nginx is serving challenge directory
echo -e "${BLUE}🧪 Testing nginx setup...${NC}"
docker compose -f docker-compose.certbot.yml exec web mkdir -p /var/www/certbot/.well-known/acme-challenge

# Get SSL certificate
echo -e "${BLUE}🔐 Getting SSL certificate from Let's Encrypt...${NC}"
docker run --rm \
    -v "$(pwd)/data/certbot/conf:/etc/letsencrypt" \
    -v "$(pwd)/data/certbot/www:/var/www/certbot" \
    --network host \
    certbot/certbot:latest certonly --webroot \
    --webroot-path=/var/www/certbot \
    --email "$EMAIL" \
    --agree-tos \
    --no-eff-email \
    --rsa-key-size 2048 \
    -d "$DOMAIN" \
    -d "www.$DOMAIN"

CERT_RESULT=$?

# Stop temporary nginx
echo -e "${BLUE}🛑 Stopping temporary nginx...${NC}"
docker compose -f docker-compose.certbot.yml down
rm docker-compose.certbot.yml

if [ $CERT_RESULT -eq 0 ]; then
    echo -e "${GREEN}✅ SSL certificate obtained successfully!${NC}"
    echo ""

    # Add HTTPS server block to nginx config
    echo -e "${BLUE}🔧 Adding HTTPS configuration...${NC}"
    cat >> nginx/nginx.conf << EOF

  # HTTP to HTTPS redirect
  server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    
    # Let's Encrypt challenge
    location /.well-known/acme-challenge/ {
      root /var/www/certbot;
      try_files \$uri =404;
    }
    
    # Redirect all HTTP to HTTPS
    location / {
      return 301 https://\$host\$request_uri;
    }
  }

  # HTTPS server
  server {
    listen 443 ssl http2;
    server_name $DOMAIN www.$DOMAIN;

    # SSL certificates
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    client_max_body_size 50m;
    client_body_timeout 120s;

    # API routes
    location /upload/pdf {
      proxy_pass http://server:8000;
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
      proxy_pass http://server:8000;
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
      proxy_pass http://client:3000;
      proxy_set_header Host \$host;
      proxy_set_header X-Real-IP \$remote_addr;
      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto \$scheme;
      proxy_http_version 1.1;
      proxy_set_header Upgrade \$http_upgrade;
      proxy_set_header Connection "upgrade";
    }

    # Health check
    location /health {
      access_log off;
      return 200 "healthy\n";
      add_header Content-Type text/plain;
    }

    # Static files caching
    location ~* \\.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)\$ {
      proxy_pass http://client:3000;
      expires 1y;
      add_header Cache-Control "public, immutable";
      proxy_set_header Host \$host;
      access_log off;
    }
  }
EOF

    echo -e "${BLUE}🔄 Restarting services with HTTPS...${NC}"
    docker compose -f docker-compose.prod.yml down
    sleep 2
    docker compose -f docker-compose.prod.yml up --build -d

    # Wait for services to start
    sleep 10

    echo ""
    echo -e "${GREEN}🎉 Setup complete!${NC}"
    echo ""
    echo -e "${YELLOW}✅ Your app is now available at:${NC}"
    echo -e "${GREEN}https://$DOMAIN${NC}"
    echo -e "${GREEN}https://www.$DOMAIN${NC}"
    echo ""
    echo -e "${YELLOW}📝 HTTPS Details:${NC}"
    echo "Domain: $DOMAIN"
    echo "Certificate: Let's Encrypt"
    echo "Auto-renewal: Enabled"
    echo ""
    echo -e "${YELLOW}✨ Security features enabled:${NC}"
    echo "✅ HTTP → HTTPS redirect"
    echo "✅ HSTS security header"
    echo "✅ TLS 1.2 & 1.3"
    echo "✅ Strong cipher suites"
    echo ""
    echo -e "${BLUE}📊 Check status:${NC}"
    echo "docker compose -f docker-compose.prod.yml ps"
    echo ""

else
    echo -e "${RED}❌ Failed to obtain SSL certificate${NC}"
    echo ""
    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo "1. Verify DNS resolution:"
    echo "   dig $DOMAIN"
    echo "   Should show: $DOMAIN. A $SERVER_IP"
    echo ""
    echo "2. Verify port 80 is open:"
    echo "   curl http://$DOMAIN"
    echo ""
    echo "3. Check if behind Cloudflare:"
    echo "   If yes, set to DNS-only mode (not proxied)"
    echo ""
    echo "4. Try again:"
    echo "   ./setup-ssl.sh $DOMAIN $EMAIL"
    exit 1
fi
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
    sed -i "/server_name $DOMAIN www.$DOMAIN;/a\    return 301 https://\$host\$request_uri;" nginx/nginx.conf

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