# RAG AI PDF Chat App

## Overview

This repository contains a full-stack PDF question-answer app using:
- `client/` — Next.js front end
- `server/` — Express API for file upload and chat
- `worker.js` — background PDF processing using Redis / BullMQ
- Redis and Qdrant for queueing and vector storage

## Quick start (local)

1. Create `.env` in the repo root:

```env
OPENAI_API_KEY=your_openai_api_key
```

2. Run locally with Docker Compose:

```bash
docker compose up --build
```

3. Open the site:
- Front end: `http://localhost:3000`
- Server health: `http://localhost:8000`

## Production deployment (live server)

Use a server or VPS with Docker and Docker Compose. This repo includes `docker-compose.prod.yml` and `nginx/nginx.conf` for a production-ready reverse proxy setup.

### 1. Copy the repo to your server

```bash
git clone <your-repo-url>
cd rag-ai-app-pdf
```

### 2. Create a `.env` file on the server

```env
OPENAI_API_KEY=your_openai_api_key
QDRANT_COLLECTION_NAME=langchainjs-testing
```

### 3. Start production services

```bash
docker compose -f docker-compose.prod.yml up --build -d
```

### 4. Access the live site

- `http://<your-server-ip>`
- If you configure DNS and HTTPS, use your domain instead

## Files added for deployment

- `.env.example` — environment variable template
- `docker-compose.prod.yml` — production Compose setup with Nginx proxy
- `nginx/nginx.conf` — public reverse proxy rules

## Notes

- Keep `OPENAI_API_KEY` private.
- For local development, the front end uses `http://localhost:8000` for the API.
- For production, Nginx proxies `/upload/pdf` and `/chat` to the backend and serves the client.
- Uploaded PDFs are stored in `server/uploads` and embedding data is stored in the `qdrant_data` volume.

## Next step

If you want, I can also help you add HTTPS with a real domain or configure the server for a specific provider like DigitalOcean, AWS, or Azure.
