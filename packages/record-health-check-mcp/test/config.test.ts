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

  it("rejects unauthenticated production and unknown values", () => {
    expect(() => loadConfig({ ...base, NODE_ENV: "production" })).toThrow();
    expect(() => loadConfig({ ...base, UNEXPECTED_SECRET: "value" })).toThrow();
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
