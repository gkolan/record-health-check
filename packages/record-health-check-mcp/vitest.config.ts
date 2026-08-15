import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    coverage: {
      provider: "v8",
      reporter: ["text", "json-summary"],
      thresholds: {
        lines: 90,
        functions: 95,
        statements: 88,
        branches: 70
      }
    },
    environment: "node",
    restoreMocks: true
  }
});
