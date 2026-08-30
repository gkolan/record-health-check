import { z } from "zod";

const booleanString = z
  .enum(["true", "false"])
  .transform((value) => value === "true");
const commaList = z.string().transform((value) =>
  value
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean)
);

const environmentShape = {
  NODE_ENV: z.enum(["development", "test", "production"]),
  HOST: z.string().default("127.0.0.1"),
  PORT: z.coerce.number().int().min(1).max(65535).default(3000),
  ALLOWED_HOSTS: commaList.default(["localhost", "127.0.0.1", "[::1]"]),
  ALLOWED_ORIGINS: commaList.default(["localhost", "127.0.0.1", "[::1]"]),
  AUTH_MODE: z.enum(["jwt", "none"]).default("jwt"),
  MCP_SERVER_URL: z.string().url(),
  MCP_AUTH_ISSUER: z.string().url().optional(),
  MCP_AUTH_AUDIENCE: z.string().min(1).optional(),
  MCP_AUTH_JWKS_URL: z.string().url().optional(),
  MCP_AUTH_REQUIRED_SCOPE: z.string().min(1).default("rhc.run"),
  SALESFORCE_LOGIN_URL: z.string().url(),
  SALESFORCE_CLIENT_ID: z.string().min(1),
  SALESFORCE_CLIENT_SECRET: z.string().min(1),
  SALESFORCE_ALLOWED_HOSTS: commaList,
  SALESFORCE_REST_PATH: z
    .string()
    .regex(/^\/services\/apexrest\/[a-zA-Z0-9_/-]+$/)
    .default(
      "/services/apexrest/rhc/record-health-check/contract-1/evaluations"
    ),
  SALESFORCE_TIMEOUT_MS: z.coerce
    .number()
    .int()
    .min(100)
    .max(30000)
    .default(10000),
  SALESFORCE_MAX_RESPONSE_BYTES: z.coerce
    .number()
    .int()
    .min(1024)
    .max(1048576)
    .default(65536),
  SALESFORCE_MAX_RETRIES: z.coerce.number().int().min(0).max(2).default(1),
  MAX_CONCURRENT_SALESFORCE_CALLS: z.coerce
    .number()
    .int()
    .min(1)
    .max(100)
    .default(10),
  KILL_SWITCH: booleanString.default(false),
  BUILD_ID: z
    .string()
    .min(1)
    .max(120)
    .regex(/^[a-zA-Z0-9._:-]+$/)
    .default("local")
};
const environmentKeys = new Set(Object.keys(environmentShape));
const serviceEnvironmentPrefixes = [
  "MCP_",
  "SALESFORCE_",
  "MAX_CONCURRENT_SALESFORCE_",
  "AUTH_",
  "ALLOWED_",
  "KILL_"
] as const;

const environmentSchema = z
  .object(environmentShape)
  .strict()
  .superRefine((value, context) => {
    if (value.AUTH_MODE === "none" && value.NODE_ENV === "production") {
      context.addIssue({
        code: "custom",
        path: ["AUTH_MODE"],
        message: "AUTH_MODE=none is forbidden in production"
      });
    }
    if (value.AUTH_MODE === "jwt") {
      for (const field of [
        "MCP_AUTH_ISSUER",
        "MCP_AUTH_AUDIENCE",
        "MCP_AUTH_JWKS_URL"
      ] as const) {
        if (!value[field]) {
          context.addIssue({
            code: "custom",
            path: [field],
            message: `${field} is required`
          });
        }
      }
    }
    if (value.HOST === "0.0.0.0" && value.ALLOWED_HOSTS.length === 0) {
      context.addIssue({
        code: "custom",
        path: ["ALLOWED_HOSTS"],
        message: "An explicit host list is required when binding all interfaces"
      });
    }
    const serverUrl = new URL(value.MCP_SERVER_URL);
    const loginUrl = new URL(value.SALESFORCE_LOGIN_URL);
    if (serverUrl.pathname !== "/mcp") {
      context.addIssue({
        code: "custom",
        path: ["MCP_SERVER_URL"],
        message: "MCP_SERVER_URL must identify the /mcp endpoint"
      });
    }
    if (value.NODE_ENV === "production") {
      if (serverUrl.protocol !== "https:") {
        context.addIssue({
          code: "custom",
          path: ["MCP_SERVER_URL"],
          message: "Production MCP_SERVER_URL must use HTTPS"
        });
      }
      if (value.BUILD_ID === "local") {
        context.addIssue({
          code: "custom",
          path: ["BUILD_ID"],
          message: "Production BUILD_ID must identify an immutable build"
        });
      }
    }
    if (loginUrl.protocol !== "https:") {
      context.addIssue({
        code: "custom",
        path: ["SALESFORCE_LOGIN_URL"],
        message: "SALESFORCE_LOGIN_URL must use HTTPS"
      });
    }
    if (!value.SALESFORCE_ALLOWED_HOSTS.includes(loginUrl.hostname)) {
      context.addIssue({
        code: "custom",
        path: ["SALESFORCE_ALLOWED_HOSTS"],
        message: "The Salesforce login host must be explicitly permitted"
      });
    }
  });

export type ServiceConfig = {
  nodeEnv: "development" | "test" | "production";
  host: string;
  port: number;
  allowedHosts: string[];
  allowedOrigins: string[];
  authMode: "jwt" | "none";
  serverUrl: URL;
  authIssuer?: string;
  authAudience?: string;
  authJwksUrl?: URL;
  requiredScope: string;
  salesforce: {
    loginUrl: URL;
    clientId: string;
    clientSecret: string;
    allowedHosts: string[];
    restPath: string;
    timeoutMs: number;
    maxResponseBytes: number;
    maxRetries: number;
    maxConcurrentCalls: number;
  };
  killSwitch: boolean;
  buildId: string;
};

export function loadConfig(
  environment: NodeJS.ProcessEnv = process.env
): ServiceConfig {
  const serviceEnvironment = Object.fromEntries(
    Object.entries(environment).filter(
      ([key]) =>
        environmentKeys.has(key) ||
        serviceEnvironmentPrefixes.some((prefix) => key.startsWith(prefix))
    )
  );
  const parsed = environmentSchema.parse(serviceEnvironment);
  return {
    nodeEnv: parsed.NODE_ENV,
    host: parsed.HOST,
    port: parsed.PORT,
    allowedHosts: parsed.ALLOWED_HOSTS,
    allowedOrigins: parsed.ALLOWED_ORIGINS,
    authMode: parsed.AUTH_MODE,
    serverUrl: new URL(parsed.MCP_SERVER_URL),
    ...(parsed.MCP_AUTH_ISSUER ? { authIssuer: parsed.MCP_AUTH_ISSUER } : {}),
    ...(parsed.MCP_AUTH_AUDIENCE
      ? { authAudience: parsed.MCP_AUTH_AUDIENCE }
      : {}),
    ...(parsed.MCP_AUTH_JWKS_URL
      ? { authJwksUrl: new URL(parsed.MCP_AUTH_JWKS_URL) }
      : {}),
    requiredScope: parsed.MCP_AUTH_REQUIRED_SCOPE,
    salesforce: {
      loginUrl: new URL(parsed.SALESFORCE_LOGIN_URL),
      clientId: parsed.SALESFORCE_CLIENT_ID,
      clientSecret: parsed.SALESFORCE_CLIENT_SECRET,
      allowedHosts: parsed.SALESFORCE_ALLOWED_HOSTS,
      restPath: parsed.SALESFORCE_REST_PATH,
      timeoutMs: parsed.SALESFORCE_TIMEOUT_MS,
      maxResponseBytes: parsed.SALESFORCE_MAX_RESPONSE_BYTES,
      maxRetries: parsed.SALESFORCE_MAX_RETRIES,
      maxConcurrentCalls: parsed.MAX_CONCURRENT_SALESFORCE_CALLS
    },
    killSwitch: parsed.KILL_SWITCH,
    buildId: parsed.BUILD_ID
  };
}

export function safeConfigError(error: unknown): string {
  if (error instanceof z.ZodError) {
    return error.issues
      .map((issue) => `${issue.path.join(".")}: ${issue.message}`)
      .join("; ");
  }
  return "Service configuration is invalid.";
}
