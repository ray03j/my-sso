FROM node:20
WORKDIR /app
COPY package*.json ./
RUN corepack enable && pnpm install
COPY . .
CMD ["pnpm", "dev"]
