import { describe, expect, it } from "vitest";

import { loadConfig, safeConfigError } from "../src/config.js";

const base = {
  NODE_ENV: "test",
  MCP_SERVER_URL: "https://mcp.example.test/mcp",
  AUTH_MODE: "none",
  SALESFORCE_LOGIN_URL: "https://login.salesforce.test",
  SALESFORCE_CLIENT_ID: "client",
  SALESFORCE_CLIENT_SECRET: "secret",
  SALESFORCE_ALLOWED_HOSTS: "login.salesforce.test,instance.salesforce.test"
};

describe("configuration", () => {
  it("loads a strict non-production configuration", () => {
    const config = loadConfig(base);
    expect(config.allowedHosts).toContain("localhost");
    expect(config.salesforce.allowedHosts).toHaveLength(2);
    expect(config.killSwitch).toBe(false);
  });

  it("rejects unauthenticated production", () => {
    expect(() => loadConfig({ ...base, NODE_ENV: "production" })).toThrow();
  });

  it("accepts ambient runtime variables but rejects unknown service settings", () => {
    const config = loadConfig({
      ...base,
      PATH: "/usr/local/bin:/usr/bin",
      HOME: "/home/node",
      HOSTNAME: "record-health-check-pod",
      CI: "true"
    });

    expect(config.serverUrl.href).toBe("https://mcp.example.test/mcp");
    expect(() =>
      loadConfig({ ...base, MCP_UNEXPECTED_SETTING: "value" })
    ).toThrow();
    expect(() =>
      loadConfig({ ...base, SALESFORCE_UNEXPECTED_SETTING: "value" })
    ).toThrow();
    expect(() =>
      loadConfig({ ...base, MAX_CONCURRENT_SALESFORCE_CALL: "50" })
    ).toThrow();
    expect(() => loadConfig({ ...base, KILL_SWICH: "true" })).toThrow();
    expect(() => loadConfig({ ...base, AUTH_MOD: "none" })).toThrow();
    expect(() =>
      loadConfig({ ...base, ALLOWED_HOST: "mcp.example.test" })
    ).toThrow();
  });

  it("requires an explicit deployment mode so a typo cannot weaken production gates", () => {
    const { NODE_ENV: removedNodeEnv, ...withoutNodeEnv } = base;
    expect(removedNodeEnv).toBe("test");

    expect(() =>
      loadConfig({
        ...withoutNodeEnv,
        NODE_EN: "production",
        HOST: "0.0.0.0",
        ALLOWED_HOSTS: "mcp.example.test",
        AUTH_MODE: "none"
      })
    ).toThrow("NODE_ENV");
  });

  it("rejects insecure endpoints, an unlisted login host, and a mutable production build", () => {
    expect(() =>
      loadConfig({
        ...base,
        SALESFORCE_LOGIN_URL: "http://login.salesforce.test"
      })
    ).toThrow();
    expect(() =>
      loadConfig({
        ...base,
        SALESFORCE_ALLOWED_HOSTS: "instance.salesforce.test"
      })
    ).toThrow();
    expect(() =>
      loadConfig({ ...base, MCP_SERVER_URL: "https://mcp.example.test/other" })
    ).toThrow();
    expect(() =>
      loadConfig({
        ...base,
        NODE_ENV: "production",
        AUTH_MODE: "jwt",
        MCP_AUTH_ISSUER: "https://issuer.example.test",
        MCP_AUTH_AUDIENCE: "record-health-check",
        MCP_AUTH_JWKS_URL: "https://issuer.example.test/jwks"
      })
    ).toThrow("BUILD_ID");
  });

  it("requires every JWT setting", () => {
    expect(() => loadConfig({ ...base, AUTH_MODE: "jwt" })).toThrow();
  });

  it("renders validation errors without environment values", () => {
    const message = safeConfigError(
      (() => {
        try {
          loadConfig({ ...base, PORT: "bad" });
        } catch (error) {
          return error;
        }
      })()
    );
    expect(message).toContain("PORT");
    expect(message).not.toContain("test-secret");
  });
});
