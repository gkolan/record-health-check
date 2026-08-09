import { defineConfig } from "eslint/config";
import { sldsCssPlugin } from "@salesforce-ux/eslint-plugin-slds";

export default defineConfig([
  {
    plugins: {
      ...sldsCssPlugin()
    },
    extends: ["@salesforce-ux/slds/recommended"],
    rules: {
      "@salesforce-ux/slds/no-hardcoded-values-slds2": "off",
      "@salesforce-ux/slds/no-slds-class-overrides": "error",
      "@salesforce-ux/slds/enforce-sds-to-slds-hooks": "error",
      "@salesforce-ux/slds/no-sldshook-fallback-for-lwctoken": "error",
      "@salesforce-ux/slds/no-unsupported-hooks-slds2": "error",
      "@salesforce-ux/slds/no-slds-var-without-fallback": "error",
      "@salesforce-ux/slds/no-slds-namespace-for-custom-hooks": "error",
      "@salesforce-ux/slds/no-slds-private-var": "error",
      "@salesforce-ux/slds/reduce-annotations": "error"
    }
  }
]);
