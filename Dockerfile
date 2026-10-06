FROM node:24-alpine AS base
WORKDIR /app
RUN npm install --global pnpm@10.11.0

FROM base AS dependencias
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN pnpm install --frozen-lockfile

FROM dependencias AS build
COPY nest-cli.json tsconfig*.json ./
COPY src ./src
RUN pnpm build

FROM base AS production-dependencias
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN pnpm install --prod --frozen-lockfile

FROM node:24-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production PORT=3000
COPY --from=production-dependencias /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY package.json ./
EXPOSE 3000
CMD ["node", "dist/main.js"]

