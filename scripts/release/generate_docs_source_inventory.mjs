#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../.."
);
const metadataRoot = path.join(
  root,
  "packages/record-health-check/force-app/main/default"
);
const output = path.join(root, "docs/reference/source-inventory.md");
const write = process.argv.includes("--write");

function xmlValue(source, name) {
  return (
    source
      .match(new RegExp(`<${name}\\b[^>]*>([\\s\\S]*?)</${name}>`))?.[1]
      ?.trim() ?? ""
  );
}

function markdown(value) {
  return String(value).replaceAll("|", "\\|").replaceAll("\n", " ");
}

function files(directory, suffix) {
  return fs
    .readdirSync(directory)
    .filter((name) => name.endsWith(suffix))
    .sort();
}

function metadataValue(source, fieldName) {
  for (const block of source.matchAll(/<values>([\s\S]*?)<\/values>/g)) {
    if (xmlValue(block[1], "field") === fieldName) {
      return xmlValue(block[1], "value")
        .replaceAll("&gt;", ">")
        .replaceAll("&lt;", "<")
        .replaceAll("&amp;", "&");
    }
  }
  return "";
}

const packageProject = JSON.parse(
  fs.readFileSync(
    path.join(root, "packages/record-health-check/sfdx-project.json"),
    "utf8"
  )
);
const release = JSON.parse(
  fs.readFileSync(path.join(root, "config/package-releases.json"), "utf8")
);
const runtimeMatrix = JSON.parse(
  fs.readFileSync(path.join(root, "config/release-runtime-matrix.json"), "utf8")
);

const permissionSets = files(
  path.join(metadataRoot, "permissionsets"),
  ".permissionset-meta.xml"
).map((name) => {
  const source = fs.readFileSync(
    path.join(metadataRoot, "permissionsets", name),
    "utf8"
  );
  return {
    apiName: name.replace(".permissionset-meta.xml", ""),
    label: xmlValue(source, "label"),
    description: xmlValue(source, "description")
  };
});

const customPermissions = files(
  path.join(metadataRoot, "customPermissions"),
  ".customPermission-meta.xml"
).map((name) => {
  const source = fs.readFileSync(
    path.join(metadataRoot, "customPermissions", name),
    "utf8"
  );
  return {
    apiName: name.replace(".customPermission-meta.xml", ""),
    label: xmlValue(source, "label"),
    description: xmlValue(source, "description")
  };
});

const components = fs
  .readdirSync(path.join(metadataRoot, "lwc"), { withFileTypes: true })
  .filter((entry) => entry.isDirectory())
  .map((entry) => {
    const metadataFile = path.join(
      metadataRoot,
      "lwc",
      entry.name,
      `${entry.name}.js-meta.xml`
    );
    if (!fs.existsSync(metadataFile)) return null;
    const source = fs.readFileSync(metadataFile, "utf8");
    if (xmlValue(source, "isExposed") !== "true") return null;
    const properties = [...source.matchAll(/<property\b([\s\S]*?)\/>/g)].map(
      (match) => {
        const attribute = (name) =>
          match[1].match(new RegExp(`${name}="([^"]*)"`))?.[1] ?? "";
        return {
          name: attribute("name"),
          type: attribute("type"),
          label: attribute("label"),
          description: attribute("description")
        };
      }
    );
    return {
      apiName: entry.name,
      label: xmlValue(source, "masterLabel"),
      description: xmlValue(source, "description"),
      targets: [...source.matchAll(/<target>([^<]+)<\/target>/g)].map(
        (match) => match[1]
      ),
      properties
    };
  })
  .filter(Boolean)
  .sort((left, right) => left.apiName.localeCompare(right.apiName));

const objects = fs
  .readdirSync(path.join(metadataRoot, "objects"), { withFileTypes: true })
  .filter((entry) => entry.isDirectory())
  .map((entry) => {
    const directory = path.join(metadataRoot, "objects", entry.name);
    const objectFile = path.join(directory, `${entry.name}.object-meta.xml`);
    const source = fs.readFileSync(objectFile, "utf8");
    const fieldDirectory = path.join(directory, "fields");
    const objectFields = fs.existsSync(fieldDirectory)
      ? files(fieldDirectory, ".field-meta.xml").map((name) => {
          const fieldSource = fs.readFileSync(
            path.join(fieldDirectory, name),
            "utf8"
          );
          return {
            apiName: name.replace(".field-meta.xml", ""),
            label: xmlValue(fieldSource, "label"),
            type: xmlValue(fieldSource, "type")
          };
        })
      : [];
    return {
      apiName: entry.name,
      label: xmlValue(source, "label"),
      kind: entry.name.endsWith("__mdt")
        ? "Custom Metadata Type"
        : entry.name.endsWith("__e")
          ? "Platform Event"
          : "Custom Object",
      fields: objectFields
    };
  })
  .sort((left, right) => left.apiName.localeCompare(right.apiName));

const customMetadataRoot = path.join(metadataRoot, "customMetadata");
const installedExampleSets = files(customMetadataRoot, ".md-meta.xml")
  .filter((name) => name.startsWith("Record_Health_Check_Set.Example_"))
  .map((name) => {
    const source = fs.readFileSync(path.join(customMetadataRoot, name), "utf8");
    return {
      apiName: name
        .replace("Record_Health_Check_Set.", "")
        .replace(".md-meta.xml", ""),
      label: xmlValue(source, "label"),
      object: metadataValue(source, "ObjectApiName__c"),
      active: metadataValue(source, "IsActive__c")
    };
  })
  .sort((left, right) => left.apiName.localeCompare(right.apiName));

const installedExampleChecks = files(customMetadataRoot, ".md-meta.xml")
  .filter((name) => name.startsWith("Record_Health_Check.Example_"))
  .map((name) => {
    const source = fs.readFileSync(path.join(customMetadataRoot, name), "utf8");
    return {
      apiName: name
        .replace("Record_Health_Check.", "")
        .replace(".md-meta.xml", ""),
      label: xmlValue(source, "label"),
      set: metadataValue(source, "Record_Health_Check_Set__c"),
      evaluationType: metadataValue(source, "EvaluationType__c"),
      active: metadataValue(source, "IsActive__c")
    };
  })
  .sort((left, right) => left.apiName.localeCompare(right.apiName));

const classRoot = path.join(metadataRoot, "classes");
const invocableActions = files(classRoot, ".cls")
  .map((name) => {
    const source = fs.readFileSync(path.join(classRoot, name), "utf8");
    if (!source.includes("@InvocableMethod")) return null;
    const annotation =
      source.match(/@InvocableMethod\s*\(([\s\S]*?)\)/)?.[1] ?? "";
    const attribute = (key) =>
      annotation.match(new RegExp(`${key}='([^']*)'`))?.[1] ?? "";
    const variables = [
      ...source.matchAll(
        /@InvocableVariable\s*(?:\(([\s\S]*?)\))?\s*global\s+([A-Za-z0-9_<>,.]+)\s+(\w+)\s*;/g
      )
    ].map((match) => {
      const before = source.slice(0, match.index);
      const container =
        [...before.matchAll(/global\s+class\s+(\w+)/g)].at(-1)?.[1] ?? "";
      const variableAnnotation = match[1] ?? "";
      return {
        direction: /Request/i.test(container) ? "Input" : "Output",
        label: variableAnnotation.match(/label='([^']+)'/)?.[1] ?? match[3],
        name: match[3],
        type: match[2],
        required: /required\s*=\s*true/.test(variableAnnotation)
      };
    });
    return {
      className: name.replace(".cls", ""),
      label: attribute("label"),
      description: attribute("description"),
      surface: name.includes("AgentAction") ? "Agentforce" : "Flow",
      variables
    };
  })
  .filter(Boolean)
  .sort((left, right) => left.label.localeCompare(right.label));

const globalApexTypes = files(classRoot, ".cls")
  .map((name) => {
    const source = fs.readFileSync(path.join(classRoot, name), "utf8");
    const declaration = source.match(
      /^global\s+(?:(?:with|without|inherited)\s+sharing\s+)?(abstract\s+class|class|interface|enum)\s+(\w+)/m
    );
    if (!declaration) return null;
    return {
      name: declaration[2],
      kind: declaration[1],
      methods: [
        ...source.matchAll(
          /^\s*global\s+(?:override\s+)?(?:static\s+)?(?:[A-Za-z0-9_<>,.]+\s+)+(\w+)\s*\(/gm
        )
      ]
        .map((match) => match[1])
        .filter((method, index, values) => values.indexOf(method) === index)
        .sort()
    };
  })
  .filter(Boolean)
  .sort((left, right) => left.name.localeCompare(right.name));

function globalRequestMethods(className) {
  const source = fs.readFileSync(
    path.join(classRoot, `${className}.cls`),
    "utf8"
  );
  return [
    ...source.matchAll(
      /^\s*global\s+(?:static\s+)?(?:[A-Za-z0-9_<>,.]+\s+)+(\w+)\s*\(/gm
    )
  ]
    .map((match) => match[1])
    .filter((name, index, values) => values.indexOf(name) === index)
    .sort();
}

const apiOptions = [
  [
    "RecordHealthCheckRequest",
    globalRequestMethods("RecordHealthCheckRequest")
  ],
  [
    "RecordHealthCheckOptions",
    globalRequestMethods("RecordHealthCheckOptions")
  ],
  [
    "RecordHealthCheckPreviewRequest",
    globalRequestMethods("RecordHealthCheckPreviewRequest")
  ],
  [
    "RecordHealthCheckPreviewService",
    globalRequestMethods("RecordHealthCheckPreviewService")
  ],
  [
    "RecordHealthCheckQueueable",
    globalRequestMethods("RecordHealthCheckQueueable")
  ],
  ["RecordHealthCheckBatch", globalRequestMethods("RecordHealthCheckBatch")],
  [
    "RecordHealthCheckScheduled",
    globalRequestMethods("RecordHealthCheckScheduled")
  ]
];

const platformEvents = objects.filter(
  (object) => object.kind === "Platform Event"
);
const lines = [
  "# Source inventory",
  "",
  "> This page is generated from package source by `npm run generate:docs:inventory`.",
  "> Do not edit it by hand. `npm run check:docs:inventory` fails when source and this page differ.",
  "",
  "Use this inventory to confirm what the package actually ships. Task guides explain how to use these capabilities.",
  "",
  "## Package identity",
  "",
  "| Item | Source value |",
  "| --- | --- |",
  `| Package | ${markdown(release.packageName)} |`,
  `| Namespace | \`${markdown(packageProject.namespace)}\` |`,
  `| Metadata API | \`${markdown(packageProject.sourceApiVersion)}\` |`,
  "",
  `## Permission Sets (${permissionSets.length})`,
  "",
  "| Salesforce label | API name | Purpose |",
  "| --- | --- | --- |",
  ...permissionSets.map(
    (item) =>
      `| ${markdown(item.label)} | \`${item.apiName}\` | ${markdown(item.description)} |`
  ),
  "",
  `## Custom Permissions (${customPermissions.length})`,
  "",
  "| Salesforce label | API name | Purpose |",
  "| --- | --- | --- |",
  ...customPermissions.map(
    (item) =>
      `| ${markdown(item.label)} | \`${item.apiName}\` | ${markdown(item.description)} |`
  ),
  "",
  `## Lightning Web Components (${components.length})`,
  "",
  "| Salesforce label | Bundle | Available in Lightning App Builder | Purpose |",
  "| --- | --- | --- | --- |",
  ...components.map(
    (item) =>
      `| ${markdown(item.label)} | \`${item.apiName}\` | ${item.targets.map((target) => `\`${target}\``).join(", ")} | ${markdown(item.description)} |`
  ),
  "",
  "### Lightning App Builder properties",
  "",
  "| Component | Salesforce label | Property | Type | Purpose |",
  "| --- | --- | --- | --- | --- |",
  ...components.flatMap((component) =>
    component.properties.map(
      (property) =>
        `| ${markdown(component.label)} | ${markdown(property.label)} | \`${property.name}\` | \`${property.type}\` | ${markdown(property.description)} |`
    )
  ),
  ...(components.every((component) => component.properties.length === 0)
    ? [
        "| None | Not applicable | Not applicable | Not applicable | No exposed properties |"
      ]
    : []),
  "",
  `## Invocable actions (${invocableActions.length})`,
  "",
  "| Surface | Salesforce label | Apex class | Purpose |",
  "| --- | --- | --- | --- |",
  ...invocableActions.map(
    (item) =>
      `| ${item.surface} | ${markdown(item.label)} | \`${item.className}\` | ${markdown(item.description)} |`
  ),
  "",
  "### Invocable action inputs and outputs",
  "",
  "| Action | Direction | Salesforce label | Apex variable | Type | Required |",
  "| --- | --- | --- | --- | --- | --- |",
  ...invocableActions.flatMap((action) =>
    action.variables.map(
      (variable) =>
        `| ${markdown(action.label)} | ${variable.direction} | ${markdown(variable.label)} | \`${variable.name}\` | \`${variable.type}\` | ${variable.required ? "Yes" : "No"} |`
    )
  ),
  "",
  `## Packaged data definitions (${objects.length})`,
  "",
  "| Kind | Salesforce label | API name | Custom fields |",
  "| --- | --- | --- | ---: |",
  ...objects.map(
    (item) =>
      `| ${item.kind} | ${markdown(item.label)} | \`${item.apiName}\` | ${item.fields.length} |`
  ),
  "",
  "## Platform Event fields",
  "",
  ...platformEvents.flatMap((event) => [
    `### ${event.label} (${event.fields.length})`,
    "",
    "| Salesforce label | API name | Type |",
    "| --- | --- | --- |",
    ...event.fields.map(
      (field) =>
        `| ${markdown(field.label)} | \`${field.apiName}\` | ${markdown(field.type)} |`
    ),
    ""
  ]),
  `## Installed example Check Sets (${installedExampleSets.length})`,
  "",
  "| Salesforce label | API name | Object | Active |",
  "| --- | --- | --- | --- |",
  ...installedExampleSets.map(
    (item) =>
      `| ${markdown(item.label)} | \`${item.apiName}\` | \`${item.object}\` | ${item.active === "true" ? "Yes" : "No"} |`
  ),
  "",
  `## Installed example Checks (${installedExampleChecks.length})`,
  "",
  "| Salesforce label | API name | Check Set | Evaluation Type | Active |",
  "| --- | --- | --- | --- | --- |",
  ...installedExampleChecks.map(
    (item) =>
      `| ${markdown(item.label)} | \`${item.apiName}\` | \`${item.set}\` | \`${item.evaluationType}\` | ${item.active === "true" ? "Yes" : "No"} |`
  ),
  "",
  "## Public Apex request and execution options",
  "",
  "| Apex type | Global methods |",
  "| --- | --- |",
  ...apiOptions.map(
    ([name, methods]) =>
      `| \`${name}\` | ${methods.map((method) => `\`${method}()\``).join(", ")} |`
  ),
  "",
  `## Global Apex types (${globalApexTypes.length})`,
  "",
  "These are the namespace-visible Apex types shipped by the package. A blank method cell means the type is a DTO, enum, exception, or marker whose public contract is its fields, values, inheritance, or interface declaration.",
  "",
  "| Apex type | Kind | Global methods declared in source |",
  "| --- | --- | --- |",
  ...globalApexTypes.map(
    (item) =>
      `| \`${item.name}\` | ${item.kind} | ${item.methods.length ? item.methods.map((method) => `\`${method}()\``).join(", ") : "Not applicable"} |`
  ),
  "",
  `## External Apex entry classes (${runtimeMatrix.apexExternalEntryClasses.length})`,
  "",
  ...runtimeMatrix.apexExternalEntryClasses.map((name) => `- \`${name}\``),
  "",
  "## Related",
  "",
  "- [Feature catalog](./feature-catalog.md)",
  "- [Permission Sets](./permission-sets.md)",
  "- [Flow action inputs and outputs](../flow-guides/action-inputs-and-outputs.md)",
  "- [Run from Apex](../developer-guides/run-from-apex.md)",
  ""
];

const rendered = lines.join("\n");
if (write) {
  fs.mkdirSync(path.dirname(output), { recursive: true });
  fs.writeFileSync(output, rendered);
  console.log(`Wrote ${path.relative(root, output)}.`);
} else {
  if (!fs.existsSync(output) || fs.readFileSync(output, "utf8") !== rendered) {
    console.error(
      "Source inventory is stale. Run npm run generate:docs:inventory and review the change."
    );
    process.exit(1);
  }
  console.log(
    `Source inventory matches ${permissionSets.length} Permission Sets, ${customPermissions.length} Custom Permissions, ${components.length} LWCs, ${invocableActions.length} invocable actions, ${objects.length} packaged data definitions, ${installedExampleSets.length} example Check Sets, ${installedExampleChecks.length} example Checks, and ${globalApexTypes.length} global Apex types.`
  );
}
