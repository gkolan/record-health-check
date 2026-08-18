FROM node:22.23.2-bookworm-slim AS build
WORKDIR /service
RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*
COPY package.json package-lock.json NOTICE ./
RUN npm ci
COPY tsconfig.json tsconfig.build.json ./
COPY src ./src
RUN npm run build && npm prune --omit=dev

FROM node:22.23.2-bookworm-slim AS runtime
ENV NODE_ENV=production
WORKDIR /service
RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/* \
    && rm -rf /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/corepack \
       /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack
USER node
COPY --chown=node:node --from=build /service/package.json /service/package-lock.json ./
COPY --chown=node:node --from=build /service/NOTICE ./NOTICE
COPY --chown=node:node --from=build /service/node_modules ./node_modules
COPY --chown=node:node --from=build /service/dist ./dist
EXPOSE 3000
CMD ["node", "dist/main.js"]
