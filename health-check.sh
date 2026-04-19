#!/bin/bash

# Health Check Script for RAG AI PDF Chat with HTTPS

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 RAG AI PDF Chat - Health Check${NC}"
echo "==================================="

# Check if domain is provided
if [ -z "$1" ]; then
    echo -e "${RED}❌ Error: Please provide your domain name${NC}"
    echo "Usage: $0 yourdomain.com"
    exit 1
fi

DOMAIN=$1

echo -e "${YELLOW}📋 Checking domain: $DOMAIN${NC}"
echo ""

# Check DNS resolution
echo -e "${BLUE}🌐 Checking DNS resolution...${NC}"
if nslookup "$DOMAIN" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ DNS resolution working${NC}"
else
    echo -e "${RED}❌ DNS resolution failed${NC}"
    echo "Make sure your domain points to this server's IP"
fi

# Check HTTP to HTTPS redirect
echo -e "${BLUE}🔄 Checking HTTP redirect...${NC}"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$DOMAIN" || echo "000")
if [ "$HTTP_STATUS" = "301" ] || [ "$HTTP_STATUS" = "302" ]; then
    echo -e "${GREEN}✅ HTTP redirects to HTTPS${NC}"
else
    echo -e "${YELLOW}⚠️  HTTP redirect status: $HTTP_STATUS${NC}"
fi

# Check HTTPS certificate
echo -e "${BLUE}🔐 Checking SSL certificate...${NC}"
CERT_INFO=$(openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" < /dev/null 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || echo "FAILED")
if [[ $CERT_INFO == *"notAfter"* ]]; then
    echo -e "${GREEN}✅ SSL certificate valid${NC}"
else
    echo -e "${RED}❌ SSL certificate issue${NC}"
fi

# Check app response
echo -e "${BLUE}🚀 Checking app response...${NC}"
HTTPS_STATUS=$(curl -s -k -o /dev/null -w "%{http_code}" "https://$DOMAIN" || echo "000")
if [ "$HTTPS_STATUS" = "200" ]; then
    echo -e "${GREEN}✅ App responding on HTTPS${NC}"
else
    echo -e "${RED}❌ App not responding (Status: $HTTPS_STATUS)${NC}"
fi

# Check Docker services
echo -e "${BLUE}🐳 Checking Docker services...${NC}"
if docker-compose -f docker-compose.prod.yml ps | grep -q "Up"; then
    echo -e "${GREEN}✅ Docker services running${NC}"

    # Show service status
    echo ""
    echo -e "${YELLOW}📊 Service Status:${NC}"
    docker-compose -f docker-compose.prod.yml ps --format "table {{.Name}}\t{{.Status}}"
else
    echo -e "${RED}❌ Docker services not running${NC}"
fi

echo ""
echo -e "${BLUE}✨ Health check complete!${NC}"

if [ "$HTTPS_STATUS" = "200" ] && [[ $CERT_INFO == *"notAfter"* ]]; then
    echo -e "${GREEN}🎉 Your app is live and secure at https://$DOMAIN${NC}"
else
    echo -e "${RED}⚠️  Some issues detected. Check the output above.${NC}"
fi