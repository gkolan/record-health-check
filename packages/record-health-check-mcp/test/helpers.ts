import type { ServiceConfig } from "../src/config.js";

export function testConfig(
  overrides: Partial<ServiceConfig> = {}
): ServiceConfig {
  return {
    nodeEnv: "test",
    host: "127.0.0.1",
    port: 3000,
    allowedHosts: ["127.0.0.1", "localhost"],
    allowedOrigins: ["127.0.0.1", "localhost"],
    authMode: "none",
    serverUrl: new URL("https://mcp.example.test/mcp"),
    requiredScope: "rhc.run",
    salesforce: {
      loginUrl: new URL("https://login.salesforce.test"),
      clientId: "test-client",
      clientSecret: "test-secret",
      allowedHosts: ["login.salesforce.test", "instance.salesforce.test"],
      restPath:
        "/services/apexrest/rhc/record-health-check/contract-1/evaluations",
      timeoutMs: 500,
      maxResponseBytes: 65536,
      maxRetries: 1,
      maxConcurrentCalls: 2
    },
    killSwitch: false,
    buildId: "test",
    ...overrides
  };
}
