import {
  createMcpExpressApp,
  originValidation,
  requireBearerAuth
} from "@modelcontextprotocol/express";
import { NodeStreamableHTTPServerTransport } from "@modelcontextprotocol/node";
import type { Express, RequestHandler } from "express";
import express from "express";

import { JwtTokenVerifier } from "./auth.js";
import type { ServiceConfig } from "./config.js";
import type { OperationalLogger } from "./logger.js";
import type { SalesforceClient } from "./salesforce-client.js";
import { createToolServer } from "./tools.js";

export function createApp(
  config: ServiceConfig,
  client: SalesforceClient,
  logger: OperationalLogger
): Express {
  const app = createMcpExpressApp({
    host: config.host,
    allowedHosts: config.allowedHosts
  });
  app.disable("x-powered-by");
  app.use(originValidation(config.allowedOrigins));
  app.get("/healthz", (_request, response) => {
    response.status(config.killSwitch ? 503 : 200).json({
      status: config.killSwitch ? "disabled" : "ok",
      buildId: config.buildId
    });
  });
  app.use(
    "/mcp",
    express.json({ limit: "32kb", strict: true, type: "application/json" })
  );

  const middleware: RequestHandler[] = [];
  if (config.authMode === "jwt") {
    middleware.push(
      requireBearerAuth({
        verifier: new JwtTokenVerifier(config),
        requiredScopes: [config.requiredScope]
      })
    );
  }
  app.post("/mcp", ...middleware, async (request, response) => {
    if (config.killSwitch) {
      response.status(503).json({ error: "Service is disabled." });
      return;
    }
    const server = createToolServer(client, logger);
    const transport = new NodeStreamableHTTPServerTransport({
      sessionIdGenerator: undefined
    });
    response.on("close", () => {
      void transport.close();
      void server.close();
    });
    await server.connect(transport);
    await transport.handleRequest(request, response, request.body);
  });
  return app;
}
