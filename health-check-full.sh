#!/bin/bash

# Health Check Script for RAG AI PDF Chat
# Verifies all services are running and accessible

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🏥 RAG AI PDF Chat - Health Check${NC}"
echo "===================================="
echo ""

# Function to check service
check_service() {
    local service=$1
    local port=$2
    local internal=${3:-false}
    
    if [ "$internal" = true ]; then
        result=$(docker compose -f docker-compose.prod.yml exec -T $service nc -z localhost $port 2>&1)
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅${NC} $service (port $port) - Running"
            return 0
        else
            echo -e "${RED}❌${NC} $service (port $port) - Not responding"
            return 1
        fi
    else
        if timeout 2 bash -c "echo >/dev/tcp/localhost/$port" 2>/dev/null; then
            echo -e "${GREEN}✅${NC} $service (port $port) - Running"
            return 0
        else
            echo -e "${RED}❌${NC} $service (port $port) - Not responding"
            return 1
        fi
    fi
}

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running${NC}"
    exit 1
fi

echo -e "${BLUE}📋 Checking services...${NC}"
echo ""

# Check container status
services=$(docker compose -f docker-compose.prod.yml ps --services --all)

for service in $services; do
    status=$(docker compose -f docker-compose.prod.yml ps $service --format "{{.State}}")
    if [ "$status" = "running" ]; then
        echo -e "${GREEN}✅${NC} $service - $status"
    else
        echo -e "${RED}❌${NC} $service - $status"
    fi
done

echo ""
echo -e "${BLUE}🔌 Checking ports...${NC}"
echo ""

check_service "web" "80"
check_service "web" "443"

echo ""
echo -e "${BLUE}📊 Resource Usage:${NC}"
echo ""
docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}\t{{.CPUPerc}}" | grep -E "CONTAINER|redis|qdrant|server|worker|client|web"

echo ""
echo -e "${BLUE}📝 Recent Logs (last 5 lines):${NC}"
echo ""
docker compose -f docker-compose.prod.yml logs --tail=5 --timestamps

echo ""
echo -e "${YELLOW}🔗 Test endpoints:${NC}"
echo ""

# Test HTTP
echo -n "Testing HTTP (http://localhost/health)... "
response=$(curl -s http://localhost/health)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅${NC} $response"
else
    echo -e "${RED}❌${NC} Not responding"
fi

echo ""
echo -e "${YELLOW}🎯 Application URLs:${NC}"
echo ""

# Get server IP
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "unknown")
echo "External: http://$SERVER_IP"

# Check if HTTPS is set up
if [ -f "data/certbot/conf/live" ]; then
    DOMAIN=$(ls data/certbot/conf/live 2>/dev/null | head -1)
    if [ ! -z "$DOMAIN" ]; then
        echo "Domain: https://$DOMAIN"
    fi
fi

echo ""
echo -e "${BLUE}✨ Health check complete!${NC}"
