import { createServer } from "node:http";

import { createApp } from "./app.js";
import { loadConfig, safeConfigError } from "./config.js";
import { JsonLogger } from "./logger.js";
import { SalesforceClient } from "./salesforce-client.js";
import { attachStartupErrorHandler } from "./startup.js";

try {
  const config = loadConfig();
  const logger = new JsonLogger();
  const app = createApp(config, new SalesforceClient(config, logger), logger);
  const server = createServer(app);
  attachStartupErrorHandler(server);
  server.listen(config.port, config.host, () => {
    logger.log("info", "MCP service started.", {
      event: "service_started",
      buildId: config.buildId
    });
  });
  for (const signal of ["SIGINT", "SIGTERM"] as const) {
    process.on(signal, () => {
      logger.log("info", "MCP service is stopping.", {
        event: "service_stopping",
        buildId: config.buildId
      });
      server.close(() => process.exit(0));
      setTimeout(() => process.exit(1), 10_000).unref();
    });
  }
} catch (error) {
  process.stderr.write(`${safeConfigError(error)}\n`);
  process.exitCode = 1;
}
