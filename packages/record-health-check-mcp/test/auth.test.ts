import { beforeEach, describe, expect, it, vi } from "vitest";
import { verifyBearerToken } from "@modelcontextprotocol/server";

const { jwtVerify } = vi.hoisted(() => ({ jwtVerify: vi.fn() }));
vi.mock("jose", () => ({
  createRemoteJWKSet: vi.fn(() => vi.fn()),
  jwtVerify
}));

import { JwtTokenVerifier } from "../src/auth.js";
import { testConfig } from "./helpers.js";

describe("JWT verifier", () => {
  beforeEach(() => jwtVerify.mockReset());

  it("maps verified standard claims to MCP auth information", async () => {
    jwtVerify.mockResolvedValue({
      payload: {
        sub: "client-subject",
        client_id: "agentforce",
        exp: 2_000_000_000,
        scope: "rhc.run extra"
      }
    });
    const config = testConfig({
      authMode: "jwt",
      authIssuer: "https://issuer.example.test",
      authAudience: "record-health-check",
      authJwksUrl: new URL("https://issuer.example.test/.well-known/jwks.json")
    });
    const result = await new JwtTokenVerifier(config).verifyAccessToken(
      "signed-token"
    );
    expect(result).toMatchObject({
      clientId: "agentforce",
      scopes: ["rhc.run", "extra"],
      expiresAt: 2_000_000_000
    });
    expect(jwtVerify).toHaveBeenCalledWith(
      "signed-token",
      expect.any(Function),
      expect.objectContaining({
        issuer: "https://issuer.example.test",
        audience: "record-health-check"
      })
    );
  });

  it("rejects incomplete, insecure, and claim-deficient configurations", async () => {
    expect(() => new JwtTokenVerifier(testConfig())).toThrow("incomplete");
    expect(
      () =>
        new JwtTokenVerifier(
          testConfig({
            authIssuer: "https://issuer.example.test",
            authAudience: "audience",
            authJwksUrl: new URL("http://issuer.example.test/jwks")
          })
        )
    ).toThrow("HTTPS");
    jwtVerify.mockResolvedValue({ payload: { scope: "rhc.run" } });
    await expect(
      new JwtTokenVerifier(
        testConfig({
          authIssuer: "https://issuer.example.test",
          authAudience: "audience",
          authJwksUrl: new URL("https://issuer.example.test/jwks")
        })
      ).verifyAccessToken("token")
    ).rejects.toThrow("access token is invalid");
  });

  it("rejects anonymous, expired, and wrong-scope requests before execution", async () => {
    const verifier = new JwtTokenVerifier(
      testConfig({
        authIssuer: "https://issuer.example.test",
        authAudience: "audience",
        authJwksUrl: new URL("https://issuer.example.test/jwks")
      })
    );
    await expect(
      verifyBearerToken(undefined, { verifier, requiredScopes: ["rhc.run"] })
    ).rejects.toMatchObject({ code: "invalid_token" });

    jwtVerify.mockResolvedValue({
      payload: {
        sub: "client",
        exp: Math.floor(Date.now() / 1000) - 60,
        scope: "rhc.run"
      }
    });
    await expect(
      verifyBearerToken("Bearer expired", {
        verifier,
        requiredScopes: ["rhc.run"]
      })
    ).rejects.toMatchObject({ code: "invalid_token" });

    jwtVerify.mockResolvedValue({
      payload: {
        sub: "client",
        exp: Math.floor(Date.now() / 1000) + 600,
        scope: "unrelated"
      }
    });
    await expect(
      verifyBearerToken("Bearer wrong-scope", {
        verifier,
        requiredScopes: ["rhc.run"]
      })
    ).rejects.toMatchObject({ code: "insufficient_scope" });
  });
});
