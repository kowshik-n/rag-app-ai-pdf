# RAG AI PDF Chat - Custom Domain & HTTPS Setup

This guide will help you set up your RAG AI PDF Chat app with a custom domain and free HTTPS certificates.

## Prerequisites

- Ubuntu server with Docker installed
- A domain name (free options below)
- SSH access to your server

## Step 1: Get a Free Domain

### Option A: Free Subdomains (Recommended for testing)
- **FreeDNS** (freedns.afraid.org) - Free subdomains
- **DuckDNS** (duckdns.org) - Free subdomains with auto-renewal
- **No-IP** (noip.com) - Free dynamic DNS

### Option B: Cheap Domains ($1-5/year)
- **Namecheap** - Search for cheap .xyz, .online, .site domains
- **Porkbun** - Affordable domains with good privacy
- **Njalla** - Privacy-focused domain registrar

## Step 2: Point Domain to Your Server

### For DigitalOcean:
1. Go to your [DigitalOcean Dashboard](https://cloud.digitalocean.com/)
2. Navigate to **Networking** → **Domains**
3. Add your domain and point the A record to your droplet's IP

### For other providers:
Create an **A record** pointing to your server's IP address:
```
Type: A
Name: @ (or your subdomain)
Value: YOUR_SERVER_IP
TTL: 3600 (or default)
```

## Step 3: Deploy with HTTPS

### On your server:

```bash
# Navigate to your project
cd /root/rag-app-ai-pdf

# Pull latest changes
git pull origin main

# Make the SSL setup script executable
chmod +x setup-ssl.sh

# Run the SSL setup (replace 'yourdomain.com' with your actual domain)
./setup-ssl.sh yourdomain.com your-email@example.com
```

### What the script does:
1. ✅ Creates necessary directories for SSL certificates
2. ✅ Updates nginx configuration with your domain
3. ✅ Obtains free SSL certificate from Let's Encrypt
4. ✅ Configures HTTPS with security headers
5. ✅ Sets up automatic HTTP to HTTPS redirects

## Step 4: Verify Setup

After the script completes:

1. **Test HTTP redirect**: Visit `http://yourdomain.com` (should redirect to HTTPS)
2. **Test HTTPS**: Visit `https://yourdomain.com` (should show your app with lock icon)
3. **Test SSL certificate**: Use [SSL Labs](https://www.ssllabs.com/ssltest/) to check your certificate

## Troubleshooting

### DNS not working?
- Wait 24-48 hours for DNS propagation
- Check DNS with: `nslookup yourdomain.com`
- Verify A record points to correct IP

### SSL certificate failed?
- Ensure port 80 is open: `ufw allow 80`
- Check if domain is behind Cloudflare (set to DNS-only mode)
- Verify DNS points to your server IP

### App not loading?
```bash
# Check service status
docker-compose -f docker-compose.prod.yml ps

# View logs
docker-compose -f docker-compose.prod.yml logs web
docker-compose -f docker-compose.prod.yml logs client
docker-compose -f docker-compose.prod.yml logs server
```

## Security Features Added

- ✅ **Free SSL certificates** from Let's Encrypt
- ✅ **HTTP to HTTPS redirects** (secure by default)
- ✅ **Security headers** (XSS protection, content security policy)
- ✅ **Gzip compression** for faster loading
- ✅ **Automatic certificate renewal**

## Certificate Renewal

Certificates auto-renew every 90 days. To manually renew:

```bash
# Stop web service temporarily
docker-compose -f docker-compose.prod.yml stop web

# Renew certificates
docker-compose -f docker-compose.prod.yml run --rm certbot renew

# Restart web service
docker-compose -f docker-compose.prod.yml start web
```

## Cost Breakdown

- **Domain**: $0-5/year (free options available)
- **SSL Certificate**: FREE (Let's Encrypt)
- **Server**: Your existing DigitalOcean droplet
- **Total**: $0-5/year + your server costs

## Need Help?

If you encounter issues:
1. Check the troubleshooting section above
2. Review Docker logs for error messages
3. Ensure your domain DNS is properly configured
4. Verify firewall allows ports 80 and 443

Your app will be available at `https://yourdomain.com` with a professional, secure setup! 🚀