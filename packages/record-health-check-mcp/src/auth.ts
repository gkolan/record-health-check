import {
  OAuthError,
  OAuthErrorCode,
  type AuthInfo,
  type OAuthTokenVerifier
} from "@modelcontextprotocol/server";
import { createRemoteJWKSet, jwtVerify } from "jose";

import type { ServiceConfig } from "./config.js";

export class JwtTokenVerifier implements OAuthTokenVerifier {
  private readonly keys: ReturnType<typeof createRemoteJWKSet>;

  constructor(private readonly config: ServiceConfig) {
    if (!config.authIssuer || !config.authAudience || !config.authJwksUrl) {
      throw new Error("JWT verification configuration is incomplete.");
    }
    if (config.authJwksUrl.protocol !== "https:") {
      throw new Error("The JWT key URL must use HTTPS.");
    }
    this.keys = createRemoteJWKSet(config.authJwksUrl, {
      cooldownDuration: 30_000,
      timeoutDuration: 5_000
    });
  }

  async verifyAccessToken(token: string): Promise<AuthInfo> {
    const issuer = this.config.authIssuer;
    const audience = this.config.authAudience;
    if (!issuer || !audience)
      throw new Error("JWT verification configuration is incomplete.");
    try {
      const { payload } = await jwtVerify(token, this.keys, {
        issuer,
        audience,
        algorithms: ["RS256", "ES256"]
      });
      if (!payload.exp || !payload.sub) {
        throw new OAuthError(
          OAuthErrorCode.InvalidToken,
          "The access token is invalid."
        );
      }
      const scopes =
        typeof payload.scope === "string"
          ? payload.scope.split(/\s+/).filter(Boolean)
          : [];
      return {
        token,
        clientId: payload.client_id?.toString() ?? payload.sub,
        scopes,
        expiresAt: payload.exp,
        resource: this.config.serverUrl
      };
    } catch {
      throw new OAuthError(
        OAuthErrorCode.InvalidToken,
        "The access token is invalid."
      );
    }
  }
}
