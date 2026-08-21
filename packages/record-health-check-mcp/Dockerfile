FROM node:22.23.2-trixie-slim AS build
WORKDIR /service
RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*
COPY package.json package-lock.json NOTICE ./
RUN npm ci
COPY tsconfig.json tsconfig.build.json ./
COPY src ./src
RUN npm run build && npm prune --omit=dev

FROM gcr.io/distroless/nodejs22-debian13:nonroot@sha256:939d6f1671529d230f50b563578e9b5d206af58f038b10ebd7e1233023d4e167 AS runtime
ENV NODE_ENV=production
WORKDIR /service
COPY --chown=nonroot:nonroot --from=build /service/package.json /service/package-lock.json ./
COPY --chown=nonroot:nonroot --from=build /service/NOTICE ./NOTICE
COPY --chown=nonroot:nonroot --from=build /service/node_modules ./node_modules
COPY --chown=nonroot:nonroot --from=build /service/dist ./dist
EXPOSE 3000
CMD ["dist/main.js"]
