FROM node:20-slim

# Prisma needs OpenSSL at runtime
RUN apt-get update && apt-get install -y --no-install-recommends openssl ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
# `npm run build` runs `prisma generate` and then `next build`
RUN npm run build

ENV NODE_ENV=production
ENV PORT=3000
EXPOSE 3000

# Web app by default. The worker service overrides this with: npm run worker:prod
CMD ["npm", "run", "start:web"]
