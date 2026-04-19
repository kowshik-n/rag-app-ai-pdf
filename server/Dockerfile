FROM node:20-alpine

WORKDIR /app

COPY package.json pnpm-lock.yaml ./
RUN corepack enable && corepack pnpm install --frozen-lockfile

COPY . .
RUN mkdir -p uploads

EXPOSE 8000
CMD ["node", "index.js"]
